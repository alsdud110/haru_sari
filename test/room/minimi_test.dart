import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/models.dart';
import 'package:haru_sari/room/registry.dart';
import 'package:haru_sari/ui/room/minimi_sprite.dart';

import 'manifest_test.dart' show loadManifest;
import 'scene_test.dart' show FakeBundle;

const skin0 = 0xFBE3D0, skin2 = 0xD9A57E;
const hair0 = 0x3B2E28, hair0light = 0x5A463C;
const sage = 0x8FAE8B, butter = 0xE5B547, sky = 0x6F8FB8;

/// 256×192 시트: 모든 프레임·두 줄에 같은 사각형들을 칠한다. [sideMarker]는 측면 줄에만.
Future<Uint8List> sheet(List<(Rect, int)> rects, {(Rect, int)? sideMarker, int w = 256, int h = 192}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  for (var row = 0; row < 2; row++) {
    for (var f = 0; f < 4; f++) {
      final o = Offset(f * 64.0, row * 96.0);
      for (final (r, color) in rects) {
        c.drawRect(r.shift(o), Paint()..color = Color(0xFF000000 | color)..isAntiAlias = false);
      }
      if (row == 1 && sideMarker != null) {
        c.drawRect(sideMarker.$1.shift(o), Paint()..color = Color(0xFF000000 | sideMarker.$2)..isAntiAlias = false);
      }
    }
  }
  final img = await rec.endRecording().toImage(w, h);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

Future<int Function(int, int)> render(void Function(Canvas, Rect) draw) async {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec), const Rect.fromLTWH(0, 0, 64, 96));
  final img = await rec.endRecording().toImage(64, 96);
  final px = (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
  return (x, y) {
    final i = (y * 64 + x) * 4;
    return (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
  };
}

void main() {
  final m = loadManifest();

  Future<Map<String, Uint8List>> files({bool badBase = false}) async {
    String p(String rel) => 'assets/pixel/$rel';
    return {
      p(m.base['minimi_base']!.sheets['idle']!): badBase
          ? await sheet(const [(Rect.fromLTWH(16, 20, 32, 68), skin0)], w: 200)
          : await sheet(const [(Rect.fromLTWH(16, 20, 32, 68), skin0)]),
      p(m.base['minimi_hair_back']!.sheets['idle']!): await sheet(const [(Rect.fromLTWH(12, 8, 40, 32), hair0)]),
      p(m.base['minimi_hair_front']!.sheets['idle']!): await sheet(const [(Rect.fromLTWH(18, 8, 28, 12), hair0light)]),
      p(m.base['minimi_eyes_0']!.sheets['idle']!): await sheet(const []),
      p(m.base['minimi_mouth_0']!.sheets['idle']!): await sheet(const []),
      p(m['outfit_knit']!.sheets['idle']!): await sheet(const [(Rect.fromLTWH(16, 50, 32, 30), sage)]),
      p(m['acc_glasses']!.sheets['idle']!): await sheet(const [], sideMarker: (const Rect.fromLTWH(50, 30, 4, 4), sky)),
      p(m['acc_starpin']!.sheets['idle']!): await sheet(const [(Rect.fromLTWH(40, 4, 8, 6), butter)]),
      p(m['acc_beanie']!.sheets['idle']!): await sheet(const [(Rect.fromLTWH(14, 2, 36, 14), butter)]),
    };
  }

  Profile profile({String? outfit = 'outfit_knit', String? acc, int skin = 0}) =>
      Profile(minimi: Minimi(skin: skin), outfitId: outfit, accessoryId: acc);

  testWidgets('시트가 없으면 null → 기존 미니미 그림 (예외 없음)', (tester) async {
    await tester.runAsync(() async {
      final reg = AssetRegistry(m, bundle: FakeBundle({}), showDraft: true);
      final p = profile();
      preloadMinimi(reg, p);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(reg.minimiLayers(outfitId: p.outfitId, accessoryId: null, skin: 0, hair: 0), isNull);
      final get = await render(minimiDrawer(p, frame: 0, registry: reg));
      expect(get(32, 60), isNot(0)); // 기존 그림이 무언가를 그렸다
    });
  });

  testWidgets('레이어 순서·겹침·피부색 바꾸기', (tester) async {
    await tester.runAsync(() async {
      final reg = AssetRegistry(m, bundle: FakeBundle(await files()), showDraft: true);
      final p = profile(acc: 'acc_glasses', skin: 2);
      await reg.preloadMinimi(outfitId: p.outfitId, accessoryId: p.accessoryId, skin: 2, hair: 0);
      final layers = reg.minimiLayers(outfitId: p.outfitId, accessoryId: p.accessoryId, skin: 2, hair: 0)!;
      expect(layers.map((l) => l.name), ['hair_back', 'base', 'eyes', 'mouth', 'outfit', 'hair_front', 'acc_face']);

      final get = await render(minimiDrawer(p, frame: 1, registry: reg));
      expect(get(30, 14), hair0light, reason: '앞머리가 뒷머리 위');
      expect(get(30, 60), sage, reason: '옷이 몸 위');
      expect(get(30, 84), skin2, reason: '몸(피부 0번)이 피부 2번 색으로 바뀜');
    });
  });

  testWidgets('측면 왼쪽 = 측면 오른쪽 반전', (tester) async {
    await tester.runAsync(() async {
      final reg = AssetRegistry(m, bundle: FakeBundle(await files()), showDraft: true);
      final p = profile(acc: 'acc_glasses');
      await reg.preloadMinimi(outfitId: p.outfitId, accessoryId: p.accessoryId, skin: 0, hair: 0);
      final right = await render(minimiDrawer(p, frame: 0, registry: reg, facing: MinimiFacing.sideRight));
      final left = await render(minimiDrawer(p, frame: 0, registry: reg, facing: MinimiFacing.sideLeft));
      expect(right(51, 31), sky);
      expect(left(12, 31), sky, reason: '64-1-51 = 12');
      expect(left(51, 31), isNot(sky));
    });
  });

  testWidgets('반전 불가 액세서리에 왼쪽 시트가 없으면 측면 왼쪽은 기존 그림 (섞지 않음)', (tester) async {
    await tester.runAsync(() async {
      final reg = AssetRegistry(m, bundle: FakeBundle(await files()), showDraft: true);
      await reg.preloadMinimi(outfitId: 'outfit_knit', accessoryId: 'acc_starpin', skin: 0, hair: 0);
      expect(
        reg.minimiLayers(outfitId: 'outfit_knit', accessoryId: 'acc_starpin', skin: 0, hair: 0),
        isNotNull,
      );
      expect(
        reg.minimiLayers(
          outfitId: 'outfit_knit',
          accessoryId: 'acc_starpin',
          skin: 0,
          hair: 0,
          facing: MinimiFacing.sideLeft,
        ),
        isNull,
      );
    });
  });

  testWidgets('비니는 앞머리를 가린다', (tester) async {
    await tester.runAsync(() async {
      final reg = AssetRegistry(m, bundle: FakeBundle(await files()), showDraft: true);
      await reg.preloadMinimi(outfitId: 'outfit_knit', accessoryId: 'acc_beanie', skin: 0, hair: 0);
      final layers = reg.minimiLayers(outfitId: 'outfit_knit', accessoryId: 'acc_beanie', skin: 0, hair: 0)!;
      expect(layers.map((l) => l.name), isNot(contains('hair_front')));
      expect(layers.last.name, 'acc_head');
    });
  });

  testWidgets('시트 크기가 틀리면 쓰지 않는다', (tester) async {
    await tester.runAsync(() async {
      final reg = AssetRegistry(m, bundle: FakeBundle(await files(badBase: true)), showDraft: true);
      await reg.preloadMinimi(outfitId: 'outfit_knit', accessoryId: null, skin: 0, hair: 0);
      expect(reg.minimiLayers(outfitId: 'outfit_knit', accessoryId: null, skin: 0, hair: 0), isNull);
      expect(reg.problems.values.join(), contains('크기'));
    });
  });

  testWidgets('출시 모드(draft 숨김)에서는 시트가 있어도 쓰지 않는다', (tester) async {
    await tester.runAsync(() async {
      final reg = AssetRegistry(m, bundle: FakeBundle(await files()), showDraft: false);
      await reg.preloadMinimi(outfitId: 'outfit_knit', accessoryId: null, skin: 0, hair: 0);
      expect(reg.minimiLayers(outfitId: 'outfit_knit', accessoryId: null, skin: 0, hair: 0), isNull);
    });
  });
}
