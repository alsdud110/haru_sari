import 'iso.dart';
import 'layout.dart';
import 'manifest.dart';

enum PlaceStatus { ok, outOfRoom, blocked, notPlaceable }

class PlaceCheck {
  const PlaceCheck(this.status, [this.blocker]);
  final PlaceStatus status;
  final String? blocker;
  bool get ok => status == PlaceStatus.ok;

  @override
  String toString() => blocker == null ? status.name : '${status.name}($blocker)';
}

/// 충돌 검사와 빈 자리 찾기 (docs/asset-system/02 §6).
class Occupancy {
  Occupancy(this.manifest);
  final PixelManifest manifest;

  /// 같은 격자에서 겹치면 안 되는 묶음: 막는 물체끼리, 러그끼리
  String? _group(ItemArt a) => switch (a.layer) {
        ArtLayer.object => a.blocking ? 'block' : null,
        ArtLayer.floorDecor => 'decor',
        _ => null,
      };

  (int, int, int, int) rectOf(String id, FloorPos p) {
    final (w, d) = manifest[id]!.footprintFor(p.r);
    return (p.x, p.y, w, d);
  }

  static bool _overlap((int, int, int, int) a, (int, int, int, int) b) =>
      a.$1 < b.$1 + b.$3 && b.$1 < a.$1 + a.$3 && a.$2 < b.$2 + b.$4 && b.$2 < a.$2 + a.$4;

  PlaceCheck canPlaceFloor(RoomLayout l, String id, FloorPos p) {
    final art = manifest[id];
    if (art == null || !art.isFloor) return const PlaceCheck(PlaceStatus.notPlaceable);
    if (p.r == Rot.r1 && !art.rotatable) return const PlaceCheck(PlaceStatus.notPlaceable);
    final me = rectOf(id, p);
    if (!IsoGrid.inRoom(me.$1, me.$2, me.$3, me.$4)) return const PlaceCheck(PlaceStatus.outOfRoom);
    final g = _group(art);
    if (g == null) return const PlaceCheck(PlaceStatus.ok);
    for (final e in l.floor.entries) {
      if (e.key == id) continue;
      final other = manifest[e.key];
      if (other == null || _group(other) != g) continue;
      if (_overlap(me, rectOf(e.key, e.value))) return PlaceCheck(PlaceStatus.blocked, e.key);
    }
    return const PlaceCheck(PlaceStatus.ok);
  }

  PlaceCheck canPlaceWall(RoomLayout l, String id, WallPos p) {
    final art = manifest[id];
    if (art == null || art.layer != ArtLayer.wall) return const PlaceCheck(PlaceStatus.notPlaceable);
    if (p.u < 0 || p.u + art.span > IsoGrid.size) return const PlaceCheck(PlaceStatus.outOfRoom);
    if (p.z < art.zRange.$1 || p.z > art.zRange.$2 || p.z + art.height > IsoGrid.wallH - 8) {
      return const PlaceCheck(PlaceStatus.outOfRoom);
    }
    for (final e in l.wall.entries) {
      if (e.key == id || e.value.left != p.left) continue;
      final o = manifest[e.key];
      if (o == null) continue;
      if (p.u < e.value.u + o.span && e.value.u < p.u + art.span) return PlaceCheck(PlaceStatus.blocked, e.key);
    }
    return const PlaceCheck(PlaceStatus.ok);
  }

  /// 방 가운데(4,4)에서 가까운 순으로 R0, R1을 차례로 시도한다.
  FloorPos? findFloorSpot(RoomLayout l, String id, {FloorPos? prefer}) {
    if (prefer != null && canPlaceFloor(l, id, prefer).ok) return prefer;
    final art = manifest[id];
    if (art == null || !art.isFloor) return null;
    final cells = [
      for (var y = 0; y < IsoGrid.size; y++)
        for (var x = 0; x < IsoGrid.size; x++) (x, y),
    ]..sort((a, b) {
        final da = (a.$1 - 4).abs() + (a.$2 - 4).abs(), db = (b.$1 - 4).abs() + (b.$2 - 4).abs();
        if (da != db) return da.compareTo(db);
        if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
        return a.$1.compareTo(b.$1);
      });
    for (final r in [Rot.r0, if (art.rotatable) Rot.r1]) {
      for (final (x, y) in cells) {
        final p = FloorPos(x, y, r);
        if (canPlaceFloor(l, id, p).ok) return p;
      }
    }
    return null;
  }

  WallPos? findWallSpot(RoomLayout l, String id, {WallPos? prefer}) {
    if (prefer != null && canPlaceWall(l, id, prefer).ok) return prefer;
    final art = manifest[id];
    if (art == null || art.layer != ArtLayer.wall) return null;
    final z = art.zRange.$1 + ((art.zRange.$2 - art.zRange.$1) ~/ 2) ~/ 8 * 8;
    for (final left in [true, false]) {
      for (var u = 0; u + art.span <= IsoGrid.size; u++) {
        final p = WallPos(left: left, u: u, z: z);
        if (canPlaceWall(l, id, p).ok) return p;
      }
    }
    return null;
  }

  /// 막는 가구가 차지한 칸인지
  bool tileBlocked(RoomLayout l, int x, int y) {
    for (final e in l.floor.entries) {
      final a = manifest[e.key];
      if (a == null || _group(a) != 'block') continue;
      if (_overlap(rectOf(e.key, e.value), (x, y, 1, 1))) return true;
    }
    return false;
  }

  /// 미니미가 설 수 있는 가장 가까운 칸 (없으면 그대로)
  (int, int) minimiSpot(RoomLayout l, (int, int) from) {
    if (IsoGrid.inRoom(from.$1, from.$2) && !tileBlocked(l, from.$1, from.$2)) return from;
    (int, int)? best;
    var bestD = 1 << 30;
    for (var y = 0; y < IsoGrid.size; y++) {
      for (var x = 0; x < IsoGrid.size; x++) {
        if (tileBlocked(l, x, y)) continue;
        final dd = (x - from.$1).abs() + (y - from.$2).abs();
        if (dd < bestD) {
          bestD = dd;
          best = (x, y);
        }
      }
    }
    return best ?? from;
  }

  /// 마이그레이션 뒤 안전장치: 겹치거나 방 밖인 것을 빈 자리로 옮기고, 자리가 없으면 뺀다.
  /// 빠진 아이템 id 목록을 돌려준다(보관함으로 간다).
  List<String> repair(RoomLayout l) {
    final dropped = <String>[];
    for (final id in [...l.floor.keys]) {
      final p = l.floor.remove(id)!;
      final spot = findFloorSpot(l, id, prefer: p);
      if (spot == null) {
        dropped.add(id);
      } else {
        l.floor[id] = spot;
      }
    }
    for (final id in [...l.wall.keys]) {
      final p = l.wall.remove(id)!;
      final spot = findWallSpot(l, id, prefer: p);
      if (spot == null) {
        dropped.add(id);
      } else {
        l.wall[id] = spot;
      }
    }
    l.minimi = minimiSpot(l, l.minimi);
    return dropped;
  }
}
