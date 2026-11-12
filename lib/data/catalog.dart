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
  plant('식물'),
  sofa('소파'),
  table('테이블'),
  storage('수납'),
  decor('소품'),
  floor('바닥');

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

  /// 귀고리는 다른 액세서리(안경·모자 등)와 함께 찰 수 있다
  bool get isEarring => id.startsWith('acc_ear_');

  ShopCategory get category => switch (kind) {
    ItemKind.outfit => ShopCategory.outfit,
    ItemKind.accessory => ShopCategory.accessory,
    ItemKind.furniture => switch (slot!) {
      RoomSlot.bed || RoomSlot.desk || RoomSlot.chair || RoomSlot.shelf => ShopCategory.furniture,
      RoomSlot.sofa || RoomSlot.table || RoomSlot.storage => ShopCategory.furniture,
      RoomSlot.lamp || RoomSlot.plant || RoomSlot.wallDecor || RoomSlot.decor => ShopCategory.decor,
      RoomSlot.wallpaper || RoomSlot.rug || RoomSlot.window || RoomSlot.floor => ShopCategory.wallFloor,
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
  ShopItem(
    id: 'plant_small',
    name: '작은 화분',
    kind: _f,
    slot: RoomSlot.plant,
    price: 15,
    level: 1,
    variant: 0,
    assetPath: 'assets/pixel/furniture/decorations/plant_small_r0.png',
  ),
  ShopItem(id: 'desk_wood', name: '원목 책상', kind: _f, slot: RoomSlot.desk, price: 40, level: 2, variant: 0),
  ShopItem(id: 'chair_wood', name: '원목 의자', kind: _f, slot: RoomSlot.chair, price: 25, level: 2, variant: 0),
  ShopItem(id: 'window_curtain', name: '커튼 달린 창', kind: _f, slot: RoomSlot.window, price: 35, level: 2, variant: 0),
  ShopItem(id: 'bed_single', name: '포근한 침대', kind: _f, slot: RoomSlot.bed, price: 60, level: 3, variant: 0),
  ShopItem(id: 'bed_double', name: '체크 더블 침대', kind: _f, slot: RoomSlot.bed, price: 100, level: 3, variant: 2),
  ShopItem(id: 'frame_sun', name: '노을 액자', kind: _f, slot: RoomSlot.wallDecor, price: 20, level: 3, variant: 0),
  ShopItem(id: 'shelf_book', name: '책 선반', kind: _f, slot: RoomSlot.shelf, price: 35, level: 3, variant: 0),
  ShopItem(id: 'rug_stripe', name: '줄무늬 러그', kind: _f, slot: RoomSlot.rug, price: 30, level: 4, variant: 1),
  ShopItem(id: 'wall_sage', name: '세이지 벽지', kind: _f, slot: RoomSlot.wallpaper, price: 50, level: 4, variant: 1),
  ShopItem(id: 'desk_white', name: '화이트 책상', kind: _f, slot: RoomSlot.desk, price: 55, level: 5, variant: 1),
  ShopItem(id: 'bed_quilt', name: '퀼트 침대', kind: _f, slot: RoomSlot.bed, price: 80, level: 6, variant: 1),
  ShopItem(id: 'wall_sky', name: '하늘 벽지', kind: _f, slot: RoomSlot.wallpaper, price: 60, level: 6, variant: 2),
  // 가구·소품·벽·바닥 2차 (그림은 모두 코드로 그린 대체 그림)
  ShopItem(id: 'bed_pink', name: '딸기 침대', kind: _f, slot: RoomSlot.bed, price: 85, level: 5, variant: 3),
  ShopItem(id: 'bed_lavender', name: '라벤더 침대', kind: _f, slot: RoomSlot.bed, price: 90, level: 7, variant: 5),
  ShopItem(id: 'bed_navy', name: '밤하늘 더블 침대', kind: _f, slot: RoomSlot.bed, price: 130, level: 8, variant: 4),
  ShopItem(id: 'desk_dark', name: '월넛 책상', kind: _f, slot: RoomSlot.desk, price: 60, level: 6, variant: 2),
  ShopItem(id: 'desk_vanity', name: '화장대', kind: _f, slot: RoomSlot.desk, price: 75, level: 7, variant: 0),
  ShopItem(id: 'chair_stool', name: '스툴', kind: _f, slot: RoomSlot.chair, price: 20, level: 1, variant: 0),
  ShopItem(id: 'chair_white', name: '화이트 의자', kind: _f, slot: RoomSlot.chair, price: 30, level: 3, variant: 1),
  ShopItem(id: 'chair_bean', name: '빈백', kind: _f, slot: RoomSlot.chair, price: 45, level: 4, variant: 0),
  ShopItem(id: 'sofa_single', name: '1인 소파', kind: _f, slot: RoomSlot.sofa, price: 55, level: 2, variant: 0),
  ShopItem(id: 'sofa_cream', name: '크림 소파', kind: _f, slot: RoomSlot.sofa, price: 90, level: 4, variant: 0),
  ShopItem(id: 'sofa_sage', name: '세이지 소파', kind: _f, slot: RoomSlot.sofa, price: 95, level: 6, variant: 0),
  ShopItem(id: 'sofa_pink', name: '핑크 소파', kind: _f, slot: RoomSlot.sofa, price: 100, level: 8, variant: 0),
  ShopItem(id: 'table_side', name: '사이드 테이블', kind: _f, slot: RoomSlot.table, price: 30, level: 2, variant: 0),
  ShopItem(id: 'table_coffee', name: '커피 테이블', kind: _f, slot: RoomSlot.table, price: 45, level: 3, variant: 0),
  ShopItem(id: 'table_dining', name: '식탁', kind: _f, slot: RoomSlot.table, price: 85, level: 6, variant: 0),
  ShopItem(id: 'nightstand', name: '협탁', kind: _f, slot: RoomSlot.storage, price: 35, level: 2, variant: 0),
  ShopItem(id: 'shelf_cube', name: '큐브 수납장', kind: _f, slot: RoomSlot.storage, price: 45, level: 3, variant: 0),
  ShopItem(id: 'drawer_wood', name: '원목 서랍장', kind: _f, slot: RoomSlot.storage, price: 65, level: 4, variant: 0),
  ShopItem(id: 'bookcase_tall', name: '책장', kind: _f, slot: RoomSlot.storage, price: 80, level: 5, variant: 0),
  ShopItem(id: 'wardrobe_white', name: '옷장', kind: _f, slot: RoomSlot.storage, price: 100, level: 6, variant: 0),
  ShopItem(id: 'tv_stand', name: 'TV와 거실장', kind: _f, slot: RoomSlot.storage, price: 110, level: 7, variant: 0),
  ShopItem(id: 'fridge_mint', name: '미니 냉장고', kind: _f, slot: RoomSlot.storage, price: 90, level: 8, variant: 0),
  ShopItem(id: 'plant_cactus', name: '선인장', kind: _f, slot: RoomSlot.plant, price: 20, level: 2, variant: 0),
  ShopItem(id: 'plant_flower', name: '꽃 화분', kind: _f, slot: RoomSlot.plant, price: 25, level: 3, variant: 0),
  ShopItem(id: 'plant_tree', name: '올리브 나무', kind: _f, slot: RoomSlot.plant, price: 55, level: 6, variant: 0),
  ShopItem(id: 'lamp_mood', name: '무드등', kind: _f, slot: RoomSlot.lamp, price: 30, level: 2, variant: 0),
  ShopItem(id: 'lamp_floor', name: '장스탠드', kind: _f, slot: RoomSlot.lamp, price: 50, level: 4, variant: 0),
  ShopItem(id: 'decor_books', name: '책 더미', kind: _f, slot: RoomSlot.decor, price: 15, level: 1, variant: 0),
  ShopItem(id: 'decor_bear', name: '곰 인형', kind: _f, slot: RoomSlot.decor, price: 35, level: 3, variant: 0),
  ShopItem(id: 'decor_fishbowl', name: '어항', kind: _f, slot: RoomSlot.decor, price: 50, level: 5, variant: 0),
  ShopItem(id: 'decor_mirror', name: '전신 거울', kind: _f, slot: RoomSlot.decor, price: 55, level: 5, variant: 0),
  ShopItem(id: 'decor_cattower', name: '캣타워', kind: _f, slot: RoomSlot.decor, price: 90, level: 7, variant: 0),
  ShopItem(id: 'decor_xmas', name: '크리스마스 트리', kind: _f, slot: RoomSlot.decor, price: 80, level: 9, variant: 0),
  ShopItem(id: 'rug_sage', name: '세이지 러그', kind: _f, slot: RoomSlot.rug, price: 25, level: 2, variant: 0),
  ShopItem(id: 'rug_checker', name: '체크 러그', kind: _f, slot: RoomSlot.rug, price: 35, level: 3, variant: 0),
  ShopItem(id: 'rug_runner', name: '복도 러그', kind: _f, slot: RoomSlot.rug, price: 30, level: 3, variant: 0),
  ShopItem(id: 'rug_pink', name: '핑크 러그', kind: _f, slot: RoomSlot.rug, price: 35, level: 5, variant: 0),
  ShopItem(id: 'rug_navy', name: '네이비 러그', kind: _f, slot: RoomSlot.rug, price: 45, level: 6, variant: 0),
  ShopItem(id: 'rug_picnic', name: '피크닉 매트', kind: _f, slot: RoomSlot.rug, price: 50, level: 7, variant: 0),
  ShopItem(id: 'rug_big', name: '큰 원형 러그', kind: _f, slot: RoomSlot.rug, price: 70, level: 8, variant: 0),
  ShopItem(id: 'frame_sea', name: '바다 액자', kind: _f, slot: RoomSlot.wallDecor, price: 25, level: 2, variant: 1),
  ShopItem(id: 'clock_round', name: '벽시계', kind: _f, slot: RoomSlot.wallDecor, price: 30, level: 3, variant: 3),
  ShopItem(id: 'frame_flower', name: '꽃 액자', kind: _f, slot: RoomSlot.wallDecor, price: 25, level: 4, variant: 2),
  ShopItem(id: 'mirror_round', name: '둥근 거울', kind: _f, slot: RoomSlot.wallDecor, price: 40, level: 5, variant: 4),
  ShopItem(id: 'poster_night', name: '밤하늘 포스터', kind: _f, slot: RoomSlot.wallDecor, price: 35, level: 6, variant: 5),
  ShopItem(id: 'window_round', name: '둥근 창', kind: _f, slot: RoomSlot.window, price: 45, level: 4, variant: 1),
  ShopItem(id: 'window_blind', name: '블라인드 창', kind: _f, slot: RoomSlot.window, price: 50, level: 5, variant: 2),
  ShopItem(id: 'window_night', name: '밤 창문', kind: _f, slot: RoomSlot.window, price: 60, level: 7, variant: 3),
  ShopItem(id: 'shelf_plant', name: '화분 선반', kind: _f, slot: RoomSlot.shelf, price: 40, level: 4, variant: 1),
  ShopItem(id: 'wall_pink', name: '핑크 벽지', kind: _f, slot: RoomSlot.wallpaper, price: 50, level: 3, variant: 0),
  ShopItem(id: 'wall_butter', name: '버터 벽지', kind: _f, slot: RoomSlot.wallpaper, price: 50, level: 5, variant: 0),
  ShopItem(id: 'wall_grey', name: '그레이 벽지', kind: _f, slot: RoomSlot.wallpaper, price: 55, level: 5, variant: 0),
  ShopItem(id: 'wall_stripe', name: '줄무늬 벽지', kind: _f, slot: RoomSlot.wallpaper, price: 65, level: 6, variant: 0),
  ShopItem(id: 'wall_lavender', name: '라벤더 벽지', kind: _f, slot: RoomSlot.wallpaper, price: 60, level: 7, variant: 0),
  ShopItem(
    id: 'wall_panel_sage',
    name: '세이지 패널 벽',
    kind: _f,
    slot: RoomSlot.wallpaper,
    price: 75,
    level: 7,
    variant: 0,
  ),
  ShopItem(id: 'wall_panel_wood', name: '원목 패널 벽', kind: _f, slot: RoomSlot.wallpaper, price: 75, level: 8, variant: 0),
  ShopItem(id: 'wall_night', name: '밤하늘 벽지', kind: _f, slot: RoomSlot.wallpaper, price: 80, level: 9, variant: 0),
  ShopItem(id: 'floor_light', name: '밝은 원목 바닥', kind: _f, slot: RoomSlot.floor, price: 40, level: 2, variant: 0),
  ShopItem(id: 'floor_carpet_grey', name: '그레이 카펫', kind: _f, slot: RoomSlot.floor, price: 55, level: 3, variant: 0),
  ShopItem(id: 'floor_walnut', name: '월넛 바닥', kind: _f, slot: RoomSlot.floor, price: 50, level: 4, variant: 0),
  ShopItem(id: 'floor_checker', name: '체크 타일', kind: _f, slot: RoomSlot.floor, price: 60, level: 5, variant: 0),
  ShopItem(id: 'floor_tile_sky', name: '하늘 타일', kind: _f, slot: RoomSlot.floor, price: 60, level: 6, variant: 0),
  ShopItem(id: 'floor_carpet_pink', name: '핑크 카펫', kind: _f, slot: RoomSlot.floor, price: 55, level: 6, variant: 0),
  ShopItem(id: 'floor_tile_sage', name: '민트 타일', kind: _f, slot: RoomSlot.floor, price: 60, level: 7, variant: 0),
  ShopItem(id: 'floor_tile_terra', name: '테라코타 타일', kind: _f, slot: RoomSlot.floor, price: 65, level: 8, variant: 0),
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
  // 안경 (기존 그림에서는 모두 동그란 안경으로 보인다)
  ShopItem(id: 'acc_glasses_horn', name: '뿔테 안경', kind: ItemKind.accessory, price: 35, level: 2, variant: 4),
  ShopItem(id: 'acc_glasses_rimless', name: '무테 안경', kind: ItemKind.accessory, price: 40, level: 3, variant: 4),
  ShopItem(id: 'acc_sunglasses', name: '선글라스', kind: ItemKind.accessory, price: 50, level: 4, variant: 4),
  ShopItem(id: 'acc_sunglasses_heart', name: '하트 선글라스', kind: ItemKind.accessory, price: 60, level: 5, variant: 4),
  // 귀고리 (기존 그림에는 없다)
  ShopItem(id: 'acc_ear_pearl', name: '진주 귀고리', kind: ItemKind.accessory, price: 25, level: 1, variant: 0),
  ShopItem(id: 'acc_ear_hoop', name: '링 귀고리', kind: ItemKind.accessory, price: 30, level: 2, variant: 0),
  ShopItem(id: 'acc_ear_heart', name: '하트 귀고리', kind: ItemKind.accessory, price: 35, level: 3, variant: 0),
  ShopItem(id: 'acc_ear_star', name: '별 귀고리', kind: ItemKind.accessory, price: 40, level: 4, variant: 0),
  ShopItem(id: 'acc_ear_drop', name: '물방울 귀고리', kind: ItemKind.accessory, price: 45, level: 5, variant: 0),
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
  RoutineTemplate('일어나기', '🌤️', 7 * 60, _everyday, '기상·수면'),
  RoutineTemplate('물 한 잔 마시기', '💧', 7 * 60 + 10, _everyday, '물·영양'),
  RoutineTemplate('출근 준비', '👔', 7 * 60 + 30, _weekdays, '씻기·단장'),
  RoutineTemplate('무사히 출근하기', '🚇', 8 * 60 + 20, _weekdays, '이동'),
  RoutineTemplate('점심 챙겨 먹기', '🍚', 12 * 60, _everyday, '식사'),
  RoutineTemplate('가볍게 운동하기', '🏃', 19 * 60, _everyday, '운동'),
  RoutineTemplate('집에 돌아오기', '🏠', 19 * 60 + 30, _weekdays, '이동'),
  RoutineTemplate('책 몇 장 읽기', '📖', 21 * 60 + 30, _everyday, '공부'),
  RoutineTemplate('씻고 쉬기', '🛁', 22 * 60, _everyday, '씻기·단장'),
];
