import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:haru_sari/app.dart';
import 'package:haru_sari/data/auth.dart';
import 'package:haru_sari/data/reminders.dart';
import 'package:haru_sari/data/store.dart';

import 'room/manifest_test.dart' show loadManifest;

final manifest = loadManifest();

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  DateTime clock() => DateTime(2026, 11, 11, 9);

  Future<void> pump(WidgetTester tester, KeyValue kv, AuthService auth) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      HaruSariApp(kv: kv, auth: auth, reminders: NoReminders(), clock: clock, manifest: manifest),
    );
    await tester.pumpAndSettle();
  }

  /// 방 화면의 미니미는 계속 숨 쉬므로 settle 대신 시간을 흘린다.
  Future<void> settleish(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('소개 → 카카오 로그인 → 닉네임 → 첫 설정 → 체크해서 보상 → 내 방 → 상점', (tester) async {
    final kv = MemoryKeyValue();
    await pump(tester, kv, DeviceAuthService(kv));

    // 로그인은 소개 마지막 장에서만 나온다
    expect(find.text('카카오로 시작하기'), findsNothing);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await settleish(tester); // 마지막 장의 미니미가 계속 숨 쉰다
    await tester.tap(find.text('카카오로 시작하기'));
    await settleish(tester);
    expect(find.text('뭐라고 불러드릴까요?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '민');
    await tester.pump();
    await tester.tap(find.text('다음'));
    await settleish(tester); // 미니미가 계속 숨 쉰다

    expect(find.text('민님을 닮은\n미니미를 만들어요'), findsOneWidget);
    await tester.tap(find.text('이 모습이 좋아요'));
    await settleish(tester);
    await tester.tap(find.text('일어나기'));
    await tester.tap(find.text('물 한 잔 마시기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2개로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('민의 오늘'), findsOneWidget);
    await tester.tap(find.text('일어나기'));
    await tester.pumpAndSettle();
    expect(find.text('방 꾸미러 가기'), findsNothing); // 50%, 기준 미달

    await tester.tap(find.text('물 한 잔 마시기'));
    await tester.pumpAndSettle();
    expect(find.text('+30 XP'), findsOneWidget);
    await tester.tap(find.text('방 꾸미러 가기'));
    await settleish(tester);
    expect(find.text('민의 방'), findsOneWidget);
    expect(find.text('미니미 상태'), findsOneWidget);

    await tester.tap(find.text('가구 상점'));
    await settleish(tester);
    expect(find.text('동그란 러그'), findsOneWidget);
    await tester.ensureVisible(find.text('동그란 러그')); // 싼 물건이 늘어 아래로 밀렸다
    await settleish(tester);
    await tester.tap(find.text('동그란 러그'));
    await settleish(tester);
    // 30코인 + 레벨업 보너스 없음(15 코인) → 20코인 러그 못 삼
    expect(find.text('코인이 조금 모자라요'), findsOneWidget);
  }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}));

  testWidgets('로그아웃했다가 다시 로그인하면 기록이 이어진다', (tester) async {
    final kv = MemoryKeyValue();
    final auth = DeviceAuthService(kv);
    await auth.signIn(SocialProvider.kakao);
    final s = AppState(PrefixedKeyValue(kv, userPrefix(auth.current!.uid)), clock: clock, manifest: manifest);
    s.finishOnboarding(name: '하루', minimi: s.profile.minimi, picked: []);

    await pump(tester, kv, auth);
    expect(find.text('하루의 오늘'), findsOneWidget);
    expect(find.text('아직 기록할 루틴이 없어요'), findsOneWidget);

    await tester.tap(find.text('나'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('로그아웃'), 200);
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
    await settleish(tester);
    expect(find.text('카카오로 시작하기'), findsOneWidget);

    // 로그인이 실패하면 안내가 보이고, 다시 누르면 들어간다
    auth.nextError = '로그인에 실패했어요. 잠시 뒤 다시 시도해 주세요';
    await tester.tap(find.text('카카오로 시작하기'));
    await settleish(tester);
    expect(find.text('로그인에 실패했어요. 잠시 뒤 다시 시도해 주세요'), findsOneWidget);
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('하루의 오늘'), findsOneWidget);

    // 개발용 초기화: 계정까지 지우고 소개 화면으로
    await tester.tap(find.text('나'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('초기화 (개발용)'), 200);
    await tester.tap(find.text('초기화 (개발용)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '초기화'));
    await tester.pumpAndSettle();
    expect(find.text('건너뛰기'), findsOneWidget);
    expect(kv.read('${userPrefix('dev-kakao')}routines'), isNull);
  });

  testWidgets('기록 탭: 일간·주간·월간이 그려진다', (tester) async {
    final kv = MemoryKeyValue();
    final auth = DeviceAuthService(kv);
    await auth.signIn(SocialProvider.kakao);
    final s = AppState(PrefixedKeyValue(kv, userPrefix(auth.current!.uid)), clock: clock, manifest: manifest);
    s.finishOnboarding(name: '민', minimi: s.profile.minimi, picked: []);
    await pump(tester, kv, auth);

    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    expect(find.text('기록 없음'), findsWidgets); // 주간 목록
    await tester.tap(find.text('월간'));
    await tester.pumpAndSettle();
    expect(find.text('한 달을 살아낸 나에게'), findsOneWidget);
    expect(find.textContaining('연속'), findsNothing);
    await tester.tap(find.text('일간'));
    await tester.pumpAndSettle();
    expect(find.text('루틴이 없던 날이에요'), findsOneWidget);
  }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}));

  testWidgets('받은 배지는 넘치지 않고, 빈 보관함 안내는 가운데에 온다', (tester) async {
    final kv = MemoryKeyValue();
    final auth = DeviceAuthService(kv);
    await auth.signIn(SocialProvider.kakao);
    final s = AppState(PrefixedKeyValue(kv, userPrefix(auth.current!.uid)), clock: clock, manifest: manifest);
    s.finishOnboarding(name: '민', minimi: s.profile.minimi, picked: []);
    await pump(tester, kv, auth);

    await tester.tap(find.text('나'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('받은 배지'));
    await tester.pumpAndSettle();
    expect(find.text('첫 기록'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 빈 보관함 안내는 화면 가운데에 온다
    await tester.tap(find.byType(BackButton)); // 한국어 설정이라 pageBack()의 영어 'Back' 찾기가 맞지 않는다
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 방'));
    await settleish(tester);
    await tester.tap(find.text('보관함'));
    await settleish(tester);
    expect(tester.getCenter(find.text('보관함이 비어 있어요')).dx, 195);
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}));

  testWidgets('설정의 오픈소스 라이선스: 글꼴 세 개의 저작권과 라이선스 전문을 볼 수 있다', (tester) async {
    final kv = MemoryKeyValue();
    final auth = DeviceAuthService(kv);
    await auth.signIn(SocialProvider.kakao);
    final s = AppState(PrefixedKeyValue(kv, userPrefix(auth.current!.uid)), clock: clock, manifest: manifest);
    s.finishOnboarding(name: '민', minimi: s.profile.minimi, picked: []);
    await pump(tester, kv, auth);

    await tester.tap(find.text('나'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('다시 시작하는 날이 곧 좋은 날이에요'), 200);
    await tester.tap(find.text('오픈소스 라이선스'));
    await tester.pumpAndSettle();
    expect(find.text('LINE Seed Sans KR'), findsOneWidget);
    expect(find.text('MaruBuri (마루 부리)'), findsOneWidget);
    expect(find.text('Bricolage Grotesque'), findsOneWidget);
    expect(find.text('© LY Corporation'), findsOneWidget);

    await tester.tap(find.text('글꼴 라이선스 전문 보기'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.textContaining('SIL OPEN FONT LICENSE Version 1.1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('가로로 눕힌 화면: 소개 세 장이 넘치지 않고, 가려진 글은 세로로 넘겨 본다', (tester) async {
    final kv = MemoryKeyValue();
    await pump(tester, kv, DeviceAuthService(kv));
    tester.view.physicalSize = const Size(780 * 3, 360 * 3);
    await settleish(tester); // 넘치면 여기서 테스트가 실패한다
    expect(find.textContaining('평범한 하루도'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await settleish(tester);
    await tester.tap(find.text('다음'));
    await settleish(tester);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('intro-minimi')), const Offset(0, -200));
    await settleish(tester);
  });

  testWidgets('가로로 눕힌 화면: 키보드가 올라온 닉네임 화면과 보상 시트가 넘치지 않는다', (tester) async {
    final kv = MemoryKeyValue();
    await pump(tester, kv, DeviceAuthService(kv));
    await tester.tap(find.text('건너뛰기'));
    await settleish(tester);
    await tester.tap(find.text('카카오로 시작하기'));
    await settleish(tester);

    // 눕히고 키보드를 올린다 (넘치면 여기서 테스트가 실패한다)
    tester.view.physicalSize = const Size(780 * 3, 360 * 3);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200 * 3);
    addTearDown(tester.view.resetViewInsets);
    await settleish(tester);
    await tester.enterText(find.byType(TextField), '민');
    await tester.pump();
    await tester.ensureVisible(find.text('다음')); // 자리가 모자라 버튼도 함께 넘겨 본다
    await settleish(tester);
    await tester.tap(find.text('다음'));
    tester.view.resetViewInsets();
    await settleish(tester);

    await tester.tap(find.text('이 모습이 좋아요'));
    await settleish(tester);
    await tester.ensureVisible(find.text('일어나기'));
    await settleish(tester);
    await tester.tap(find.text('일어나기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1개로 시작하기'));
    await tester.pumpAndSettle();

    // 세로에서 체크해 보상 시트를 띄운 뒤 눕힌다
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    await tester.pumpAndSettle();
    await tester.tap(find.text('일어나기'));
    await tester.pumpAndSettle();
    expect(find.text('오늘을 온전히 살아냈어요'), findsOneWidget);
    tester.view.physicalSize = const Size(780 * 3, 360 * 3);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
  });

  testWidgets('개발자 모드: 소개 마지막 장의 미니미를 두 번 누르면 로그인 없이 들어간다', (tester) async {
    final kv = MemoryKeyValue();
    final auth = DeviceAuthService(kv);
    await pump(tester, kv, auth);
    await tester.tap(find.text('건너뛰기'));
    await settleish(tester);

    final minimi = find.byKey(const ValueKey('intro-minimi'));
    await tester.tap(minimi);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(minimi);
    await settleish(tester);

    expect(auth.current!.isDeveloper, isTrue);
    expect(find.text('뭐라고 불러드릴까요?'), findsOneWidget);
    // 다시 열어도 개발자 모드가 이어지고, 로그아웃하면 풀린다
    expect(DeviceAuthService(kv).current?.uid, AuthService.devUid);
    await auth.logout();
    expect(auth.signedIn, isFalse);
    expect(DeviceAuthService(kv).signedIn, isFalse);
    await settleish(tester);
  });

  testWidgets('소개 장면: 루틴이 차례로 체크되고, 달성률은 1/3에서 멈추고, 장을 다시 보면 처음부터 재생된다', (tester) async {
    final kv = MemoryKeyValue();
    await pump(tester, kv, DeviceAuthService(kv));

    // 1장: 재생이 끝나면 루틴 세 개 가운데 위의 둘이 체크돼 있다
    expect(find.text('일어나기'), findsOneWidget);
    expect(find.text('점심 챙겨 먹기'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));

    // 2장: 다 채우지 않고 1/3에서 멈춘다
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);

    // 1장으로 돌아가면 처음(체크 없음)부터 다시 재생된다
    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
