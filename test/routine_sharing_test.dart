import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/models.dart';
import 'package:haru_sari/data/routine_sharing.dart';
import 'package:haru_sari/data/store.dart';

import 'room/manifest_test.dart' show loadManifest;
import 'sync_test.dart' show FakeServer;

final manifest = loadManifest();

/// 디바운스를 0으로 둔 공유가 서버에 다 올릴 때까지 기다린다.
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  late FakeServer server;
  late MemoryKeyValue kv;
  late AppState s;
  late RoutineSharing sh;

  Routine r(String id, {String memo = ''}) => Routine(id: id, name: id, emoji: '✨', minuteOfDay: 480, memo: memo, alarmOn: true);

  setUp(() {
    server = FakeServer();
    kv = MemoryKeyValue();
    s = AppState(kv, clock: () => DateTime(2026, 11, 25, 9), manifest: manifest);
    s.finishOnboarding(name: '하루', minimi: const Minimi(skin: 2), picked: [r('a', memo: '비밀'), r('b'), r('c')]);
    sh = RoutineSharing(s, server, kv, debounce: Duration.zero);
  });

  tearDown(() => sh.dispose());

  test('고른 루틴만, 메모·알림 없이 공유하고 코드를 받는다', () async {
    final code = await sh.share({'a', 'b'});
    expect(code, 'MYCQDE23');
    expect(sh.isOn, isTrue);
    expect(sh.ids, {'a', 'b'});
    expect(server.sharedNickname, '하루');
    expect(server.sharedRoutines.map((e) => e.id), ['a', 'b']);
    expect(server.sharedRoutines.first.toJson().containsKey('memo'), isFalse);
    expect(sh.dirty, isFalse);
  });

  test('공유한 루틴을 고치면 잠시 뒤 서버도 바뀐다', () async {
    await sh.share({'a'});
    s.upsertRoutine(s.routines.firstWhere((e) => e.id == 'a').copy()..name = '물 한 잔');
    await settle();
    expect(server.sharedRoutines.single.name, '물 한 잔');
    expect(sh.dirty, isFalse);
  });

  test('공유하지 않은 루틴을 고치면 올리지 않는다', () async {
    await sh.share({'a'});
    server.calls.clear();
    s.upsertRoutine(s.routines.firstWhere((e) => e.id == 'b').copy()..name = '독서');
    await settle();
    expect(server.calls.where((c) => c.startsWith('share')), isEmpty);
  });

  test('공유한 루틴을 지우면 목록에서 빠지고 서버도 바뀐다', () async {
    await sh.share({'a', 'b'});
    s.deleteRoutine('a');
    await settle();
    expect(sh.ids, {'b'});
    expect(server.sharedRoutines.map((e) => e.id), ['b']);
  });

  test('공유 전에는 루틴을 고쳐도 서버에 올리지 않는다', () async {
    s.upsertRoutine(s.routines.first.copy()..name = 'x');
    await settle();
    expect(server.calls.where((c) => c.startsWith('share')), isEmpty);
  });

  test('오프라인이면 남겨 두었다가 다음에 올린다', () async {
    await sh.share({'a'});
    server.offline = true;
    s.upsertRoutine(s.routines.firstWhere((e) => e.id == 'a').copy()..name = '오프라인');
    await settle();
    expect(sh.dirty, isTrue);
    expect(server.sharedRoutines.single.name, 'a');

    // 앱을 다시 켠 것처럼 같은 기기 저장소로 새로 만들어도 '못 올림'이 남아 있다
    sh.dispose();
    sh = RoutineSharing(s, server, kv, debounce: Duration.zero);
    expect(sh.isOn, isTrue);
    expect(sh.dirty, isTrue);

    server.offline = false;
    await sh.flush();
    expect(server.sharedRoutines.single.name, '오프라인');
    expect(sh.dirty, isFalse);
  });

  test('고른 루틴을 바꾸면 서버에 올린다', () async {
    await sh.share({'a'});
    await sh.setIds({'a', 'c'});
    await settle();
    expect(server.sharedRoutines.map((e) => e.id), ['a', 'c']);
  });

  test('멈추면 코드가 사라지고, 다시 켜도 기기에 남지 않는다', () async {
    await sh.share({'a'});
    await sh.stop();
    expect(sh.isOn, isFalse);
    expect(server.shareCode, isNull);
    sh.dispose();
    sh = RoutineSharing(s, server, kv, debounce: Duration.zero);
    expect(sh.isOn, isFalse);
    expect(sh.ids, isEmpty);
  });

  test('다른 기기에서 멈췄으면 새로고침할 때 꺼진다', () async {
    await sh.share({'a'});
    server.shareCode = null;
    await sh.refresh();
    expect(sh.isOn, isFalse);
  });

  test('30개를 넘게 고르면 30개만 공유한다', () async {
    for (var i = 0; i < 35; i++) {
      s.upsertRoutine(r('x$i'));
    }
    await sh.share({for (final e in s.routines) e.id});
    expect(server.sharedRoutines.length, RoutineSharing.maxRoutines);
  });
}
