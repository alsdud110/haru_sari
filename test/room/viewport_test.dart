import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneul_sari/ui/room/iso_room_view.dart';

void main() {
  test('RoomFit: 기기별 크기와 스크롤 여부', () {
    final iphone15 = RoomFit.of(393, 3);
    expect(iphone15.scale, 2);
    expect(iphone15.size.width, closeTo(341.33, 0.01));
    expect(iphone15.scrolls, isFalse);

    final s23 = RoomFit.of(360, 3);
    expect(s23.size.width, closeTo(341.33, 0.01));
    expect(s23.scrolls, isFalse);

    final se = RoomFit.of(375, 2); // 1배면 68% → 2배 + 가로 스크롤
    expect(se.scale, 2);
    expect(se.size.width, 512);
    expect(se.scrolls, isTrue);
  });

  test('RoomFit: 위젯 좌표 → 캔버스 좌표', () {
    final f = RoomFit.of(393, 3);
    expect(f.toCanvas(Offset(f.size.width / 2, f.size.height / 2)), const Offset(256, 216));
  });

  Future<void> pumpAt(WidgetTester tester, Size logical, double dpr, Widget child) async {
    tester.view.physicalSize = logical * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('넓은 화면: 가운데 정렬, 스크롤 없음', (tester) async {
    await pumpAt(
      tester,
      const Size(393, 852),
      3,
      RoomViewport(builder: (_, fit) => const ColoredBox(key: Key('room'), color: Colors.brown)),
    );
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.getSize(find.byKey(const Key('room'))).width, closeTo(341.33, 0.01));
  });

  testWidgets('좁은 화면: 가로 스크롤, 처음엔 가운데를 보여줌, 편집 중엔 잠금', (tester) async {
    await pumpAt(
      tester,
      const Size(375, 667),
      2,
      RoomViewport(builder: (_, fit) => const ColoredBox(key: Key('room'), color: Colors.brown)),
    );
    await tester.pump();
    final scroll = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
    expect(scroll.controller!.offset, closeTo((512 - 375) / 2, 0.5));

    await pumpAt(
      tester,
      const Size(375, 667),
      2,
      RoomViewport(lockScroll: true, builder: (_, fit) => const SizedBox()),
    );
    expect(tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView)).physics,
        isA<NeverScrollableScrollPhysics>());
  });

  testWidgets('FullBleed: 좌우 여백 안에서도 화면 폭 전체를 쓴다', (tester) async {
    await pumpAt(
      tester,
      const Size(360, 780),
      3,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Builder(
          builder: (context) => Column(children: [
            FullBleed(
              height: FullBleed.heightFor(context),
              child: const ColoredBox(key: Key('bleed'), color: Colors.brown),
            ),
          ]),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('bleed'))).width, 360);
  });
}
