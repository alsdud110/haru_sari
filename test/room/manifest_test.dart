import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/catalog.dart';
import 'package:haru_sari/room/asset_check.dart';
import 'package:haru_sari/room/iso.dart';
import 'package:haru_sari/room/manifest.dart';
import 'package:haru_sari/room/palette.dart';

PixelManifest loadManifest() => PixelManifest.parse(File(PixelManifest.manifestPath).readAsStringSync());

/// 허용 영역 안을 팔레트 색으로 채운 테스트용 PNG.
Future<Uint8List> fakeSprite(
  int w,
  int h,
  List<(double, double)> region, {
  Color color = const Color(0xFFB98559),
  bool semi = false,
  bool spill = false,
}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final path = Path()..moveTo(region.first.$1, region.first.$2);
  for (final p in region.skip(1)) {
    path.lineTo(p.$1, p.$2);
  }
  // 1px 안쪽만 칠한다 (가장자리 안티앨리어싱 방지)
  c.save();
  c.clipPath(path, doAntiAlias: false);
  c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = color..isAntiAlias = false);
  c.restore();
  if (semi) {
    c.drawRect(
      const Rect.fromLTWH(40, 60, 2, 2),
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..blendMode = BlendMode.src
        ..isAntiAlias = false,
    );
  }
  if (spill) c.drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint()..color = color..isAntiAlias = false);
  final img = await rec.endRecording().toImage(w, h);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

void main() {
  final m = loadManifest();

  test('상점 아이템 26개가 모두 매니페스트에 있고 종류가 맞다', () {
    for (final item in shopCatalog) {
      final art = m[item.id];
      expect(art, isNotNull, reason: item.id);
      switch (item.kind) {
        case ItemKind.furniture:
          expect(art!.layer, isNot(ArtLayer.character), reason: item.id);
          if (item.slot == RoomSlot.wallpaper) expect(art.layer, ArtLayer.surface);
        case ItemKind.outfit:
          expect(art!.slot, 'outfit', reason: item.id);
        case ItemKind.accessory:
          expect(['head', 'face'], contains(art!.slot), reason: item.id);
      }
    }
    expect(m.items.keys.toSet(), shopCatalog.map((e) => e.id).toSet());
  });

  test('바닥 물체에는 R0 경로가 있고, 회전 가능 여부가 정해져 있다', () {
    for (final art in m.items.values.where((a) => a.isFloor)) {
      expect(art.rotations[Rot.r0], isNotNull, reason: art.id);
      expect(art.rotatable, isTrue, reason: '${art.id}: R1 경로 또는 mirrorR1 필요');
    }
  });

  test('침대 규격', () {
    final bed = m['bed_single']!;
    expect(bed.footprintFor(Rot.r0), (1, 2));
    expect(bed.footprintFor(Rot.r1), (2, 1));
    expect(bed.spriteSpec(Rot.r0), (width: 96, height: 104, ax: 64, ay: 56));
    expect(bed.spriteSpec(Rot.r1), (width: 96, height: 104, ax: 32, ay: 56));
    expect(bed.rotations[Rot.r0], 'furniture/beds/bed_single_r0.png');
  });

  test('final 에셋은 파일이 있어야 하고, 있는 파일은 모두 검증을 통과해야 한다', () async {
    // 지금은 PNG가 하나도 없다 → 모두 draft여야 한다.
    for (final art in m.items.values) {
      final paths = [...art.rotations.values, ?art.path, ...art.sheets.values];
      for (final p in paths) {
        final f = File('${PixelManifest.assetRoot}$p');
        if (art.isFinal) expect(f.existsSync(), isTrue, reason: '${art.id}: final인데 $p 없음');
      }
    }
    for (final b in m.base.values) {
      if (b.isFinal && b.path != null) expect(File('${PixelManifest.assetRoot}${b.path}').existsSync(), isTrue);
    }
    expect(m.roomBaseFinal, isFalse, reason: '바닥·벽 에셋이 아직 없으므로 draft여야 한다');
  });

  testWidgets('있는 PNG 검증: final은 통과해야 하고, draft는 문제를 경고로 남긴다', (tester) async {
    await tester.runAsync(() async {
      for (final art in m.items.values.where((a) => a.isFloor)) {
        for (final e in art.rotations.entries) {
          final f = File('${PixelManifest.assetRoot}${e.value}');
          if (!f.existsSync()) continue;
          final problems = await AssetCheck.objectSprite(art, e.key, f.readAsBytesSync());
          if (art.isFinal) {
            expect(problems, isEmpty, reason: '${art.id} ${e.key.name}: $problems');
          } else if (problems.isNotEmpty) {
            // ignore: avoid_print
            print('[draft 경고] ${art.id} ${e.key.name}: ${problems.join(', ')}');
          }
        }
      }
    });
  });

  testWidgets('검증기: 올바른 침대는 통과, 잘못된 침대는 걸러낸다', (tester) async {
    final bed = m['bed_single']!;
    final s = bed.spriteSpec(Rot.r0);
    final region = AssetCheck.allowedRegion(1, 2, 52, s.ax, s.ay);
    // 칠할 영역은 허용 영역을 2px 줄인 모양
    final inner = [
      (region[0].$1, region[0].$2 + 3),
      (region[1].$1 - 3, region[1].$2 + 1),
      (region[2].$1 - 3, region[2].$2 - 1),
      (region[3].$1, region[3].$2 - 3),
      (region[4].$1 + 3, region[4].$2 - 1),
      (region[5].$1 + 3, region[5].$2 + 1),
    ];
    await tester.runAsync(() async {
      expect(await AssetCheck.objectSprite(bed, Rot.r0, await fakeSprite(96, 104, inner)), isEmpty);
      expect((await AssetCheck.objectSprite(bed, Rot.r0, await fakeSprite(96, 100, inner))).single, contains('크기'));
      expect(await AssetCheck.objectSprite(bed, Rot.r0, await fakeSprite(96, 104, inner, semi: true)),
          contains(contains('반투명')));
      expect(await AssetCheck.objectSprite(bed, Rot.r0, await fakeSprite(96, 104, inner, spill: true)),
          contains(contains('허용 영역 밖')));
      expect(
        await AssetCheck.objectSprite(bed, Rot.r0, await fakeSprite(96, 104, inner, color: const Color(0xFF123456))),
        contains(contains('팔레트')),
      );
    });
  });

  test('팔레트: 57색, 앱 토큰 색 포함, 스왑 표', () {
    expect(PixelPalette.all.length, 57);
    expect(PixelPalette.all, containsAll([0xF2E6D8 == 0 ? 0 : 0xD9B993, 0xB98559, 0x8FAE8B, 0xE08A5B]));
    final swap = PixelPalette.swapFor(skinIndex: 2, hairIndex: 0);
    expect(swap[0xFBE3D0], 0xD9A57E);
    expect(swap.containsKey(0x3B2E28), isFalse); // 머리 0번은 그대로
  });
}
