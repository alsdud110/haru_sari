import 'models.dart';

/// 방의 자리. 자리마다 가구를 하나씩 놓는다.
enum RoomSlot {
  wallpaper('벽지'),
  window('창문'),
  wallDecor('벽 장식'),
  rug('러그'),
  bed('침대'),
  desk('책상'),
  chair('의자'),
  lamp('조명'),
  shelf('선반'),
  plant('식물');

  const RoomSlot(this.label);
  final String label;
}

/// 상점 아이템 종류.
enum ItemKind { furniture, outfit, accessory }

/// 상점·보관함에서 쓰는 분류.
enum ShopCategory {
  all('전체'),
  furniture('가구'),
  decor('소품'),
  wallFloor('벽·바닥'),
  outfit('의상'),
  accessory('액세서리');

  const ShopCategory(this.label);
  final String label;
}

/// 상점 아이템 하나 (가구·의상·액세서리).
/// [variant]는 그림 그릴 때 쓰는 모양 번호다.
/// 나중에 그림 에셋이 생기면 [assetPath]를 채우면 된다.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.price,
    required this.level,
    required this.variant,
    this.kind = ItemKind.furniture,
    this.slot,
    this.assetPath,
  });
  final String id;
  final String name;
  final ItemKind kind;

  /// 가구일 때만
  final RoomSlot? slot;
  final int price;
  final int level;
  final int variant;
  final String? assetPath;

  bool get isFurniture => kind == ItemKind.furniture;

  ShopCategory get category => switch (kind) {
    ItemKind.outfit => ShopCategory.outfit,
    ItemKind.accessory => ShopCategory.accessory,
    ItemKind.furniture => switch (slot!) {
      RoomSlot.bed || RoomSlot.desk || RoomSlot.chair || RoomSlot.shelf => ShopCategory.furniture,
      RoomSlot.lamp || RoomSlot.plant || RoomSlot.wallDecor => ShopCategory.decor,
      RoomSlot.wallpaper || RoomSlot.rug || RoomSlot.window => ShopCategory.wallFloor,
    },
  };

  /// 카드에 쓰는 짧은 분류 이름
  String get typeLabel => switch (kind) {
    ItemKind.outfit => '의상',
    ItemKind.accessory => '액세서리',
    ItemKind.furniture => slot!.label,
  };
}

const _f = ItemKind.furniture;

