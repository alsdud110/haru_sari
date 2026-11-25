import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/friend_alarm_sync.dart';
import 'package:haru_sari/data/friends.dart';
import 'package:haru_sari/data/reminders.dart';
import 'package:haru_sari/data/store.dart';

import 'room/manifest_test.dart' show loadManifest;
import 'store_test.dart' show FakeReminders;
import 'sync_test.dart' show FakeServer;

final manifest = loadManifest();

SharedRoutine sr(String id, {int? minute = 420, List<int> days = const [1, 2, 3, 4, 5, 6, 7]}) =>
    SharedRoutine(id: id, name: id, emoji: '🧘', minuteOfDay: minute, weekdays: days, category: '기타');

FriendAlarm fa(String id, {String owner = 'f1', int? minute = 420, List<int> days = const [1, 2, 3, 4, 5, 6, 7]}) =>
    FriendAlarm(owner: owner, nickname: '하루', routine: sr(id, minute: minute, days: days));

void main() {
  group('친구 알림 자리', () {
    test('남은 자리 안에서, 루틴 하나의 요일은 통째로 넣거나 뺀다', () {
      final slots = friendSlots([fa('a'), fa('b', days: [1, 3]), fa('c')], 10);
      // a: 7개 → 들어감(7), b: 2개 → 들어감(9), c: 7개 → 넘쳐서 통째로 빠짐
      expect(slots.map((e) => e.alarm.routine.id).toSet(), {'a', 'b'});
      expect(slots.length, 9);
    });

    test('5개까지만, 시간이 없는 루틴은 빼고', () {
      final alarms = [for (var i = 0; i < 7; i++) fa('r$i', days: [1])]..insert(0, fa('x', minute: null));
      final slots = friendSlots(alarms, 60);
      expect(slots.map((e) => e.alarm.routine.id), ['r0', 'r1', 'r2', 'r3']);
    });

    test('자리가 없으면 하나도 걸지 않는다', () {
      expect(friendSlots([fa('a')], 0), isEmpty);
    });

    test('문구', () {
      expect(friendAlarmBody(fa('아침 스트레칭')), '🌱 하루님의 ‘아침 스트레칭’ 시간이에요. 같이 해볼까요?');
    });
  });

  group('기기 저장과 서버 맞추기', () {
    late MemoryKeyValue kv;
    late FakeReminders reminders;
    late AppState s;

    setUp(() {
      kv = MemoryKeyValue();
      reminders = FakeReminders();
      s = AppState(kv, clock: () => DateTime(2026, 11, 26, 9), reminders: reminders, manifest: manifest);
    });

    test('바꾸면 알림을 다시 걸고, 앱을 다시 켜도 남는다', () async {
      s.setFriendAlarms([fa('a')]);
      await s.syncReminders();
      expect(reminders.lastFriendAlarms.map((e) => e.key), ['f1/a']);

      final again = AppState(kv, clock: () => DateTime(2026, 11, 26, 9), reminders: FakeReminders(), manifest: manifest);
      expect(again.friendAlarms.map((e) => e.key), ['f1/a']);
      expect(again.friendAlarms.single.routine.minuteOfDay, 420);
    });

    test('같은 내용이면 다시 걸지 않는다', () async {
      s.setFriendAlarms([fa('a')]);
      await s.syncReminders();
      final n = reminders.syncs;
      s.setFriendAlarms([fa('a')]);
      await s.syncReminders();
      expect(reminders.syncs, n + 1); // 위의 직접 부른 한 번만
    });

    test('친구가 시간을 바꾸면 따라가고, 공유를 멈추면 빠진다', () async {
      s.setFriendAlarms([fa('a'), fa('b', owner: 'f2')]);
      final server = FakeServer()
        ..following.addAll({'f1'})
        ..others['AAAAAAAA'] = FriendShare(
          owner: 'f1',
          nickname: '하루',
          look: const SharedLook(),
          routines: [sr('a', minute: 480)],
        )
        ..alarmIds['f1'] = {'a'};
      // f2 는 공유를 멈춰 친구 목록에 없다
      await refreshFriendAlarms(s, server);
      expect(s.friendAlarms.map((e) => e.key), ['f1/a']);
      expect(s.friendAlarms.single.routine.minuteOfDay, 480);
    });

    test('켜 둔 친구 알림이 없으면 서버에 묻지 않는다', () async {
      final server = FakeServer()..offline = true; // 물으면 예외
      await refreshFriendAlarms(s, server);
      expect(s.friendAlarms, isEmpty);
    });

    test('친구 목록의 알림: 고른 것 중 시간이 있는 것만', () {
      final f = FriendShare(
        owner: 'f1',
        nickname: '하루',
        look: const SharedLook(),
        routines: [sr('a'), sr('b', minute: null), sr('c')],
        alarmIds: {'a', 'b'},
      );
      expect(f.alarms.map((e) => e.key), ['f1/a']);
      applyFriendAlarms(s, [f]);
      expect(s.friendAlarms.map((e) => e.key), ['f1/a']);
    });
  });
}
