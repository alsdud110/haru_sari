import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/catalog.dart';
import 'package:haru_sari/room/palette.dart';
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