const shopCatalog = <ShopItem>[
  // 가구
  ShopItem(id: 'rug_round', name: '동그란 러그', kind: _f, slot: RoomSlot.rug, price: 20, level: 1, variant: 0),
  ShopItem(id: 'plant_small', name: '작은 화분', kind: _f, slot: RoomSlot.plant, price: 15, level: 1, variant: 0, assetPath: 'assets/pixel/furniture/decorations/plant_small_r0.png'),
  ShopItem(id: 'lamp_stand', name: '스탠드 조명', kind: _f, slot: RoomSlot.lamp, price: 25, level: 1, variant: 0),
  ShopItem(id: 'desk_wood', name: '원목 책상', kind: _f, slot: RoomSlot.desk, price: 40, level: 2, variant: 0),
  ShopItem(id: 'chair_wood', name: '원목 의자', kind: _f, slot: RoomSlot.chair, price: 25, level: 2, variant: 0),
  ShopItem(id: 'window_curtain', name: '커튼 달린 창', kind: _f, slot: RoomSlot.window, price: 35, level: 2, variant: 0),
  ShopItem(id: 'bed_single', name: '포근한 침대', kind: _f, slot: RoomSlot.bed, price: 60, level: 3, variant: 0),
  ShopItem(id: 'bed_double', name: '체크 더블 침대', kind: _f, slot: RoomSlot.bed, price: 100, level: 3, variant: 2),
  ShopItem(id: 'frame_sun', name: '노을 액자', kind: _f, slot: RoomSlot.wallDecor, price: 20, level: 3, variant: 0),
  ShopItem(id: 'shelf_book', name: '책 선반', kind: _f, slot: RoomSlot.shelf, price: 35, level: 3, variant: 0),
  ShopItem(id: 'rug_stripe', name: '줄무늬 러그', kind: _f, slot: RoomSlot.rug, price: 30, level: 4, variant: 1),
  ShopItem(id: 'plant_big', name: '몬스테라', kind: _f, slot: RoomSlot.plant, price: 45, level: 4, variant: 1),
  ShopItem(id: 'wall_sage', name: '세이지 벽지', kind: _f, slot: RoomSlot.wallpaper, price: 50, level: 4, variant: 1),
  ShopItem(id: 'lamp_pendant', name: '펜던트 조명', kind: _f, slot: RoomSlot.lamp, price: 45, level: 5, variant: 1),
  ShopItem(id: 'desk_white', name: '화이트 책상', kind: _f, slot: RoomSlot.desk, price: 55, level: 5, variant: 1),
  ShopItem(id: 'bed_quilt', name: '퀼트 침대', kind: _f, slot: RoomSlot.bed, price: 80, level: 6, variant: 1),
  ShopItem(id: 'wall_sky', name: '하늘 벽지', kind: _f, slot: RoomSlot.wallpaper, price: 60, level: 6, variant: 2),
  // 의상
  ShopItem(id: 'outfit_knit', name: '크림 니트', kind: ItemKind.outfit, price: 30, level: 1, variant: 1),
  ShopItem(id: 'outfit_stripe', name: '줄무늬 셔츠', kind: ItemKind.outfit, price: 40, level: 2, variant: 2),
  ShopItem(id: 'outfit_overall', name: '멜빵 바지', kind: ItemKind.outfit, price: 50, level: 3, variant: 3),
  ShopItem(id: 'outfit_hoodie', name: '포근한 후드티', kind: ItemKind.outfit, price: 55, level: 4, variant: 4),
  ShopItem(id: 'outfit_pajama', name: '별무늬 잠옷', kind: ItemKind.outfit, price: 60, level: 5, variant: 5),
  // 액세서리
  ShopItem(id: 'acc_starpin', name: '별 머리핀', kind: ItemKind.accessory, price: 20, level: 1, variant: 1),
  ShopItem(id: 'acc_ribbon', name: '리본', kind: ItemKind.accessory, price: 30, level: 2, variant: 2),
  ShopItem(id: 'acc_beanie', name: '니트 비니', kind: ItemKind.accessory, price: 35, level: 3, variant: 3),
  ShopItem(id: 'acc_glasses', name: '동그란 안경', kind: ItemKind.accessory, price: 35, level: 3, variant: 4),
  ShopItem(id: 'acc_headphone', name: '헤드폰', kind: ItemKind.accessory, price: 55, level: 5, variant: 5),
];

ShopItem? itemById(String? id) {
  if (id == null) return null;
  for (final i in shopCatalog) {
    if (i.id == id) return i;
  }
  return null;
}

/// 첫 설정에서 고르는 루틴 템플릿.
class RoutineTemplate {
  const RoutineTemplate(this.name, this.emoji, this.minute, this.weekdays, this.category);
  final String name;
  final String emoji;
  final int? minute;
  final Set<int> weekdays;
  final String category;

  Routine toRoutine(String id) =>
      Routine(id: id, name: name, emoji: emoji, minuteOfDay: minute, weekdays: {...weekdays}, category: category);
}

const _weekdays = {1, 2, 3, 4, 5};
const _everyday = {1, 2, 3, 4, 5, 6, 7};

const routineTemplates = <RoutineTemplate>[
  RoutineTemplate('일어나기', '🌤️', 7 * 60, _everyday, '생활'),
  RoutineTemplate('물 한 잔 마시기', '💧', 7 * 60 + 10, _everyday, '건강'),
  RoutineTemplate('출근 준비', '👔', 7 * 60 + 30, _weekdays, '생활'),
  RoutineTemplate('무사히 출근하기', '🚇', 8 * 60 + 20, _weekdays, '이동'),
  RoutineTemplate('점심 챙겨 먹기', '🍚', 12 * 60, _everyday, '식사'),
  RoutineTemplate('가볍게 운동하기', '🏃', 19 * 60, _everyday, '건강'),
  RoutineTemplate('집에 돌아오기', '🏠', 19 * 60 + 30, _weekdays, '이동'),
  RoutineTemplate('책 몇 장 읽기', '📖', 21 * 60 + 30, _everyday, '마음'),
  RoutineTemplate('씻고 쉬기', '🛁', 22 * 60, _everyday, '생활'),
];
