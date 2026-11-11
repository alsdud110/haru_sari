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
    await tester.pumpWidget(HaruSariApp(kv: kv, auth: auth, reminders: NoReminders(), clock: clock, manifest: manifest));
    await tester.pumpAndSettle();
  }

  /// 방 화면의 미니미는 계속 숨 쉬므로 settle 대신 시간을 흘린다.
  Future<void> settleish(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('소개 → 가입 → 첫 설정 → 체크해서 보상 → 내 방 → 상점', (tester) async {
    final kv = MemoryKeyValue();
    await pump(tester, kv, AuthService(kv));

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '민');
    await tester.enterText(fields.at(1), 'min@test.com');
    await tester.enterText(fields.at(2), '12345678');
    await tester.enterText(fields.at(3), '12345678');
    await tester.tap(find.text('가입하고 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('민님을 닮은\n미니미를 만들어요'), findsOneWidget);
    await tester.tap(find.text('이 모습이 좋아요'));
    await tester.pumpAndSettle();
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
    await tester.tap(find.text('동그란 러그'));
    await settleish(tester);
    // 30코인 + 레벨업 보너스 없음(15 코인) → 20코인 러그 못 삼
    expect(find.text('코인이 조금 모자라요'), findsOneWidget);
  });

  testWidgets('로그아웃했다가 다시 로그인하면 기록이 이어진다', (tester) async {
    final kv = MemoryKeyValue();
    final auth = AuthService(kv);
    auth.signUp(email: 'a@b.com', password: '12345678', nickname: '하루');
    final s = AppState(PrefixedKeyValue(kv, userPrefix(auth.current!.uid)), clock: clock, manifest: manifest);
    s.finishOnboarding(minimi: s.profile.minimi, picked: []);

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
    expect(find.text('이미 계정이 있어요'), findsOneWidget);

    await tester.tap(find.text('이미 계정이 있어요'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
    await tester.enterText(find.byType(TextField).at(1), '12345678');
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.text('하루의 오늘'), findsOneWidget);
  });

  testWidgets('기록 탭: 일간·주간·월간이 그려진다', (tester) async {
    final kv = MemoryKeyValue();
    final auth = AuthService(kv)..signUp(email: 'a@b.com', password: '12345678', nickname: '민');
    final s = AppState(PrefixedKeyValue(kv, userPrefix(auth.current!.uid)), clock: clock, manifest: manifest);
    s.finishOnboarding(minimi: s.profile.minimi, picked: []);
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
  });
}
