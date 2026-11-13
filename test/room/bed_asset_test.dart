import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/catalog.dart';
import 'package:haru_sari/data/models.dart';
import 'package:haru_sari/data/store.dart';
import 'package:haru_sari/room/asset_check.dart';
import 'package:haru_sari/room/generated_sprites.dart';
import 'package:haru_sari/room/iso.dart';
import 'package:haru_sari/room/layout.dart';
import 'package:haru_sari/room/registry.dart';
import 'package:haru_sari/room/scene.dart';
import 'package:haru_sari/ui/room/iso_room_painter.dart';
import 'package:haru_sari/ui/room/minimi_sprite.dart';

import 'manifest_test.dart' show loadManifest;
import 'scene_test.dart' show FakeBundle;

/// 침대 두 종: 싱글(1×2, PNG 제작 예정) / 더블(2×2, 사용자 그림을 재분류한 draft)
/// 검수 스크린샷: `flutter test test/room/bed_asset_test.dart --dart-define=WRITE_REVIEW=true`
const writeReview = bool.fromEnvironment('WRITE_REVIEW');

void main() {
  final m = loadManifest();
  const doublePath = 'assets/pixel/furniture/beds/bed_double_r1.png';
  final doubleFile = File(doublePath);

  group('규격', () {
    test('싱글: 1×2, 96×104, R0 앵커 (64,56), R1 앵커 (32,56)', () {
      final a = m['bed_single']!;
      expect(a.footprint, (1, 2));
      expect(a.spriteSpec(Rot.r0), (width: 96, height: 104, ax: 64, ay: 56));
      expect(a.spriteSpec(Rot.r1), (width: 96, height: 104, ax: 32, ay: 56));
    });

    test('더블: 2×2, 높이 56 → 128×120, 앵커 (64,56) (R0·R1 같음)', () {
      final a = m['bed_double']!;
      expect(a.footprint, (2, 2));
      expect(a.height, 56);
      expect(a.spriteSpec(Rot.r0), (width: 128, height: 120, ax: 64, ay: 56));
      expect(a.spriteSpec(Rot.r1), (width: 128, height: 120, ax: 64, ay: 56));
      expect(a.rotations.keys, containsAll([Rot.r0, Rot.r1]));
      expect(a.mirrorR1, isFalse, reason: '광원 때문에 반전 금지, R0·R1 따로 그림');
    });

    test('카탈로그: 더블 100코인·레벨 9, 싱글은 그대로 60코인·레벨 1', () {
      final d = itemById('bed_double')!;
      expect((d.price, d.level, d.slot), (100, 9, RoomSlot.bed));
      final s = itemById('bed_single')!;
      expect((s.price, s.level), (60, 1));
    });
  });

  group('파일', () {
    test('원본은 이름만 바꿔 보존, 싱글은 코드로 그린 픽셀 그림이 네 방향 모두 있다', () {
      expect(File('art/source/furniture/beds/bed_double_r1_original.png').existsSync(), isTrue);
      expect(doubleFile.existsSync(), isTrue);
      expect(generatedSprites, contains('bed_single'));
      expect(generatedSprites, isNot(contains('bed_double')), reason: '사람이 그린 그림은 덮어쓰지 않는다');
      for (final r in Rot.values) {
        final p = m['bed_single']!.rotations[r];
        expect(p, isNotNull, reason: r.name);
        expect(File('assets/pixel/$p').existsSync(), isTrue, reason: r.name);
      }
    });

    testWidgets('더블 R1 보정본: 크기·알파·팔레트·허용 영역 모두 통과 (늘리지 않고 옮겨 놓음)', (tester) async {
      await tester.runAsync(() async {
        final problems = await AssetCheck.objectSprite(m['bed_double']!, Rot.r1, doubleFile.readAsBytesSync());
        expect(problems, isEmpty);
        // R0은 R1을 좌우로 뒤집은 임시본 (명암은 손보지 않음)
        final r0 = File('assets/pixel/furniture/beds/bed_double_r0.png').readAsBytesSync();
        expect(await AssetCheck.objectSprite(m['bed_double']!, Rot.r0, r0), isEmpty);
      });
    });
  });

  group('데이터 호환', () {
    test('싱글 침대를 산 기존 사용자: ID·구매일·배치 그대로, 더블은 따로 산다', () async {
      final kv = MemoryKeyValue();
      final old = Profile(
        level: 9,
        coins: 120,
        owned: {'bed_single'},
        acquired: {'bed_single': '2026-11-01'},
        placed: {'bed': 'bed_single'},
      );
      await kv.write('profile', jsonEncode(old.toJson()..remove('room')));
      final s = AppState(kv, clock: () => DateTime(2026, 11, 11, 9), manifest: m);
      expect(s.profile.owned, {'bed_single'});
      expect(s.profile.acquired['bed_single'], '2026-11-01');
      expect(s.room.floor['bed_single'], const FloorPos(0, 1));

      expect(s.buy(itemById('bed_double')!), BuyResult.ok);
      expect(s.profile.coins, 20);
      expect(s.room.floor.keys, containsAll(['bed_single', 'bed_double']));
      expect(s.isInUse(itemById('bed_single')!), isTrue);
      // 둘이 겹치지 않는다
      for (final e in s.room.floor.entries) {
        expect(s.occupancy.canPlaceFloor(s.room, e.key, e.value).ok, isTrue, reason: e.key);
      }
    });

    test('더블 2×2 회전: 점유는 그대로 2×2, 방 끝에서도 회전 가능', () {
      final s = AppState(MemoryKeyValue(), clock: () => DateTime(2026, 11, 11, 9), manifest: m);
      s.profile
        ..level = 9
        ..coins = 200;
      s.buy(itemById('bed_double')!);
      expect(s.moveFloor('bed_double', const FloorPos(6, 6)).ok, isTrue);
      expect(s.rotateFloor('bed_double').ok, isTrue);
      expect(s.room.floor['bed_double'], const FloorPos(6, 6, Rot.r1));
      expect(s.moveFloor('bed_double', const FloorPos(7, 6, Rot.r1)).status.name, 'outOfRoom');
    });
  });

  Future<AssetRegistry> devRegistry() async {
    final reg = AssetRegistry(m, bundle: FakeBundle({doublePath: doubleFile.readAsBytesSync()}));
    await reg.preload(['bed_double', 'bed_single']);
    return reg;
  }

  testWidgets('더블 R1은 PNG, R0과 싱글은 그림이 없어 기존 그림', (tester) async {
    await tester.runAsync(() async {
      final reg = await devRegistry();
      final r1 = reg.sprite('bed_double', Rot.r1);
      expect(r1, isNotNull);
      expect((r1!.image.width, r1.image.height), (128, 120));
      expect(r1.opaqueAt(64, 80), isTrue);
      expect(r1.opaqueAt(2, 2), isFalse);
      expect(reg.sprite('bed_double', Rot.r0), isNull);
      expect(reg.sprite('bed_single', Rot.r0), isNull);
    });
  });

  test('깊이 정렬: 더블 침대 앞의 의자·미니미는 나중에, 뒤의 화분은 먼저', () {
    final l = RoomLayout(
      floor: {
        'bed_double': const FloorPos(3, 2, Rot.r1),
        'chair_wood': const FloorPos(5, 3),
        'plant_small': const FloorPos(3, 1),
      },
      minimi: (3, 4),
    );
    final ids = RoomScene.build(l, m).entries.map((e) => e.id).toList();
    expect(ids.indexOf('plant_small'), lessThan(ids.indexOf('bed_double')));
    expect(ids.indexOf('chair_wood'), greaterThan(ids.indexOf('bed_double')));
    expect(ids.indexOf(RoomScene.minimiId), greaterThan(ids.indexOf('bed_double')));
  });

  testWidgets('실제 방에 그리기: 더블 R1·R0(대체)·싱글(대체)·편집 표시 예외 없음 (+ 검수 스크린샷)', (tester) async {
    final reg = await tester.runAsync(devRegistry);
    Future<void> shot(String name, RoomLayout l, {String? selected}) async {
      final painter = IsoRoomPainter(
        layout: l,
        scene: RoomScene.build(l, m),
        manifest: m,
        registry: reg,
        drawMinimi: minimiDrawer(Profile(), frame: 0),
        editing: selected != null,
        selected: selected,
      );
      final key = GlobalKey();
      await tester.pumpWidget(Center(
        child: RepaintBoundary(key: key, child: CustomPaint(size: const Size(1024, 864), painter: painter)),
      ));
      expect(tester.takeException(), isNull);
      if (writeReview) {
        await tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject()! as dynamic;
          final ui.Image img = await boundary.toImage(pixelRatio: 1.0);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('docs/asset-system/review/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }
    }

    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final base = {
      'chair_wood': const FloorPos(5, 3),
      'plant_small': const FloorPos(3, 1),
      'rug_round': const FloorPos(1, 5),
      'bed_single': const FloorPos(0, 1),
    };
    await shot(
      'bed_double_in_room_r1',
      RoomLayout(floor: {'bed_double': const FloorPos(3, 2, Rot.r1), ...base}, minimi: (3, 5)),
    );
    await shot(
      'bed_double_in_room_r1_footprint',
      RoomLayout(floor: {'bed_double': const FloorPos(3, 2, Rot.r1), ...base}, minimi: (3, 5)),
      selected: 'bed_double',
    );
    await shot(
      'bed_double_in_room_r0_fallback',
      RoomLayout(floor: {'bed_double': const FloorPos(3, 2), ...base}, minimi: (3, 5)),
    );
    expect(IsoGrid.canvasW, 512);
  });
}
