import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oneul_sari/room/depth.dart';
import 'package:oneul_sari/room/iso.dart';
import 'package:oneul_sari/room/layout.dart';
import 'package:oneul_sari/room/manifest.dart';
import 'package:oneul_sari/room/occupancy.dart';

import 'manifest_test.dart' show loadManifest;

void main() {
  final m = loadManifest();
  final occ = Occupancy(m);

  group('배치 데이터', () {
    test('JSON 저장·복원', () {
      final l = RoomLayout(
        floor: {'bed_single': const FloorPos(0, 1), 'desk_wood': const FloorPos(5, 1, Rot.r1)},
        wall: {'window_curtain': const WallPos(left: true, u: 2, z: 40)},
        wallSurface: 'wall_sage',
        minimi: (3, 6),
        lastFloor: {'chair_wood': const FloorPos(5, 2)},
      );
      final back = RoomLayout.fromJson(l.toJson());
      expect(back.floor, l.floor);
      expect(back.wall, l.wall);
      expect(back.wallSurface, 'wall_sage');
      expect(back.minimi, (3, 6));
      expect(back.lastFloor, l.lastFloor);
      expect(back.count, 4);
    });

    test('같은 분류 가구를 여러 개 둘 수 있다 (키 = 아이템 id)', () {
      final l = RoomLayout(floor: {'bed_single': const FloorPos(0, 1), 'bed_quilt': const FloorPos(0, 4)});
      expect(occ.canPlaceFloor(l, 'bed_quilt', const FloorPos(0, 4)).ok, isTrue);
      expect(l.floor.length, 2);
    });
  });

  group('기존 데이터 이전 (placed → room)', () {
    test('모든 자리를 기준 장면 위치로 옮기고 아무것도 잃지 않는다', () {
      final legacy = {
        'bed': 'bed_single',
        'lamp': 'lamp_stand',
        'desk': 'desk_wood',
        'chair': 'chair_wood',
        'plant': 'plant_small',
        'rug': 'rug_round',
        'shelf': 'shelf_book',
        'window': 'window_curtain',
        'wallDecor': 'frame_sun',
        'wallpaper': 'wall_sage',
      };
      final l = RoomLayout.fromLegacy(legacy);
      final dropped = occ.repair(l);
      expect(dropped, isEmpty);
      expect(l.count, 10);
      expect(l.floor['bed_single'], const FloorPos(0, 1));
      expect(l.wall['window_curtain'], const WallPos(left: true, u: 2, z: 40));
      expect(l.wallSurface, 'wall_sage');
      for (final e in l.floor.entries) {
        expect(occ.canPlaceFloor(l, e.key, e.value).ok, isTrue, reason: e.key);
      }
      for (final e in l.wall.entries) {
        expect(occ.canPlaceWall(l, e.key, e.value).ok, isTrue, reason: e.key);
      }
      expect(occ.tileBlocked(l, l.minimi.$1, l.minimi.$2), isFalse);
    });

    test('빈 placed는 빈 방', () {
      final l = RoomLayout.fromLegacy({});
      expect(l.count, 0);
      expect(l.minimi, (4, 4));
    });
  });

  group('충돌 검사', () {
    final base = RoomLayout(floor: {'bed_single': const FloorPos(0, 1), 'rug_round': const FloorPos(3, 2)});

    test('방 밖', () {
      expect(occ.canPlaceFloor(base, 'desk_wood', const FloorPos(7, 0)).status, PlaceStatus.outOfRoom);
      expect(occ.canPlaceFloor(base, 'desk_wood', const FloorPos(7, 0, Rot.r1)).ok, isTrue); // 회전하면 1×2로 들어감
      expect(occ.canPlaceFloor(base, 'chair_wood', const FloorPos(-1, 0)).status, PlaceStatus.outOfRoom);
    });

    test('가구끼리 겹침', () {
      final c = occ.canPlaceFloor(base, 'chair_wood', const FloorPos(0, 2));
      expect(c.status, PlaceStatus.blocked);
      expect(c.blocker, 'bed_single');
    });

    test('러그 위에는 가구를 놓을 수 있고, 러그끼리는 겹칠 수 없다', () {
      expect(occ.canPlaceFloor(base, 'chair_wood', const FloorPos(3, 2)).ok, isTrue);
      expect(occ.canPlaceFloor(base, 'rug_stripe', const FloorPos(4, 3)).status, PlaceStatus.blocked);
    });

    test('회전 불가 아이템은 R1 불가, 자기 자신과는 충돌하지 않는다', () {
      expect(occ.canPlaceFloor(base, 'bed_single', const FloorPos(0, 1, Rot.r1)).ok, isTrue);
      expect(occ.canPlaceFloor(base, 'wall_sage', const FloorPos(0, 0)).status, PlaceStatus.notPlaceable);
    });

    test('벽: 같은 벽 칸 겹침, 높이 범위', () {
      final l = RoomLayout(wall: {'window_curtain': const WallPos(left: true, u: 2, z: 40)});
      expect(occ.canPlaceWall(l, 'frame_sun', const WallPos(left: true, u: 3, z: 72)).status, PlaceStatus.blocked);
      expect(occ.canPlaceWall(l, 'frame_sun', const WallPos(left: false, u: 3, z: 72)).ok, isTrue);
      expect(occ.canPlaceWall(l, 'frame_sun', const WallPos(left: true, u: 5, z: 200)).status, PlaceStatus.outOfRoom);
      expect(occ.canPlaceWall(l, 'shelf_book', const WallPos(left: true, u: 7, z: 72)).status, PlaceStatus.outOfRoom);
    });
  });

  group('빈 자리 찾기', () {
    test('가운데에서 가까운 빈 자리', () {
      final p = occ.findFloorSpot(RoomLayout(), 'chair_wood');
      expect(p, const FloorPos(4, 4));
    });

    test('가득 차면 null (테스트용 매니페스트: 2×2 블록 16개로 방을 채움)', () {
      final blocks = [for (var i = 0; i < 16; i++) '"b$i": {"layer": "object", "footprint": [2, 2], "height": 8}'];
      final tm = PixelManifest.parse(
        '{"items": {${blocks.join(',')}, "chair": {"layer": "object", "footprint": [1, 1], "height": 8}}}',
      );
      final o = Occupancy(tm);
      final full = RoomLayout(floor: {
        for (var i = 0; i < 16; i++) 'b$i': FloorPos((i % 4) * 2, (i ~/ 4) * 2),
      });
      expect(o.findFloorSpot(full, 'chair'), isNull);
      full.floor.remove('b5');
      expect(o.findFloorSpot(full, 'chair'), isNotNull);
    });

    test('미니미 칸이 막히면 가장 가까운 빈 칸으로', () {
      final l = RoomLayout(floor: {'chair_wood': const FloorPos(4, 4)}, minimi: (4, 4));
      final s = occ.minimiSpot(l, l.minimi);
      expect(s, isNot((4, 4)));
      expect((s.$1 - 4).abs() + (s.$2 - 4).abs(), 1);
    });
  });

  group('깊이 정렬', () {
    test('기준 장면', () {
      final order = depthSort(const [
        DepthItem('plant', 7, 3, 1, 1),
        DepthItem('minimi', 4, 4, 1, 1),
        DepthItem('chair', 5, 2, 1, 1),
        DepthItem('desk', 5, 1, 2, 1),
        DepthItem('lamp', 1, 1, 1, 1),
        DepthItem('bed', 0, 1, 1, 2),
      ]).map((e) => e.id).toList();
      expect(order, ['bed', 'lamp', 'desk', 'chair', 'minimi', 'plant']);
    });

    test('무작위 배치 200회: 확실히 앞인 물체는 항상 나중에 그린다', () {
      final rnd = Random(7);
      for (var t = 0; t < 200; t++) {
        final items = <DepthItem>[];
        for (var tries = 0; tries < 40 && items.length < 8; tries++) {
          final w = rnd.nextInt(2) + 1, d = rnd.nextInt(2) + 1;
          final x = rnd.nextInt(9 - w), y = rnd.nextInt(9 - d);
          final c = DepthItem('i$tries', x, y, w, d);
          final clash = items.any((o) => c.x < o.x + o.w && o.x < c.x + c.w && c.y < o.y + o.d && o.y < c.y + c.d);
          if (!clash) items.add(c);
        }
        final order = depthSort(items);
        for (var i = 0; i < order.length; i++) {
          for (var j = i + 1; j < order.length; j++) {
            final a = order[i], b = order[j];
            expect(a.inFrontOf(b) && !b.inFrontOf(a), isFalse, reason: '${a.id} 가 ${b.id} 보다 먼저 그려짐');
          }
        }
      }
    });
  });
}
