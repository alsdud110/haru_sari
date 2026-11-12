import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/catalog.dart';
import 'package:haru_sari/data/models.dart';
import 'package:haru_sari/room/palette.dart';
import 'package:haru_sari/room/registry.dart';
import 'package:image/image.dart' as img;

import 'manifest_test.dart' show loadManifest;
import 'scene_test.dart' show FakeBundle;

/// 실제 미니미 시트(tool/draw_minimi.dart 결과) 검증.
void main() {
  final m = loadManifest();
  final paths = {
    for (final b in m.base.values) ...b.sheets.values,
    for (final i in shopCatalog.where((i) => !i.isFurniture)) ...m[i.id]!.sheets.values,
  };

  test('모든 미니미 시트: 256×192, 알파 0/255, 팔레트 색만', () {
    expect(paths.length, 55);
    for (final p in paths) {
      final im = img.decodePng(File('assets/pixel/$p').readAsBytesSync())!;
      expect((im.width, im.height), (MinimiSheet.width, MinimiSheet.height), reason: p);
      for (final px in im) {
        if (px.a == 0) continue;
        expect(px.a, 255, reason: p);
        expect(PixelPalette.all, contains((px.r.toInt() << 16) | (px.g.toInt() << 8) | px.b.toInt()), reason: p);
      }
    }
  });

  testWidgets('기본 차림과 모든 옷·액세서리가 정면·측면 왼쪽 레이어로 조립된다', (tester) async {
    await tester.runAsync(() async {
      final reg = AssetRegistry(
        m,
        bundle: FakeBundle({for (final p in paths) 'assets/pixel/$p': File('assets/pixel/$p').readAsBytesSync()}),
      );
      final looks = <(String?, String?)>[
        (null, null),
        for (final i in shopCatalog.where((i) => !i.isFurniture))
          if (!i.isEarring) i.kind == ItemKind.outfit ? (i.id, null) : (null, i.id),
      ];
      for (final (o, a) in looks) {
        await reg.preloadMinimi(outfitId: o, accessoryId: a, skin: 1, hair: 2, outfit: 3);
        for (final f in [MinimiFacing.front, MinimiFacing.sideLeft]) {
          final layers = reg.minimiLayers(outfitId: o, accessoryId: a, skin: 1, hair: 2, outfit: 3, facing: f);
          expect(layers, isNotNull, reason: '$o $a $f');
          expect(layers!.any((l) => l.name == 'outfit'), isTrue);
        }
      }
      // 머리 모양·눈·입 조합
      for (var i = 0; i < Minimi.hairStyleNames.length; i++) {
        final e = i % Minimi.eyeNames.length, mo = i % Minimi.mouthNames.length;
        await reg.preloadMinimi(outfitId: null, accessoryId: null, skin: 7, hair: 7, hairStyle: i, eyes: e, mouth: mo);
        final layers = reg.minimiLayers(
          outfitId: null,
          accessoryId: null,
          skin: 7,
          hair: 7,
          hairStyle: i,
          eyes: e,
          mouth: mo,
        );
        expect(layers!.map((l) => l.name), MinimiSheet.order.take(6), reason: '머리 $i');
      }
      // 안경과 귀고리를 함께
      await reg.preloadMinimi(
        outfitId: null,
        accessoryId: 'acc_sunglasses',
        earringId: 'acc_ear_hoop',
        skin: 0,
        hair: 0,
      );
      final both = reg.minimiLayers(
        outfitId: null,
        accessoryId: 'acc_sunglasses',
        earringId: 'acc_ear_hoop',
        skin: 0,
        hair: 0,
      );
      expect(both!.map((l) => l.name).skip(6), ['acc_ear', 'acc_face']);
      expect(reg.problems, isEmpty);
    });
  });
}
