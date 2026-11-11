import 'iso.dart';

/// 바닥 위치 (가구·러그)
class FloorPos {
  const FloorPos(this.x, this.y, [this.r = Rot.r0]);
  final int x;
  final int y;
  final Rot r;

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'r': r.index};
  factory FloorPos.fromJson(Map<String, dynamic> j) =>
      FloorPos(j['x'] as int, j['y'] as int, Rot.values[(j['r'] as int?) ?? 0]);

  @override
  bool operator ==(Object other) => other is FloorPos && other.x == x && other.y == y && other.r == r;
  @override
  int get hashCode => Object.hash(x, y, r);
  @override
  String toString() => '($x,$y,${r.name})';
}

/// 벽 위치. [left] = 왼쪽 벽(gx=0 변), [u] = 벽을 따라 몇 번째 칸, [z] = 바닥에서 아래 변까지 높이
class WallPos {
  const WallPos({required this.left, required this.u, required this.z});
  final bool left;
  final int u;
  final int z;

  Map<String, dynamic> toJson() => {'w': left ? 'L' : 'R', 'u': u, 'z': z};
  factory WallPos.fromJson(Map<String, dynamic> j) =>
      WallPos(left: j['w'] == 'L', u: j['u'] as int, z: j['z'] as int);

  @override
  bool operator ==(Object other) => other is WallPos && other.left == left && other.u == u && other.z == z;
  @override
  int get hashCode => Object.hash(left, u, z);
}

/// 방 배치 (docs/asset-system/02 §5). 키는 ShopItem.id라 같은 분류 가구를 여러 개 둘 수 있다.
class RoomLayout {
  RoomLayout({
    Map<String, FloorPos>? floor,
    Map<String, WallPos>? wall,
    this.wallSurface,
    this.floorSurface,
    this.minimi = (4, 4),
    Map<String, FloorPos>? lastFloor,
    Map<String, WallPos>? lastWall,
  })  : floor = floor ?? {},
        wall = wall ?? {},
        lastFloor = lastFloor ?? {},
        lastWall = lastWall ?? {};

  static const version = 1;

  final Map<String, FloorPos> floor;
  final Map<String, WallPos> wall;
  String? wallSurface;
  String? floorSurface;
  (int, int) minimi;

  /// 보관함으로 넣을 때 기억해 둔 마지막 위치 (다시 놓을 때 먼저 시도)
  final Map<String, FloorPos> lastFloor;
  final Map<String, WallPos> lastWall;

  bool contains(String id) => floor.containsKey(id) || wall.containsKey(id) || wallSurface == id || floorSurface == id;

  /// 방에 놓인 아이템 수 (배지 '제법 내 방' 등에 쓴다)
  int get count => floor.length + wall.length + (wallSurface != null ? 1 : 0) + (floorSurface != null ? 1 : 0);

  Iterable<String> get ids => [...floor.keys, ...wall.keys, ?wallSurface, ?floorSurface];

  Map<String, dynamic> toJson() => {
        'v': version,
        'floor': floor.map((k, v) => MapEntry(k, v.toJson())),
        'wall': wall.map((k, v) => MapEntry(k, v.toJson())),
        'surface': {'wall': wallSurface, 'floor': floorSurface},
        'minimi': {'x': minimi.$1, 'y': minimi.$2},
        'lastFloor': lastFloor.map((k, v) => MapEntry(k, v.toJson())),
        'lastWall': lastWall.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory RoomLayout.fromJson(Map<String, dynamic> j) {
    Map<String, T> read<T>(Object? m, T Function(Map<String, dynamic>) f) =>
        ((m as Map?) ?? {}).map((k, v) => MapEntry(k as String, f((v as Map).cast<String, dynamic>())));
    final s = ((j['surface'] as Map?) ?? {}).cast<String, dynamic>();
    final mm = ((j['minimi'] as Map?) ?? {}).cast<String, dynamic>();
    return RoomLayout(
      floor: read(j['floor'], FloorPos.fromJson),
      wall: read(j['wall'], WallPos.fromJson),
      wallSurface: s['wall'] as String?,
      floorSurface: s['floor'] as String?,
      minimi: ((mm['x'] as int?) ?? 4, (mm['y'] as int?) ?? 4),
      lastFloor: read(j['lastFloor'], FloorPos.fromJson),
      lastWall: read(j['lastWall'], WallPos.fromJson),
    );
  }

  /// 기존 '자리' → 새 위치 (기준 장면, 서로 겹치지 않음. 02 §5.3)
  static const legacyFloor = <String, FloorPos>{
    'bed': FloorPos(0, 1),
    'lamp': FloorPos(1, 1),
    'desk': FloorPos(5, 1),
    'chair': FloorPos(5, 2),
    'plant': FloorPos(7, 3),
    'rug': FloorPos(3, 2),
  };
  static const legacyWall = <String, WallPos>{
    'shelf': WallPos(left: false, u: 5, z: 72),
    'window': WallPos(left: true, u: 2, z: 40),
    'wallDecor': WallPos(left: true, u: 5, z: 72),
  };

  /// 기존 `Profile.placed` (자리 이름 → 아이템 id)에서 배치를 만든다.
  /// 알 수 없는 자리나 id는 건너뛴다(그 아이템은 보관함에 남는다).
  factory RoomLayout.fromLegacy(Map<String, String> placed) {
    final l = RoomLayout();
    placed.forEach((slot, id) {
      if (slot == 'wallpaper') {
        l.wallSurface = id;
      } else if (legacyFloor[slot] case final p?) {
        l.floor[id] = p;
      } else if (legacyWall[slot] case final p?) {
        l.wall[id] = p;
      }
    });
    return l;
  }
}
