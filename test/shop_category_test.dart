import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/catalog.dart';

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
}
