import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/catalog.dart';
import 'package:haru_sari/data/models.dart';
import 'package:haru_sari/ui/onboarding.dart';

void main() {
  testWidgets('옷 무늬·하의를 고르면 그것만 바뀌고 머리 모양은 그대로다', (tester) async {
    var m = const Minimi(hairStyle: 11, hair: 2, outfit: 6);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => MinimiPicker(minimi: m, onChanged: (v) => setState(() => m = v), fill: true),
          ),
        ),
      ),
    );
    await tester.tap(find.text('옷').last); // 탭 이름 (Text 안에 Text 가 한 겹 더 있다)
    await tester.pumpAndSettle();
    await tester.tap(find.text('땡땡이 티셔츠')); // 기본 티셔츠는 무늬마다 한 칸
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('플리츠 치마'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('플리츠 치마'));
    await tester.pumpAndSettle();
    expect(m, const Minimi(hairStyle: 11, hair: 2, outfit: 6, pattern: 2, bottom: 3));
  });

  testWidgets('옷 탭: 기본 옷과 산 옷이 한 줄에 있고, 누르면 그 옷을 입는다', (tester) async {
    var m = const Minimi(bottom: 2);
    String? top, bottom;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => MinimiPicker(
              minimi: m,
              onChanged: (v) => setState(() => m = v),
              fill: true,
              clothes: [itemById('outfit_jeans')!, itemById('outfit_dress_floral')!, itemById('outfit_cardigan')!],
              top: top,
              bottom: bottom,
              onDress: (t, b, _) => setState(() {
                top = t;
                bottom = b;
              }),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('옷').last);
    await tester.pumpAndSettle();

    Future<void> tap(String name) async {
      await tester.ensureVisible(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    await tap('진청 청바지');
    expect((top, bottom), (null, 'outfit_jeans'));
    await tap('롱 스커트'); // 기본 하의로 돌아가면 산 하의를 벗는다
    expect((top, bottom, m.bottom), (null, null, 6));
    await tap('진청 청바지');
    await tap('꽃무늬 원피스'); // 원피스는 하의를 벗긴다
    expect((top, bottom), ('outfit_dress_floral', null));
    expect(find.text('원피스·세트를 입는 동안에는 하의가 없어요'), findsOneWidget);

    // 산 상의 → 기본 티셔츠: 색 칸이 바뀌며 칸 수가 달라져도 색 동그라미가 썸네일로 바뀌며 깨지지 않는다
    await tap('버터 가디건');
    expect(find.text('버터 가디건 · 원래 색'), findsOneWidget);
    await tester.ensureVisible(find.text('체크 티셔츠'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('체크 티셔츠'));
    // 애니메이션 중간 프레임에서 깨졌다 (pumpAndSettle 만으로는 잡히지 않음)
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect((top, m.pattern), (null, 3));
    expect(tester.takeException(), isNull);
    expect(find.text('상의 색상'), findsOneWidget);

    // 주사위: 산 옷도 입는다 (칸마다 같은 확률이라 50번이면 산 옷이 나오지 않을 확률은 0에 가깝다)
    final worn = <String?>{};
    for (var n = 0; n < 50; n++) {
      await tester.tap(find.byTooltip('아무렇게나 꾸며 보기'));
      await tester.pump();
      worn.addAll([top, bottom]);
      if (top == 'outfit_dress_floral') expect(bottom, isNull, reason: '원피스면 하의 없음');
    }
    await tester.pumpAndSettle();
    expect(worn, containsAll(['outfit_cardigan', 'outfit_jeans']));
  });
}
