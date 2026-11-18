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
    expect(paths.length, 114);
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

  test('색을 바꿀 수 있는 산 옷: 적어 둔 색을 실제로 쓰고, 신발 색과 겹치지 않는다', () {
    final clothes = shopCatalog.where((i) => i.kind == ItemKind.outfit).toList();
    expect(clothes.where((i) => m[i.id]?.recolor == null), isEmpty, reason: '모든 의상은 색을 바꿀 수 있다');
    for (final i in clothes) {
      final art = m[i.id]!;
      final im = img.decodePng(File('assets/pixel/${art.sheets['idle']}').readAsBytesSync())!;
      final used = {for (final px in im) if (px.a > 0) (px.r.toInt() << 16) | (px.g.toInt() << 8) | px.b.toInt()};
      expect(used, contains(art.recolor![1]), reason: i.id);
      // 신발을 그리는 옷(하의·세트)은 신발 색이 함께 바뀌면 안 된다
      if (i.group != ShopCategory.top) {
        expect(art.recolor, isNot(contains(0xFFF8EE)), reason: i.id);
        expect(art.recolor, isNot(contains(0xD6C2A8)), reason: i.id);
      }
    }
  });

  test('모든 미니미 시트의 폴더가 pubspec 에셋에 들어 있다 (빠지면 앱에서 미니미가 옛 그림으로 바뀐다)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final p in paths) {
      final dir = 'assets/pixel/${p.substring(0, p.lastIndexOf('/') + 1)}';
      expect(pubspec, contains('- $dir'), reason: p);
    }
  });

  testWidgets('기본 차림과 모든 옷·액세서리가 정면·측면 왼쪽 레이어로 조립된다', (tester) async {
    await tester.runAsync(() async {
      final reg = AssetRegistry(
        m,
        bundle: FakeBundle({for (final p in paths) 'assets/pixel/$p': File('assets/pixel/$p').readAsBytesSync()}),
      );
      // (상의·세트, 하의, 액세서리). 하의는 하의 자리에 입는다
      final looks = <(String?, String?, String?)>[
        (null, null, null),
        for (final i in shopCatalog.where((i) => !i.isFurniture && !i.isEarring))
          i.kind == ItemKind.accessory ? (null, null, i.id) : (i.isBottom ? (null, i.id, null) : (i.id, null, null)),
        ('outfit_blouse', 'outfit_tennis_skirt', 'acc_band_bunny'),
      ];
      for (final (o, b, a) in looks) {
        await reg.preloadMinimi(outfitId: o, bottomId: b, accessoryId: a, skin: 1, hair: 2, outfit: 3);
        for (final f in [MinimiFacing.front, MinimiFacing.sideLeft]) {
          final layers = reg.minimiLayers(
            outfitId: o,
            bottomId: b,
            accessoryId: a,
            skin: 1,
            hair: 2,
            outfit: 3,
            facing: f,
          );
          expect(layers, isNotNull, reason: '$o $b $a $f');
          final names = layers!.map((l) => l.name).toList();
          expect(names, contains('outfit'));
          // 원피스·세트를 입으면 하의 레이어가 없다
          expect(names.contains('bottom'), !(itemById(o)?.isSet ?? false), reason: '$o');
        }
      }
      // 머리 모양·눈·입·무늬·하의 조합
      for (var i = 0; i < Minimi.hairStyleNames.length; i++) {
        final e = i % Minimi.eyeNames.length, mo = i % Minimi.mouthNames.length;
        final pt = i % Minimi.patternNames.length, bt = i % Minimi.bottomNames.length;
        await reg.preloadMinimi(
          outfitId: null,
          accessoryId: null,
          skin: 7,
          hair: 7,
          outfit: i % 12,
          hairStyle: i,
          eyes: e,
          mouth: mo,
          pattern: pt,
          bottom: bt,
          bottomColor: i % 12,
        );
        final layers = reg.minimiLayers(
          outfitId: null,
          accessoryId: null,
          skin: 7,
          hair: 7,
          outfit: i % 12,
          hairStyle: i,
          eyes: e,
          mouth: mo,
          pattern: pt,
          bottom: bt,
          bottomColor: i % 12,
        );
        expect(layers!.map((l) => l.name), MinimiSheet.order.take(7), reason: '머리 $i');
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
      expect(both!.map((l) => l.name).skip(7), ['acc_ear', 'acc_face']);
      expect(reg.problems, isEmpty);
    });
  });
}
