import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/auth.dart';
import 'package:haru_sari/data/catalog.dart';
import 'package:haru_sari/data/models.dart';
import 'package:haru_sari/data/reminders.dart';
import 'package:haru_sari/data/rewards.dart';
import 'package:haru_sari/data/store.dart';
import 'package:haru_sari/room/iso.dart';
import 'package:haru_sari/room/layout.dart';
import 'package:haru_sari/room/manifest.dart';
import 'package:haru_sari/room/occupancy.dart';

import 'room/manifest_test.dart' show loadManifest;

final manifest = loadManifest();

class FakeReminders implements Reminders {
  int syncs = 0;
  List<Routine> lastRoutines = [];
  AlarmSettings? lastSettings;
  @override
  Future<void> sync({required List<Routine> routines, required AlarmSettings settings}) async {
    syncs++;
    lastRoutines = routines;
    lastSettings = settings;
  }

  @override
  Future<void> clear() async {}
  @override
  Future<bool> requestPermission() async => true;
}

void main() {
  // 2026-11-11 은 수요일
  var now = DateTime(2026, 11, 11, 9);
  late MemoryKeyValue kv;
  late AppState s;
  late FakeReminders rem;

  Routine r(String id, {Set<int>? days, String memo = ''}) =>
      Routine(id: id, name: id, emoji: '✨', weekdays: days, memo: memo);

  setUp(() {
    now = DateTime(2026, 11, 11, 9);
    kv = MemoryKeyValue();
    rem = FakeReminders();
    s = AppState(kv, clock: () => now, reminders: rem, initialName: '민', manifest: manifest);
    s.finishOnboarding(
      minimi: const Minimi(),
      picked: [
        r('a'),
        r('b'),
        r('c'),
        r('d'),
        r('weekend', days: {6, 7}),
      ],
    );
    s.takePendingBadges();
  });

  group('기록과 보상', () {
    test('오늘 요일에 맞는 루틴만 오늘 목록에 들어간다', () {
      expect(s.todayRoutines.map((e) => e.id), ['a', 'b', 'c', 'd']);
      expect(s.profile.name, '민');
    });

    test('기준(70%)을 처음 넘을 때 한 번만 보상한다', () {
      expect(s.toggle('a'), isNull); // 25%
      expect(s.toggle('b'), isNull); // 50%
      final reward = s.toggle('c'); // 75%
      expect(reward, isNotNull);
      expect(reward!.xp, RewardRules.baseXp);
      expect(s.profile.coins, RewardRules.baseCoins);
      expect(s.profile.totalXp, RewardRules.baseXp);
      expect(s.todayReward!.coins, RewardRules.baseCoins);

      s.toggle('b');
      expect(s.toggle('b'), isNull);
      expect(s.profile.coins, RewardRules.baseCoins);
    });

    test('70%로 받은 뒤 그날 100%가 되면 보너스만 한 번 더 받는다', () {
      s.completeMany(['a', 'b', 'c']); // 75%
      expect(s.profile.totalXp, RewardRules.baseXp);
      final bonus = s.toggle('d'); // 100%
      expect(bonus, isNotNull);
      expect(bonus!.xp, RewardRules.perfectBonusXp);
      expect(bonus.coins, RewardRules.perfectBonusCoins);
      expect(bonus.perfect, isTrue);
      expect(s.profile.totalXp, RewardRules.baseXp + RewardRules.perfectBonusXp);
      expect(s.profile.coins, RewardRules.baseCoins + RewardRules.perfectBonusCoins);
      // 취소했다 다시 100%가 돼도 더 받지 않는다
      s.toggle('d');
      expect(s.toggle('d'), isNull);
      expect(s.todayReward!.xp, RewardRules.baseXp + RewardRules.perfectBonusXp);
    });

    test('완료를 취소해도 보상은 회수하지 않는다', () {
      s.completeMany(['a', 'b', 'c']);
      final coins = s.profile.coins;
      expect(coins, greaterThan(0));
      for (final id in ['a', 'b', 'c']) {
        s.toggle(id);
      }
      expect(s.todayLog.done, 0);
      expect(s.profile.coins, coins);
    });

    test('한 번에 기록은 고른 것만 완료한다', () {
      final reward = s.completeMany(['a', 'b', 'c', 'd']);
      expect(s.todayLog.done, 4);
      expect(reward!.perfect, isTrue);
      expect(reward.xp, RewardRules.baseXp + RewardRules.perfectBonusXp);
    });

    test('레벨업: 경험치가 넘치면 다음 레벨로 넘어간다', () {
      final r1 = addXp(1, 40, 20);
      expect(r1.level, 2);
      expect(r1.xp, 10);
      expect(r1.levelsGained, 1);
    });

    test('날이 바뀌면 새 기록이 생기고 지난 기록은 그대로다', () {
      s.toggle('a');
      now = DateTime(2026, 11, 14, 9); // 토요일
      expect(s.todayRoutines.map((e) => e.id), ['a', 'b', 'c', 'd', 'weekend']);
      expect(s.todayLog.done, 0);
      expect(s.logs['2026-11-11']!.done, 1);
    });

    test('오늘 한 줄 메모는 오늘 기록에만 붙는다', () {
      s.setTodayMemo('  오늘도 무사히  ');
      expect(s.todayLog.memo, '오늘도 무사히');
      now = DateTime(2026, 11, 12, 9);
      expect(s.todayLog.memo, '');
      expect(s.logs['2026-11-11']!.memo, '오늘도 무사히');
    });
  });

  group('루틴 관리', () {
    test('루틴을 지워도 지난 기록은 남는다', () {
      s.toggle('a');
      now = DateTime(2026, 11, 12, 9);
      s.deleteRoutine('a');
      expect(s.todayRoutines.map((e) => e.id), isNot(contains('a')));
      expect(s.logs['2026-11-11']!.scheduled.containsKey('a'), isTrue);
    });

    test('쉬는 루틴은 오늘 목록에서 빠지고 다시 켜면 돌아온다', () {
      s.toggle('a');
      s.setRoutineActive('a', false);
      expect(s.todayRoutines.map((e) => e.id), isNot(contains('a')));
      expect(s.todayLog.completed, isNot(contains('a')));
      s.setRoutineActive('a', true);
      expect(s.todayRoutines.map((e) => e.id), contains('a'));
    });

    test('카테고리와 메모가 저장된다', () async {
      s.upsertRoutine(r('e', memo: '기상 후 바로')..category = '건강');
      await Future<void>.delayed(Duration.zero);
      final again = AppState(kv, clock: () => now, manifest: manifest);
      final e = again.routines.firstWhere((x) => x.id == 'e');
      expect(e.memo, '기상 후 바로');
      expect(e.category, '건강');
    });

    test('루틴이나 알림 설정이 바뀌면 알림을 다시 건다', () {
      final before = rem.syncs;
      s.upsertRoutine(
        r('a')
          ..alarmOn = true
          ..minuteOfDay = 420,
      );
      s.updateAlarms(s.profile.alarms..dayEnd = true);
      expect(rem.syncs, before + 2);
      expect(rem.lastSettings!.dayEnd, isTrue);
    });
  });

  group('상점·방·옷', () {
    test('가구는 레벨과 코인이 충분해야 산다', () {
      final desk = itemById('desk_wood')!; // Lv2, 40
      expect(s.buy(desk), BuyResult.levelTooLow);
      s.profile.level = 2;
      expect(s.buy(desk), BuyResult.notEnoughCoins);
      s.profile.coins = 100;
      expect(s.buy(desk), BuyResult.ok);
      expect(s.profile.coins, 60);
      expect(s.isInUse(desk), isTrue);
      expect(s.profile.acquired[desk.id], '2026-11-11');
      expect(s.buy(desk), BuyResult.alreadyOwned);
    });

    test('같은 가구를 색마다 따로 사고, 보관함에 색별로 남는다', () {
      s.profile
        ..level = 9
        ..coins = 1000;
      final bed = itemById('bed_single')!;
      final sky = bed.withColor(ItemColor.sky);
      expect(itemById(sky.id)!.color, ItemColor.sky);
      expect(sky.withColor(null).id, 'bed_single');
      expect(itemById('bed_single~nope'), isNull);
      expect(itemById('outfit_knit~sky'), isNull);
      expect(s.buy(bed), BuyResult.ok);
      expect(s.canBuy(sky), BuyResult.ok);
      expect(s.buy(sky), BuyResult.ok);
      expect(s.buy(sky), BuyResult.alreadyOwned);
      expect(s.isInUse(sky), isTrue);
      s.putAway(bed);
      s.putAway(sky);
      expect(s.storedItems.map((i) => i.id), ['bed_single', 'bed_single~sky']);
    });

    test('같은 분류 가구를 여러 개 놓을 수 있고, 보관했다 다시 놓으면 원래 자리로 간다', () {
      s.profile
        ..level = 6
        ..coins = 500;
      final a = itemById('rug_round')!, b = itemById('rug_stripe')!;
      final bed1 = itemById('bed_single')!, bed2 = itemById('bed_quilt')!;
      for (final i in [a, b, bed1, bed2]) {
        expect(s.buy(i), BuyResult.ok, reason: i.id);
      }
      expect(s.isInUse(a) && s.isInUse(b) && s.isInUse(bed1) && s.isInUse(bed2), isTrue);
      expect(s.storedItems, isEmpty);
      // 겹치지 않게 놓였다
      for (final e in s.room.floor.entries) {
        expect(s.occupancy.canPlaceFloor(s.room, e.key, e.value).ok, isTrue, reason: e.key);
      }
      final where = s.room.floor[bed1.id];
      s.putAway(bed1);
      expect(s.storedItems, [bed1]);
      expect(s.use(bed1), isTrue);
      expect(s.room.floor[bed1.id], where);
    });

    test('벽지는 하나만 — 새로 사면 교체되고 이전 것은 보관함으로', () {
      s.profile
        ..level = 6
        ..coins = 500;
      s.buy(itemById('wall_sage')!);
      s.buy(itemById('wall_sky')!);
      expect(s.room.wallSurface, 'wall_sky');
      expect(s.storedItems.map((e) => e.id), ['wall_sage']);
    });

    test('바닥재는 벽지와 따로 깔린다', () {
      s.profile
        ..level = 6
        ..coins = 500;
      s.buy(itemById('wall_sage')!);
      s.buy(itemById('floor_checker')!);
      expect(s.room.wallSurface, 'wall_sage');
      expect(s.room.floorSurface, 'floor_checker');
      s.putAway(itemById('floor_checker')!);
      expect(s.room.floorSurface, isNull);
      expect(s.room.wallSurface, 'wall_sage');
    });

    test('방이 꽉 차면 사도 보관함으로 가고, 코인은 정상 차감된다', () {
      // 테스트용 매니페스트: 침대가 방 전체(8×8)를 차지한다
      final tm = PixelManifest.parse(
        '{"items": {"bed_single": {"layer": "object", "footprint": [8, 8], "height": 8},'
        ' "chair_wood": {"layer": "object", "footprint": [1, 1], "height": 8}}}',
      );
      final t = AppState(MemoryKeyValue(), clock: () => now, manifest: tm);
      t.profile
        ..level = 3
        ..coins = 200;
      expect(t.buy(itemById('bed_single')!), BuyResult.ok);
      expect(t.buy(itemById('chair_wood')!), BuyResult.okStored);
      expect(t.profile.coins, 200 - 60 - 25);
      expect(t.profile.owned, contains('chair_wood'));
      expect(t.storedItems.map((e) => e.id), ['chair_wood']);
      expect(t.use(itemById('chair_wood')!), isFalse);
      t.putAway(itemById('bed_single')!);
      expect(t.use(itemById('chair_wood')!), isTrue);
    });

    test('기존 사용자: placed만 있는 저장 데이터를 불러오면 room이 생기고 다른 데이터는 그대로다', () async {
      final kv = MemoryKeyValue();
      final legacy = Profile(
        name: '하루',
        level: 4,
        coins: 77,
        owned: {'bed_single', 'desk_wood', 'rug_round', 'window_curtain', 'wall_sage', 'outfit_knit'},
        placed: {
          'bed': 'bed_single',
          'desk': 'desk_wood',
          'rug': 'rug_round',
          'window': 'window_curtain',
          'wallpaper': 'wall_sage',
        },
        outfitId: 'outfit_knit',
        acquired: {'bed_single': '2026-11-01'},
      );
      final json = legacy.toJson()..remove('room');
      expect(json.containsKey('room'), isFalse);
      await kv.write('profile', jsonEncode(json));
      await kv.write('onboarded', 'true');

      final st = AppState(kv, clock: () => now, manifest: manifest);
      expect(st.profile.coins, 77);
      expect(st.profile.level, 4);
      expect(st.profile.owned.length, 6);
      expect(st.profile.outfitId, 'outfit_knit');
      expect(st.profile.acquired['bed_single'], '2026-11-01');
      expect(st.profile.placed.length, 5, reason: 'placed는 지우지 않는다');
      expect(st.room.floor.keys, containsAll(['bed_single', 'desk_wood', 'rug_round']));
      expect(st.room.wall.keys, ['window_curtain']);
      expect(st.room.wallSurface, 'wall_sage');
      expect(st.storedItems, isEmpty);
      // 저장됐다가 다시 열어도 같다
      await Future<void>.delayed(Duration.zero);
      final again = AppState(kv, clock: () => now, manifest: manifest);
      expect(again.room.floor, st.room.floor);
    });

    test('편집: 옮기기·회전·충돌 시 그대로', () {
      s.profile
        ..level = 3
        ..coins = 500;
      s.buy(itemById('bed_single')!);
      s.buy(itemById('chair_wood')!);
      final bed = s.room.floor['bed_single']!;
      expect(s.moveFloor('bed_single', const FloorPos(0, 0)).ok, isTrue);
      expect(s.rotateFloor('bed_single').ok, isTrue);
      expect(s.room.floor['bed_single']!.r, Rot.r1);
      // 의자를 침대 위로 옮기면 실패하고 그대로
      final chair = s.room.floor['chair_wood']!;
      final c = s.moveFloor('chair_wood', const FloorPos(1, 0));
      expect(c.status, PlaceStatus.blocked);
      expect(s.room.floor['chair_wood'], chair);
      expect(bed, isNotNull);
    });

    test('옷과 액세서리를 사서 입고 벗는다', () {
      s.profile
        ..level = 5
        ..coins = 300;
      final knit = itemById('outfit_knit')!, pin = itemById('acc_starpin')!;
      s.buy(knit);
      s.buy(pin);
      expect(s.profile.outfitId, knit.id);
      expect(s.profile.accessoryId, pin.id);
      // 귀고리는 액세서리와 따로 찬다
      final hoop = itemById('acc_ear_hoop')!;
      s.buy(hoop);
      expect((s.profile.accessoryId, s.profile.earringId), (pin.id, hoop.id));
      expect(s.isInUse(pin) && s.isInUse(hoop), isTrue);
      s.putAway(hoop);
      expect((s.profile.accessoryId, s.profile.earringId), (pin.id, null));
      s.putAway(knit);
      expect(s.profile.outfitId, isNull);
      expect(s.storedItems, unorderedEquals([knit, hoop]));
    });
  });

  group('배지 (연속 기록 없음)', () {
    test('첫 기록·해낸 하루·온전한 하루', () {
      s.completeMany(['a', 'b', 'c', 'd']);
      expect(s.takePendingBadges(), containsAll(['first_check', 'first_day', 'perfect_day']));
      expect(s.takePendingBadges(), isEmpty);
    });

    test('며칠 쉬었다가 다시 기록하면 다시 시작 배지', () {
      s.toggle('a');
      s.takePendingBadges();
      now = DateTime(2026, 11, 16, 9); // 5일 뒤
      s.toggle('a');
      expect(s.takePendingBadges(), contains('comeback'));
    });

    test('연이은 날에는 다시 시작 배지가 없다', () {
      s.toggle('a');
      now = DateTime(2026, 11, 12, 9);
      s.toggle('a');
      expect(s.profile.badges.containsKey('comeback'), isFalse);
    });

    test('첫 옷을 입으면 새 옷 배지', () {
      s.profile.coins = 100;
      s.buy(itemById('outfit_knit')!);
      expect(s.takePendingBadges(), containsAll(['first_item', 'first_outfit']));
    });
  });

  test('월간 루틴별 현황을 센다', () {
    s.completeMany(['a', 'b']);
    now = DateTime(2026, 11, 12, 9);
    s.toggle('a');
    final stats = s.perRoutine(DateTime(2026, 11, 1), DateTime(2026, 11, 30));
    final a = stats.firstWhere((e) => e.label.contains('a'));
    expect(a.done, 2);
    expect(a.total, 2);
  });

  test('저장한 상태를 다시 불러온다', () async {
    s.completeMany(['a', 'b', 'c']);
    await Future<void>.delayed(Duration.zero);
    final again = AppState(kv, clock: () => now, manifest: manifest);
    expect(again.onboarded, isTrue);
    expect(again.routines.length, 5);
    expect(again.todayLog.done, 3);
    expect(again.profile.coins, s.profile.coins);
    expect(again.profile.badges, s.profile.badges);
  });

  group('계정 (기기용 로그인)', () {
    test('계정 삭제는 그 계정의 기록만 지우고 로그아웃한다', () async {
      final kv = MemoryKeyValue();
      final a = DeviceAuthService(kv);
      expect(await a.signIn(SocialProvider.kakao), isNull);
      final uid = a.current!.uid;
      expect(a.current!.provider, SocialProvider.kakao);
      await kv.write('${userPrefix(uid)}routines', '[]');
      await kv.write('${userPrefix('other')}routines', '[]');

      expect(await a.deleteAccount(), isNull);
      expect(a.signedIn, isFalse);
      expect(kv.read('${userPrefix(uid)}routines'), isNull);
      expect(kv.read('${userPrefix('other')}routines'), '[]');
    });

    test('세션은 다시 열어도 유지되고, 로그아웃하면 풀린다', () async {
      final kv = MemoryKeyValue();
      await DeviceAuthService(kv).signIn(SocialProvider.google);
      final again = DeviceAuthService(kv);
      expect(again.current?.provider, SocialProvider.google);
      await again.logout();
      expect(DeviceAuthService(kv).signedIn, isFalse);
    });
  });

  test('개발용 충전: 누를 때마다 코인 +10000, 레벨 +1', () {
    final s = AppState(MemoryKeyValue(), clock: () => DateTime(2026, 11, 11, 9));
    final before = s.profile.coins;
    s.debugTopUp();
    expect(s.profile.coins, before + 10000);
    expect(s.profile.level, 2);
    s.debugTopUp();
    expect(s.profile.coins, before + 20000);
    expect(s.profile.level, 3);
  });

  test('회전: 네 방향을 차례로 돌아 제자리로, 막힌 방향은 건너뛴다', () {
    final s = AppState(MemoryKeyValue(), clock: () => DateTime(2026, 11, 11, 9), manifest: manifest)
      ..debugTopUp()
      ..debugTopUp();
    s.buy(itemById('bed_single')!);
    expect(s.moveFloor('bed_single', const FloorPos(3, 3)).ok, isTrue);
    for (final r in [Rot.r1, Rot.r2, Rot.r3, Rot.r0]) {
      expect(s.rotateFloor('bed_single').ok, isTrue);
      expect(s.room.floor['bed_single']!.r, r);
    }
    // 오른쪽 끝 열: 1×2는 서지만 2×1(R1·R3)은 방 밖 → R0에서 바로 R2로
    expect(s.moveFloor('bed_single', const FloorPos(7, 3)).ok, isTrue);
    expect(s.rotateFloor('bed_single').ok, isTrue);
    expect(s.room.floor['bed_single']!.r, Rot.r2);
  });
}
