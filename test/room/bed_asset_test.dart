import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneul_sari/data/models.dart';
import 'package:oneul_sari/room/asset_check.dart';
import 'package:oneul_sari/room/iso.dart';
import 'package:oneul_sari/room/layout.dart';
import 'package:oneul_sari/room/registry.dart';
import 'package:oneul_sari/room/scene.dart';
import 'package:oneul_sari/ui/room/iso_room_painter.dart';
import 'package:oneul_sari/ui/room/minimi_sprite.dart';

import 'manifest_test.dart' show loadManifest;
import 'scene_test.dart' show FakeBundle;

/// 사용자가 만든 침대(보정본, draft)를 실제 방에 넣어 본다.
/// 검수용 스크린샷: `flutter test test/room/bed_asset_test.dart --dart-define=WRITE_REVIEW=true`
const writeReview = bool.fromEnvironment('WRITE_REVIEW');

void main() {
  final m = loadManifest();
  const path = 'assets/pixel/furniture/beds/bed_single_r0.png';
  final file = File(path);

  test('침대 보정본은 draft이고, 원본은 별도로 보존돼 있다', () {
    expect(file.existsSync(), isTrue);
    expect(m['bed_single']!.isFinal, isFalse, reason: '검수 전에는 final로 표시하지 않는다');
    expect(File('art/source/furniture/beds/bed_single_r0_original.png').existsSync(), isTrue);
  });

  testWidgets('검증기: 크기·알파·팔레트는 통과, 허용 영역은 아직 어긋남(재작업 필요)', (tester) async {
    await tester.runAsync(() async {
      final problems = await AssetCheck.objectSprite(m['bed_single']!, Rot.r0, file.readAsBytesSync());
      expect(problems.where((p) => p.contains('크기') || p.contains('반투명') || p.contains('팔레트')), isEmpty);
      // 현재 그림은 정사각형에 가까운 더블 침대라 1×2 점유 기둥 밖으로 53px이 나간다 (review 문서 참고)
      expect(problems.single, contains('허용 영역 밖'));
    });
  });

  Future<AssetRegistry> devRegistry() async {
    final reg = AssetRegistry(m, bundle: FakeBundle({path: file.readAsBytesSync()}), showDraft: true);
    await reg.preload(['bed_single']);
    return reg;
  }

  testWidgets('개발 모드: R0은 PNG로, R1은 그림이 없어 기존 그림으로 대체', (tester) async {
    await tester.runAsync(() async {
      final reg = await devRegistry();
      final r0 = reg.sprite('bed_single', Rot.r0);
      expect(r0, isNotNull);
      expect((r0!.image.width, r0.image.height), (96, 104));
      expect(reg.sprite('bed_single', Rot.r1), isNull, reason: 'R1 PNG 없음, 침대는 반전 금지(명암)');
      // 알파 마스크로 터치 판정: 이불 가운데는 불투명, 왼쪽 위 구석은 투명
      expect(r0.opaqueAt(60, 70), isTrue);
      expect(r0.opaqueAt(2, 2), isFalse);
    });
  });

  testWidgets('출시 모드: draft 침대는 쓰지 않는다', (tester) async {
    await tester.runAsync(() async {
      final reg = AssetRegistry(m, bundle: FakeBundle({path: file.readAsBytesSync()}), showDraft: false);
      await reg.preload(['bed_single']);
      expect(reg.sprite('bed_single', Rot.r0), isNull);
    });
  });

  test('깊이 정렬: 침대 앞 칸의 의자·미니미는 침대보다 나중에, 뒤의 화분은 먼저', () {
    final l = RoomLayout(
      floor: {
        'bed_single': const FloorPos(3, 2),
        'chair_wood': const FloorPos(4, 3), // 침대 오른쪽 옆 (x가 큼 → 앞)
        'plant_small': const FloorPos(3, 1), // 침대 뒤
      },
      minimi: (3, 4), // 침대 발치 앞
    );
    final ids = RoomScene.build(l, m).entries.map((e) => e.id).toList();
    expect(ids.indexOf('plant_small'), lessThan(ids.indexOf('bed_single')));
    expect(ids.indexOf('chair_wood'), greaterThan(ids.indexOf('bed_single')));
    expect(ids.indexOf(RoomScene.minimiId), greaterThan(ids.indexOf('bed_single')));
  });

  testWidgets('실제 방에 그리기: R0·R1·편집 표시 모두 예외 없음 (+ 검수 스크린샷)', (tester) async {
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
      'chair_wood': const FloorPos(4, 3),
      'plant_small': const FloorPos(3, 1),
      'rug_round': const FloorPos(2, 4),
    };
    await shot('bed_in_room_r0', RoomLayout(floor: {'bed_single': const FloorPos(3, 2), ...base}, minimi: (3, 4)));
    await shot(
      'bed_in_room_r0_footprint',
      RoomLayout(floor: {'bed_single': const FloorPos(3, 2), ...base}, minimi: (3, 4)),
      selected: 'bed_single',
    );
    await shot(
      'bed_in_room_r1_fallback',
      RoomLayout(floor: {'bed_single': const FloorPos(2, 2, Rot.r1), ...base}, minimi: (3, 4)),
    );
    expect(IsoGrid.canvasW, 512);
  });
}
