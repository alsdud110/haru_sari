import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneul_sari/ui/motion.dart';

Widget _host(Widget Function(BuildContext) body) => MaterialApp(
  home: Scaffold(
    body: Builder(builder: (c) => Center(child: body(c))),
  ),
);

void main() {
  testWidgets('스낵바: 아래에서 올라왔다가 시간이 지나면 내려가 사라진다', (t) async {
    await t.pumpWidget(_host((c) => TextButton(onPressed: () => showAppSnack(c, '안녕'), child: const Text('go'))));
    await t.tap(find.text('go'));
    await t.pump();
    final slide = t.widget<SlideTransition>(
      find.ancestor(of: find.text('안녕'), matching: find.byType(SlideTransition)).first,
    );
    expect(slide.position.value.dy, greaterThan(0)); // 아래에서 시작
    await t.pump(AppMotion.snackDuration);
    expect(slide.position.value, Offset.zero);
    await t.pump(const Duration(seconds: 4)); // 표시 시간이 지나 내려가기 시작
    await t.pumpAndSettle();
    expect(find.text('안녕'), findsNothing);
  });

  testWidgets('스낵바: 들어올 땐 ease-out, 나갈 땐 ease-in', (t) async {
    await t.pumpWidget(_host((c) => TextButton(onPressed: () => showAppSnack(c, '곡선'), child: const Text('go'))));
    await t.tap(find.text('go'));
    await t.pump();
    final slide = t.widget<SlideTransition>(
      find.ancestor(of: find.text('곡선'), matching: find.byType(SlideTransition)).first,
    );
    final curved = (slide.position as dynamic).parent as CurvedAnimation;
    expect(curved.curve, AppMotion.snackIn);
    expect(curved.reverseCurve, AppMotion.snackOut);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('토스트: 제자리에서 페이드만 한다', (t) async {
    await t.pumpWidget(_host((c) => TextButton(onPressed: () => showAppToast(c, '저장했어요'), child: const Text('go'))));
    await t.tap(find.text('go'));
    await t.pump();
    expect(find.ancestor(of: find.text('저장했어요'), matching: find.byType(SlideTransition)), findsNothing);
    expect(find.ancestor(of: find.text('저장했어요'), matching: find.byType(FadeTransition)), findsWidgets);
    await t.pump(const Duration(seconds: 3));
    expect(find.text('저장했어요'), findsNothing);
  });

  testWidgets('팝업: 작게 시작해서 커지며 나온다', (t) async {
    await t.pumpWidget(
      _host(
        (c) => TextButton(
          onPressed: () => showAppDialog<void>(c, builder: (_) => const AlertDialog(title: Text('팝업'))),
          child: const Text('go'),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 40));
    final scale = t.widget<ScaleTransition>(
      find.ancestor(of: find.text('팝업'), matching: find.byType(ScaleTransition)).first,
    );
    expect(scale.scale.value, lessThan(1.0));
    expect(scale.scale.value, greaterThanOrEqualTo(AppMotion.popupFrom));
    await t.pumpAndSettle();
    expect(scale.scale.value, 1.0);
  });

  testWidgets('좋아요(체크): 켜지면 1을 넘었다가 돌아오는 스프링', (t) async {
    var on = false;
    late StateSetter set;
    await t.pumpWidget(
      _host(
        (c) => StatefulBuilder(
          builder: (c, s) {
            set = s;
            return SpringPop(active: on, child: const SizedBox(width: 20, height: 20));
          },
        ),
      ),
    );
    set(() => on = true);
    var peak = 0.0;
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 16));
      final tr = t.widget<Transform>(find.descendant(of: find.byType(SpringPop), matching: find.byType(Transform)));
      peak = peak > tr.transform.getMaxScaleOnAxis() ? peak : tr.transform.getMaxScaleOnAxis();
    }
    expect(peak, greaterThan(1.0)); // 톡 튀었다
    await t.pumpAndSettle();
    final tr = t.widget<Transform>(find.descendant(of: find.byType(SpringPop), matching: find.byType(Transform)));
    expect(tr.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.01));
  });

  testWidgets('로딩: 같은 시간마다 같은 각도만큼 돈다 (linear)', (t) async {
    await t.pumpWidget(_host((_) => const AppSpinner()));
    final rot = t.widget<RotationTransition>(
      find.descendant(of: find.byType(AppSpinner), matching: find.byType(RotationTransition)),
    );
    final a = rot.turns.value;
    await t.pump(AppMotion.spinPeriod ~/ 4);
    final b = rot.turns.value;
    await t.pump(AppMotion.spinPeriod ~/ 4);
    final c = rot.turns.value;
    expect(b - a, closeTo(0.25, 0.01));
    expect(c - b, closeTo(0.25, 0.01));
  });

  testWidgets('제목·순서: 한 줄씩 차례로 나타난다', (t) async {
    await t.pumpWidget(
      _host(
        (_) => Column(mainAxisSize: MainAxisSize.min, children: Reveal.lines([const Text('첫째'), const Text('둘째')])),
      ),
    );
    double op(String s) => t
        .widget<FadeTransition>(find.ancestor(of: find.text(s), matching: find.byType(FadeTransition)).first)
        .opacity
        .value;
    await t.pump(); // 첫 줄 애니메이션 시작 프레임
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(op('첫째'), greaterThan(0));
    expect(op('둘째'), 0); // 아직 차례가 아님 (70ms 뒤 시작)
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(op('둘째'), greaterThan(0));
    await t.pumpAndSettle();
    expect(op('첫째'), 1);
    expect(op('둘째'), 1);
  });
}
