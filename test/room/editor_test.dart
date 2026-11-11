import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/app.dart';
import 'package:haru_sari/data/catalog.dart';
import 'package:haru_sari/data/store.dart';
import 'package:haru_sari/room/iso.dart';
import 'package:haru_sari/room/layout.dart';
import 'package:haru_sari/room/scene.dart';
import 'package:haru_sari/ui/room/room_editor_screen.dart';

import 'manifest_test.dart' show loadManifest;

void main() {
  final m = loadManifest();

  AppState makeState() {
    final s = AppState(MemoryKeyValue(), clock: () => DateTime(2026, 11, 11, 9), manifest: m);
    s.profile
      ..level = 6
      ..coins = 1000;
    s.buy(itemById('bed_single')!);
    s.buy(itemById('chair_wood')!);
    expect(s.moveFloor('bed_single', const FloorPos(1, 1)).ok, isTrue);
    expect(s.moveFloor('chair_wood', const FloorPos(5, 5)).ok, isTrue);
    return s;
  }

  Future<AppState> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final s = makeState();
    await tester.pumpWidget(AppScope(state: s, child: const MaterialApp(home: RoomEditorScreen())));
    await tester.pump();
    return s;
  }

  /// 캔버스(512×432) 좌표 → 화면 좌표
  Offset screen(WidgetTester tester, Offset canvasPt) {
    final f = find.byKey(const Key('room-editor-canvas'));
    final tl = tester.getTopLeft(f);
    final size = tester.getSize(f);
    return tl + canvasPt * (size.width / IsoGrid.canvasW);
  }

  Offset itemPoint(AppState s, String id) {
    final e = RoomScene.build(s.room, m).entries.firstWhere((e) => e.id == id);
    // 상자 아래쪽 1/3 지점 (가구 몸통)
    return Offset(e.box.rect.center.dx, e.box.top + e.box.height * 0.7);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('탭하면 선택, 빈 곳을 탭하면 해제', (tester) async {
    final s = await open(tester);
    await tester.tapAt(screen(tester, itemPoint(s, 'bed_single')));
    await settle(tester);
    expect(find.text('포근한 침대'), findsOneWidget);
    expect(find.byTooltip('회전'), findsOneWidget);
    await tester.tapAt(screen(tester, IsoGrid.tileCenter(6, 1)));
    await settle(tester);
    expect(find.byTooltip('회전'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('끌어서 옮기면 칸에 맞춰 놓이고 저장된다', (tester) async {
    final s = await open(tester);
    final from = itemPoint(s, 'bed_single');
    // 침대 기준 꼭짓점을 (1,1) → (3,4)로: 캔버스 이동량
    final delta = IsoGrid.toCanvas(3, 4) - IsoGrid.toCanvas(1, 1);
    await tester.dragFrom(screen(tester, from), delta * (tester.getSize(find.byKey(const Key('room-editor-canvas'))).width / 512));
    await settle(tester);
    expect(s.room.floor['bed_single'], const FloorPos(3, 4));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('다른 가구 위에 놓으면 그대로이고 안내가 뜬다', (tester) async {
    final s = await open(tester);
    final from = itemPoint(s, 'chair_wood');
    final delta = IsoGrid.toCanvas(1, 2) - IsoGrid.toCanvas(5, 5); // 침대(1,1)~(1,2) 위
    await tester.dragFrom(screen(tester, from), delta * (tester.getSize(find.byKey(const Key('room-editor-canvas'))).width / 512));
    await settle(tester);
    expect(s.room.floor['chair_wood'], const FloorPos(5, 5));
    expect(find.text('여기엔 놓을 수 없어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('작은 화면: 고르기 전엔 드래그가 스크롤, 고른 뒤엔 가구 이동', (tester) async {
    tester.view.physicalSize = const Size(375 * 2, 667 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final s = makeState();
    await tester.pumpWidget(AppScope(state: s, child: const MaterialApp(home: RoomEditorScreen())));
    await tester.pump();
    await tester.pump();
    final scroll = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
    final before = scroll.controller!.offset;
    await tester.dragFrom(screen(tester, IsoGrid.tileCenter(4, 2)), const Offset(-60, 0));
    await settle(tester);
    expect(scroll.controller!.offset, greaterThan(before));
    expect(s.room.floor['bed_single'], const FloorPos(1, 1));

    // 침대를 고르면 스크롤이 잠기고, 끌면 침대가 움직인다
    await tester.tapAt(screen(tester, itemPoint(s, 'bed_single')));
    await settle(tester);
    final delta = IsoGrid.toCanvas(2, 4) - IsoGrid.toCanvas(1, 1);
    await tester.dragFrom(
      screen(tester, itemPoint(s, 'bed_single')),
      delta * (tester.getSize(find.byKey(const Key('room-editor-canvas'))).width / 512),
    );
    await settle(tester);
    expect(s.room.floor['bed_single'], const FloorPos(2, 4));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('회전·보관함에 넣기·보관함에서 다시 놓기', (tester) async {
    final s = await open(tester);
    await tester.tapAt(screen(tester, itemPoint(s, 'bed_single')));
    await settle(tester);
    await tester.tap(find.byTooltip('회전'));
    await settle(tester);
    expect(s.room.floor['bed_single']!.r, Rot.r1);

    await tester.tap(find.byTooltip('보관함으로'));
    await settle(tester);
    expect(s.room.floor.containsKey('bed_single'), isFalse);
    expect(s.storedItems.map((e) => e.id), contains('bed_single'));

    await tester.tap(find.bySemanticsLabel('포근한 침대 방에 놓기'));
    await settle(tester);
    expect(s.room.floor['bed_single'], isNotNull);
    expect(s.room.floor['bed_single']!.r, Rot.r1, reason: '마지막 위치·방향으로 돌아온다');
    await tester.pump(const Duration(seconds: 3));
  });
}
