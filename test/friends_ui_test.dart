import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:haru_sari/app.dart';
import 'package:haru_sari/config.dart';
import 'package:haru_sari/data/auth.dart';
import 'package:haru_sari/data/friends.dart';
import 'package:haru_sari/data/kakao_share.dart';
import 'package:haru_sari/data/models.dart';
import 'package:haru_sari/data/reminders.dart';
import 'package:haru_sari/data/store.dart';

import 'room/manifest_test.dart' show loadManifest;
import 'sync_test.dart' show FakeServer;

final manifest = loadManifest();

/// 카카오톡 공유 가짜. [deliver] 로 카드 버튼을 누른 것처럼 코드를 넣는다.
class FakeInvites implements FriendInvites {
  void Function(String code)? _onCode;
  final List<(String, String)> sent = [];

  void deliver(String code) => _onCode?.call(code);

  @override
  Future<bool> kakaoAvailable() async => true;

  @override
  Future<void> shareToKakao({required String name, required String code}) async => sent.add((name, code));

  @override
  void listen(void Function(String code) onCode) => _onCode = onCode;

  /// Play 링크로 설치한 것처럼 흉내 낼 코드
  String? referrer;

  @override
  Future<String?> installReferrerCode() async => referrer;
}

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  DateTime clock() => DateTime(2026, 11, 25, 9);

  /// 미니미가 계속 움직이므로 settle 대신 시간을 흘린다.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<(FakeServer, AppState)> boot(
    WidgetTester tester, {
    FakeInvites? invites,
    MemoryKeyValue? store,
    bool newAccount = false,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final kv = store ?? MemoryKeyValue();
    final auth = DeviceAuthService(kv);
    await auth.signIn(SocialProvider.kakao);
    final pre = AppState(PrefixedKeyValue(kv, userPrefix(auth.current!.uid)), clock: clock, manifest: manifest);
    pre.finishOnboarding(name: '민', minimi: pre.profile.minimi, picked: [Routine(id: 'mine', name: '산책', emoji: '🚶')]);

    final server = FakeServer()
      ..newAccount = newAccount
      ..others['ABCDEFGH'] = const FriendShare(
        owner: 'friend-1',
        nickname: '하루친구',
        look: SharedLook(),
        routines: [
          SharedRoutine(id: 'f1', name: '아침 스트레칭', emoji: '🧘', minuteOfDay: 420, weekdays: [1, 2, 3, 4, 5], category: '건강'),
        ],
      );

    await tester.pumpWidget(
      HaruSariApp(
        kv: kv,
        auth: auth,
        reminders: NoReminders(),
        clock: clock,
        manifest: manifest,
        remoteFor: (_) => server,
        invites: invites,
      ),
    );
    await settle(tester);
    return (server, pre);
  }

  testWidgets('코드로 구경 → 친구 추가 → 친구 루틴을 내 루틴에 담기 → 친구 끊기', (tester) async {
    final (server, _) = await boot(tester);

    await tester.tap(find.text('나'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('친구 루틴'), 200);
    await tester.tap(find.text('친구 루틴'));
    await settle(tester);
    expect(find.text('아직 친구가 없어요'), findsOneWidget);

    // 틀린 형식은 확인이 꺼져 있다
    await tester.tap(find.text('코드로 추가').first);
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'haru-abcd-efg0');
    await tester.pump();
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, '확인')).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'haru-abcd-efgh');
    await tester.pump();
    await tester.tap(find.text('확인'));
    await settle(tester);
    expect(find.text('하루친구님이 루틴을 공유했어요'), findsOneWidget);
    expect(find.text('아침 스트레칭'), findsOneWidget);

    await tester.tap(find.text('친구 추가'));
    await settle(tester);
    expect(server.following, {'friend-1'});
    expect(find.text('하루친구'), findsOneWidget);
    expect(find.text('루틴 1개'), findsOneWidget);

    await tester.tap(find.text('하루친구'));
    await settle(tester);
    await tester.tap(find.text('내 루틴에 추가'));
    await settle(tester);
    expect(find.text('추가함'), findsOneWidget);
    // 체크 표시는 글자(✓)가 아니라 앱 그림(assets/icons/check.png)
    expect(find.image(const AssetImage('assets/icons/check.png')), findsOneWidget);

    await tester.tap(find.byTooltip('더보기'));
    await settle(tester);
    await tester.tap(find.text('친구 끊기').last);
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, '친구 끊기'));
    await settle(tester);
    expect(server.following, isEmpty);
    expect(find.text('아직 친구가 없어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('카톡 카드 버튼으로 앱이 열리면 구경 화면이 뜨고, 친구 추가 뒤 친구 목록으로 간다', (tester) async {
    final invites = FakeInvites();
    final (server, _) = await boot(tester, invites: invites);

    invites.deliver('ABCDEFGH');
    await settle(tester);
    expect(find.text('하루친구님이 루틴을 공유했어요'), findsOneWidget);

    await tester.tap(find.text('친구 추가'));
    await settle(tester);
    expect(server.following, {'friend-1'});
    expect(find.text('친구 1 / $maxFriends명'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('로그인 전에 받은 코드는 기억했다가 홈이 뜨면 연다 (한 번만)', (tester) async {
    final kv = MemoryKeyValue();
    // 앱이 꺼진 상태에서 링크로 켜져 코드만 저장된 상황
    await kv.write('pending_friend_code', 'ABCDEFGH');
    await boot(tester, store: kv);
    expect(find.text('하루친구님이 루틴을 공유했어요'), findsOneWidget);
    expect(kv.read('pending_friend_code'), '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('카카오톡으로 보내기: 공유를 만들고 코드를 카카오로 넘긴다', (tester) async {
    final invites = FakeInvites();
    final (server, _) = await boot(tester, invites: invites);

    await tester.tap(find.text('나'));
    await settle(tester);
    await tester.tap(find.text('루틴 공유'));
    await settle(tester);
    await tester.tap(find.text('카카오톡으로 보내기'));
    await settle(tester);
    expect(server.shareCode, 'MYCQDE23');
    expect(server.sharedRoutines.map((e) => e.id), ['mine']);
    expect(invites.sent, [('민', 'MYCQDE23')]);
    // 공유하는 사람에게 초대 보상 안내 한 줄
    expect(find.text(ShareCopy.inviterReward()), findsOneWidget);
    expect(find.text('HARU-MYCQ-DE23'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('친구 루틴 🔔: 켜고 끄고, 5개를 넘으면 막힌다', (tester) async {
    final (server, _) = await boot(tester);
    server.others['ABCDEFGH'] = FriendShare(
      owner: 'friend-1',
      nickname: '하루친구',
      look: const SharedLook(),
      routines: [
        for (var i = 1; i <= 6; i++)
          SharedRoutine(id: 'f$i', name: '루틴$i', emoji: '🧘', minuteOfDay: 420 + i, weekdays: const [1], category: '기타'),
      ],
    );
    server.following.add('friend-1');

    await tester.tap(find.text('나'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('친구 루틴'), 200);
    await tester.tap(find.text('친구 루틴'));
    await settle(tester);
    await tester.tap(find.text('하루친구'));
    await settle(tester);

    for (var i = 1; i <= 5; i++) {
      await tester.scrollUntilVisible(find.byTooltip('루틴$i 알림 받기'), 100);
      await tester.tap(find.byTooltip('루틴$i 알림 받기'));
      await settle(tester);
    }
    expect(server.alarmIds['friend-1'], {'f1', 'f2', 'f3', 'f4', 'f5'});
    // 켜진 알림은 흔들리는 종 그림, 꺼진 것은 그냥 종 (Material 아이콘이 아니라 앱 그림)
    expect(find.image(const AssetImage('assets/icons/bell_ring.png')), findsWidgets);
    expect(find.byIcon(Icons.notifications_active_rounded), findsNothing);

    await tester.scrollUntilVisible(find.byTooltip('루틴6 알림 받기'), 100);
    await tester.tap(find.byTooltip('루틴6 알림 받기'));
    await tester.pump();
    expect(find.text('친구 루틴 알림은 $maxFriendAlarms개까지 켤 수 있어요'), findsOneWidget);
    await settle(tester);
    expect(server.alarmIds['friend-1']!.contains('f6'), isFalse);

    // 하나 끄면 자리가 난다
    await tester.scrollUntilVisible(find.byTooltip('루틴1 알림 끄기'), -100);
    await tester.tap(find.byTooltip('루틴1 알림 끄기'));
    await settle(tester);
    expect(server.alarmIds['friend-1']!.contains('f1'), isFalse);
    expect(tester.takeException(), isNull);
  });

  group('초대 보상 (3단계)', () {
    testWidgets('새 계정: 홈이 뜨면 코드를 묻고, 넣으면 30코인 → 구경', (tester) async {
      final (server, _) = await boot(tester, newAccount: true);
      expect(find.text('친구에게 초대받았나요?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ZZZZZZZZ');
      await tester.pump();
      await tester.tap(find.text('${InviteRules.newFriendCoins}코인 받기'));
      await settle(tester);
      expect(find.text('코드가 맞지 않거나 공유가 끝났어요'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'haru-abcd-efgh');
      await tester.pump();
      await tester.tap(find.text('${InviteRules.newFriendCoins}코인 받기'));
      await settle(tester);
      expect(server.inviteClaimed, isTrue);
      expect(find.text('친구 링크로 와서 ${InviteRules.newFriendCoins}코인 받았어요!'), findsOneWidget);

      await tester.tap(find.text('친구 루틴 구경하기'));
      await settle(tester);
      expect(find.text('하루친구님이 루틴을 공유했어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Play 링크로 설치했으면 코드가 미리 채워져 있다', (tester) async {
      final invites = FakeInvites()..referrer = 'ABCDEFGH';
      await boot(tester, newAccount: true, invites: invites);
      expect(find.text('HARU-ABCD-EFGH'), findsOneWidget);
      await tester.tap(find.text('건너뛰기'));
      await settle(tester);
      expect(find.text('친구에게 초대받았나요?'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('건너뛰면 다시 묻지 않는다 (계정마다 한 번)', (tester) async {
      final kv = MemoryKeyValue();
      await boot(tester, newAccount: true, store: kv);
      await tester.tap(find.text('건너뛰기'));
      await settle(tester);
      // 앱을 다시 켠다
      await tester.pumpWidget(const SizedBox());
      await boot(tester, newAccount: true, store: kv);
      expect(find.text('친구에게 초대받았나요?'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('카톡 카드로 받은 새 계정: 묻지 않고 바로 보상 → 축하 창', (tester) async {
      final kv = MemoryKeyValue();
      await kv.write('pending_friend_code', 'ABCDEFGH');
      final (server, _) = await boot(tester, newAccount: true, store: kv);
      expect(find.text('친구에게 초대받았나요?'), findsNothing);
      expect(server.inviteClaimed, isTrue);
      expect(find.text('친구 링크로 와서 ${InviteRules.newFriendCoins}코인 받았어요!'), findsOneWidget);
      await tester.tap(find.text('그냥 시작하기'));
      await settle(tester);
      expect(find.text('하루친구님이 루틴을 공유했어요'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('오래된 계정은 묻지 않는다', (tester) async {
      await boot(tester);
      expect(find.text('친구에게 초대받았나요?'), findsNothing);
    });
  });

  testWidgets('없는 코드와 내 코드', (tester) async {
    final (server, _) = await boot(tester);
    server.shareCode = 'MYCQDE23';

    await tester.tap(find.text('나'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('친구 루틴'), 200);
    await tester.tap(find.text('친구 루틴'));
    await settle(tester);

    await tester.tap(find.text('코드로 추가').first);
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'ZZZZZZZZ');
    await tester.pump();
    await tester.tap(find.text('확인'));
    await settle(tester);
    expect(find.text('공유가 끝났거나 코드가 맞지 않아요'), findsOneWidget);
    // 안내는 화면 가로 가운데에 (왼쪽 위에 붙지 않게)
    final screenW = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(tester.getCenter(find.text('공유가 끝났거나 코드가 맞지 않아요')).dx, closeTo(screenW / 2, 1));

    // 다른 코드 넣기 → 같은 화면에서 맞는 코드로 다시 불러온다
    await tester.tap(find.text('다른 코드 넣기'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'ABCDEFGH');
    await tester.pump();
    await tester.tap(find.text('확인'));
    await settle(tester);
    expect(find.text('하루친구님이 루틴을 공유했어요'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await settle(tester);

    await tester.tap(find.text('코드로 추가').first);
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'HARU-MYCQ-DE23');
    await tester.pump();
    await tester.tap(find.text('확인'));
    await settle(tester);
    expect(find.text('내가 공유한 루틴이에요'), findsOneWidget);
    expect(find.text('친구 추가'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
