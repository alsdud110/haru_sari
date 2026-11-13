import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/catalog.dart';
import 'package:haru_sari/room/iso.dart';
import 'package:haru_sari/room/manifest.dart';
import 'package:haru_sari/room/palette.dart';
import 'package:image/image.dart' as img;
import 'package:haru_sari/room/registry.dart';

void main() {
  test('모든 아이템에 분류가 있고 전체는 맨 뒤다', () {
    for (final i in shopCatalog) {
      expect(i.category, isNot(ShopCategory.all), reason: i.id);
    }
    for (final slot in RoomSlot.values) {
      expect(ShopCategory.values.byName(slot.name).label, slot.label);
    }
    expect(ShopCategory.values.last, ShopCategory.all);
  });

  test('원래 색이 정해진 가구: 색마다 id가 있고, 그림에 그 색이 실제로 쓰였다', () async {
    final manifest = PixelManifest.parse(File(PixelManifest.manifestPath).readAsStringSync());
    final items = shopCatalog.where((i) => i.accent != null).toList();
    expect(items.length, greaterThan(40));
    for (final item in items) {
      expect(item.colorIds.length, ItemColor.values.length, reason: item.id);
      for (final id in item.colorIds) {
        expect(itemById(id)?.accent, item.accent, reason: id);
      }
      final art = manifest[item.id]!;
      if (art.layer == ArtLayer.surface) {
        // 벽지·바닥은 색마다 그림을 따로 뽑아 둔다
        final kind = item.slot == RoomSlot.floor ? 'floors' : 'walls';
        for (final id in item.colorIds) {
          final path = '${PixelManifest.assetRoot}${AssetRegistry.surfacePath(kind, id)}';
          expect(File(path).existsSync(), isTrue, reason: path);
        }
        continue;
      }
      // 나머지는 원래 그림에서 그 색 램프를 바꿔 칠한다
      final path = art.layer == ArtLayer.wall ? art.path! : art.rotations[Rot.r0]!;
      final pic = img.decodePng(File('${PixelManifest.assetRoot}$path').readAsBytesSync())!;
      final ramp = PixelPalette.ramps[item.accent!.index];
      var n = 0;
      for (final p in pic) {
        if (p.a > 0 && ramp.contains((p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt())) n++;
      }
      expect(n, greaterThan(40), reason: '${item.id}: 바뀔 색이 거의 없다');
    }
  });

  test('색을 바꿀 램프: 강조색이 충분하면 강조색, 아니면 가장 많이 쓰인 색', () {
    Uint8List px(Map<int, int> counts) => Uint8List.fromList([
      for (final e in counts.entries)
        for (var i = 0; i < e.value; i++) ...[e.key >> 16, (e.key >> 8) & 255, e.key & 255, 255],
    ]);
    final wood = PixelPalette.wood[0], sky = PixelPalette.sky[1], ink = PixelPalette.ink[0];
    expect(recolorRamp(px({wood: 80, sky: 20, ink: 50})), ItemColor.sky.index); // 침대: 이불
    expect(recolorRamp(px({wood: 95, sky: 5})), PixelPalette.ramps.indexOf(PixelPalette.wood)); // 협탁: 몸통
    expect(recolorRamp(px({ink: 10})), -1);
  });
}
