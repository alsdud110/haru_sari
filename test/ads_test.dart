import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/app.dart';
import 'package:haru_sari/data/ads.dart';
import 'package:haru_sari/data/models.dart';
import 'package:haru_sari/data/rewards.dart';
import 'package:haru_sari/data/store.dart';
import 'package:haru_sari/theme/tokens.dart';
import 'package:haru_sari/ui/ad_coin_button.dart';

/// 정해 둔 결과를 차례로 돌려주는 가짜 광고.
class FakeAds implements RewardAds {
  FakeAds(this.outcomes);
  final List<AdOutcome> outcomes;
  int shown = 0, preloads = 0;
  @override
  bool get available => true;
  @override
  void preload() => preloads++;
  @override
  Future<AdOutcome> show() async => outcomes[shown++];
}

void main() {
  var now = DateTime(2026, 11, 11, 9);
  setUp(() => now = DateTime(2026, 11, 11, 9));

  test('규칙: 하루 3번, 한 번에 5코인', () {
    expect((AdRules.perDay, AdRules.coins), (3, 5));
  });

  test('광고 보상: 횟수는 날마다 다시 차고, 저장했다 다시 열어도 이어진다', () async {
    final kv = MemoryKeyValue();
    final s = AppState(kv, clock: () => now);
    expect((s.adsUsedToday, s.adsLeftToday), (0, 3));
    expect(s.grantAdReward(), isTrue);
    expect((s.adsUsedToday, s.adsLeftToday, s.profile.coins), (1, 2, 5));
    await Future<void>.delayed(Duration.zero); // 기기 저장이 끝나도록

    final again = AppState(kv, clock: () => now);
    expect((again.adsLeftToday, again.profile.coins), (2, 5));
    again
      ..grantAdReward()
      ..grantAdReward();
    expect(again.grantAdReward(), isFalse);
    expect((again.adsLeftToday, again.profile.coins), (0, 15));

    now = now.add(const Duration(days: 1));
    expect(again.adsLeftToday, 3);
    expect(Profile.fromJson(again.profile.toJson()).adCount, 3); // 어제 횟수는 날짜와 함께 남아 있을 뿐이다
  });

  testWidgets('광고 버튼: (3/3)에서 끝까지 볼 때마다 5코인을 받고 줄어들다가, 다 보면 눌리지 않는다', (tester) async {
    final ads = FakeAds([
      AdOutcome.earned,
      AdOutcome.closedEarly, // 중간에 닫으면 코인도 횟수도 그대로
      AdOutcome.unavailable, // 광고를 못 불러와도 그대로
      AdOutcome.earned,
      AdOutcome.earned,
    ]);
    final s = AppState(MemoryKeyValue(), clock: () => now, ads: ads);
    await tester.pumpWidget(
      AppScope(
        state: s,
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(body: Center(child: AdCoinButton())),
        ),
      ),
    );
    expect(ads.preloads, 1); // 버튼이 보이면 광고를 미리 불러 둔다

    Future<void> tap() async {
      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2)); // 알림 글이 사라질 때까지
      await tester.pump(const Duration(seconds: 1));
    }

    expect(find.text('광고 보고 코인 5개 받기 (3/3)'), findsOneWidget);
    await tap();
    expect(find.text('광고 보고 코인 5개 받기 (2/3)'), findsOneWidget);
    expect(s.profile.coins, 5);

    await tap(); // 중간에 닫음
    await tap(); // 광고 없음
    expect(find.text('광고 보고 코인 5개 받기 (2/3)'), findsOneWidget);
    expect(s.profile.coins, 5);

    await tap();
    expect(find.text('광고 보고 코인 5개 받기 (1/3)'), findsOneWidget);
    await tap();
    expect(find.text('오늘 광고는 다 봤어요 (0/3)'), findsOneWidget);
    expect(s.profile.coins, 15);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);
    expect(ads.shown, 5);
  });

  testWidgets('광고를 쓸 수 없는 빌드에서는 버튼이 보이지 않는다', (tester) async {
    final s = AppState(MemoryKeyValue(), clock: () => now);
    await tester.pumpWidget(
      AppScope(
        state: s,
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(body: AdCoinButton()),
        ),
      ),
    );
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
