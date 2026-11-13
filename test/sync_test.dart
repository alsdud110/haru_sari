import 'package:flutter_test/flutter_test.dart';
import 'package:haru_sari/data/catalog.dart';
import 'package:haru_sari/data/models.dart';
import 'package:haru_sari/data/rewards.dart';
import 'package:haru_sari/data/store.dart';
import 'package:haru_sari/data/sync.dart';

import 'room/manifest_test.dart' show loadManifest;

final manifest = loadManifest();

/// 서버 규칙(supabase/migrations/..._init.sql)을 흉내 낸 가짜 서버.
class FakeServer implements Remote {
  bool offline = false;
  Map<String, dynamic>? state;
  DateTime? stateAt;
  final Map<String, ({Map<String, dynamic> data, DateTime at})> logs = {};
  int level = 1, xp = 0, totalXp = 0, coins = 0;
  final Map<String, ({int xp, int coins, bool perfect})> grants = {};
  final Set<String> purchases = {};
  final List<String> calls = [];

  void _net() {
    if (offline) throw Exception('offline');
  }

  Wallet get wallet => Wallet(level: level, xp: xp, totalXp: totalXp, coins: coins);

  @override
  Future<RemoteSnapshot> pull() async {
    _net();
    return RemoteSnapshot(
      state: state,
      stateAt: stateAt,
      logs: Map.of(logs),
      wallet: wallet,
      purchases: Set.of(purchases),
      hasGrants: grants.isNotEmpty,
    );
  }

  @override
  Future<void> pushState({
    required String nickname,
    required bool onboarded,
    required List<dynamic> routines,
    required Map<String, dynamic> profile,
    required DateTime at,
  }) async {
    _net();
    calls.add('state');
    state = {'nickname': nickname, 'onboarded': onboarded, 'routines': routines, 'profile': profile};
    stateAt = at;
  }

  @override
  Future<void> pushLogs(Map<String, ({Map<String, dynamic> data, DateTime at})> l) async {
    _net();
    calls.add('logs ${l.keys.join(',')}');
    logs.addAll(l);
  }

  void _addXp(int x, int c) {
    xp += x;
    totalXp += x;
    var ups = 0;
    while (xp >= level * 50) {
      xp -= level * 50;
      level++;
      ups++;
    }
    coins += c + ups * 20;
  }

  @override
  Future<({int gainedXp, int gainedCoins, Wallet wallet})> claim(String day, int done, int total) async {
    _net();
    calls.add('claim $day');
    final g = grants[day];
    final perfect = done == total;
    var ax = 0, ac = 0;
    if (g == null) {
      if (done * 10 >= total * 7) {
        ax = 20 + (perfect ? 10 : 0);
        ac = 10 + (perfect ? 5 : 0);
        grants[day] = (xp: ax, coins: ac, perfect: perfect);
      }
    } else if (perfect && !g.perfect) {
      ax = 10;
      ac = 5;
      grants[day] = (xp: g.xp + ax, coins: g.coins + ac, perfect: true);
    }
    if (ax > 0) _addXp(ax, ac);
    return (gainedXp: ax, gainedCoins: ac, wallet: wallet);
  }

  @override
  Future<BuyReply> buy(String itemId, int price, int minLevel) async {
    _net();
    calls.add('buy $itemId');
    if (purchases.contains(itemId)) return BuyReply(ok: false, reason: 'already_owned', wallet: wallet);
    if (level < minLevel) return BuyReply(ok: false, reason: 'level_too_low', wallet: wallet);
    if (coins < price) return BuyReply(ok: false, reason: 'not_enough_coins', wallet: wallet);
    purchases.add(itemId);
    coins -= price;
    return BuyReply(ok: true, wallet: wallet);
  }

  /// 날짜 → 그날 광고 보상을 준 횟수 (claim_ad_reward 와 같은 규칙: 하루 3번, 5코인)
  final Map<String, int> adUsed = {};

  /// 서버에 광고 보상 함수를 아직 올리지 않은 상태를 흉내 낸다
  bool adFunctionMissing = false;

  @override
  Future<AdReply> adReward(String day) async {
    _net();
    calls.add('ad $day');
    if (adFunctionMissing) throw const RemoteRejected('function not found');
    final n = adUsed[day] ?? 0;
    if (n >= 3) return AdReply(ok: false, used: n, wallet: wallet);
    adUsed[day] = n + 1;
    coins += 5;
    return AdReply(ok: true, used: n + 1, wallet: wallet);
  }
}

void main() {
  var now = DateTime(2026, 11, 11, 9);
  Routine r(String id) => Routine(id: id, name: id, emoji: '✨');

  /// 한 기기: 기기 저장소 + AppState + 동기화
  ({AppState s, SyncEngine sync, MemoryKeyValue kv}) device(FakeServer server, {MemoryKeyValue? kv}) {
    final store = kv ?? MemoryKeyValue();
    final s = AppState(store, clock: () => now, manifest: manifest);
    final sync = SyncEngine(s, server, store, clock: () => now);
    s.sync = sync;
    return (s: s, sync: sync, kv: store);
  }

  Future<void> settle(SyncEngine sync) async {
    await sync.flush();
    await sync.flush();
  }

  setUp(() => now = DateTime(2026, 11, 11, 9));

  test('다른 기기에서 로그인하면 루틴·기록·레벨·코인·산 물건·방이 그대로 이어진다', () async {
    final server = FakeServer();
    final a = device(server);
    await a.sync.start();
    a.s.finishOnboarding(name: '민', minimi: const Minimi(skin: 2), picked: [r('a'), r('b'), r('c')]);
    a.s.completeMany(['a', 'b', 'c']); // 100% → 30 XP, 15코인
    await settle(a.sync);
    expect(server.coins, 15);

    final rug = shopCatalog.firstWhere((i) => i.id == 'rug_round'); // 20코인
    server.coins += 100; // (다른 날 받은 셈)
    await a.sync.start();
    expect(a.s.profile.coins, 115);
    expect(a.s.buy(rug), isNot(BuyResult.notEnoughCoins));
    await settle(a.sync);
    expect(server.purchases, contains('rug_round'));
    expect(server.coins, 95);

    // 새 기기
    now = now.add(const Duration(minutes: 5));
    final b = device(server);
    expect(b.s.onboarded, isFalse);
    await b.sync.start();
    expect(b.s.onboarded, isTrue);
    expect(b.s.profile.name, '민');
    expect(b.s.profile.minimi.skin, 2);
    expect(b.s.routines.map((e) => e.id), ['a', 'b', 'c']);
    expect(b.s.todayLog.done, 3);
    expect(b.s.profile.coins, 95);
    expect(b.s.profile.totalXp, 30);
    expect(b.s.profile.owned, contains('rug_round'));
    expect(b.s.room.contains('rug_round'), isTrue);
  });

  test('두 기기에서 같은 날 보상을 받아도 서버는 한 번만 준다', () async {
    final server = FakeServer();
    final a = device(server);
    a.s.finishOnboarding(name: '민', minimi: const Minimi(), picked: [r('a'), r('b'), r('c')]);
    await a.sync.start();
    final b = device(server);
    await b.sync.start();

    a.s.completeMany(['a', 'b', 'c']);
    b.s.completeMany(['a', 'b', 'c']);
    await settle(a.sync);
    await settle(b.sync);
    expect(server.totalXp, RewardRules.baseXp + RewardRules.perfectBonusXp);
    expect(server.coins, RewardRules.baseCoins + RewardRules.perfectBonusCoins);
    expect(b.s.profile.coins, server.coins); // 기기 값도 서버에 맞춰진다
  });

  test('오프라인이면 쌓아 두었다가 연결되면 보낸다', () async {
    final server = FakeServer();
    final a = device(server);
    a.s.finishOnboarding(name: '민', minimi: const Minimi(), picked: [r('a'), r('b'), r('c')]);
    await a.sync.start();
    server.offline = true;
    a.s.completeMany(['a', 'b', 'c']);
    await settle(a.sync);
    expect(server.totalXp, 0);
    expect(a.s.profile.totalXp, 30); // 기기에서는 바로 보인다

    server.offline = false;
    await settle(a.sync);
    expect(server.totalXp, 30);
    expect(server.logs[dateKey(now)]!.data['completed'], hasLength(3));
  });

  test('다른 기기에서 코인을 먼저 써서 서버가 거절하면 구매를 되돌린다', () async {
    final server = FakeServer()..coins = 20;
    final a = device(server);
    a.s.finishOnboarding(name: '민', minimi: const Minimi(), picked: [r('a')]);
    await a.sync.start();
    expect(a.s.profile.coins, 20);
    server.coins = 0; // 다른 기기에서 다 씀
    final rug = shopCatalog.firstWhere((i) => i.id == 'rug_round');
    a.s.buy(rug);
    expect(a.s.profile.owned, contains('rug_round'));
    await settle(a.sync);
    expect(a.s.profile.owned, isNot(contains('rug_round')));
    expect(a.s.room.contains('rug_round'), isFalse);
    expect(a.s.profile.coins, 0);
  });

  test('광고 보상: 하루 3번까지 5코인씩 받고, 서버 지갑과 맞는다', () async {
    final server = FakeServer();
    final a = device(server);
    await a.sync.start();
    a.s.finishOnboarding(name: '민', minimi: const Minimi(), picked: [r('a')]);
    expect(a.s.adsLeftToday, 3);
    expect(a.s.grantAdReward(), isTrue);
    expect(a.s.grantAdReward(), isTrue);
    expect((a.s.adsLeftToday, a.s.profile.coins), (1, 10));
    expect(a.s.grantAdReward(), isTrue);
    expect(a.s.grantAdReward(), isFalse); // 네 번째는 주지 않는다
    expect((a.s.adsLeftToday, a.s.profile.coins), (0, 15));
    await settle(a.sync);
    expect(server.adUsed['2026-11-11'], 3);
    expect(server.coins, 15);
    expect(a.s.profile.coins, 15);

    // 다음 날에는 다시 3번
    now = now.add(const Duration(days: 1));
    expect(a.s.adsLeftToday, 3);
    expect(a.s.grantAdReward(), isTrue);
    await settle(a.sync);
    expect(server.coins, 20);
  });

  test('광고 보상: 다른 기기에서 이미 다 봤으면 서버가 거절하고, 코인과 남은 횟수가 서버 값으로 돌아온다', () async {
    final server = FakeServer();
    final a = device(server), b = device(server);
    await a.sync.start();
    a.s.finishOnboarding(name: '민', minimi: const Minimi(), picked: [r('a')]);
    for (var i = 0; i < 3; i++) {
      a.s.grantAdReward();
    }
    await settle(a.sync);

    // 기기 B는 아직 모른다 (오프라인으로 한 번 봤다)
    server.offline = true;
    expect(b.s.adsLeftToday, 3);
    expect(b.s.grantAdReward(), isTrue);
    expect(b.s.profile.coins, 5);
    server.offline = false;
    await settle(b.sync);
    expect(server.coins, 15);
    expect(b.s.profile.coins, 15); // 서버 지갑으로
    expect(b.s.adsLeftToday, 0); // 서버가 센 횟수로
  });

  test('광고 보상: 서버에 함수가 아직 없어도 뒤에 쌓인 요청이 막히지 않는다', () async {
    final server = FakeServer()..adFunctionMissing = true;
    final a = device(server);
    await a.sync.start();
    a.s.finishOnboarding(name: '민', minimi: const Minimi(), picked: [r('a'), r('b')]);
    expect(a.s.grantAdReward(), isTrue);
    a.s.completeMany(['a', 'b']);
    await settle(a.sync);
    expect(server.calls, containsAllInOrder(['ad 2026-11-11', 'claim 2026-11-11']));
    expect(server.grants, hasLength(1)); // 하루 보상은 그대로 올라갔다
    expect(server.coins, 15);
  });

  test('동기화 전부터 쓰던 기기: 처음 연결하면 지난 보상과 구매를 서버로 옮긴다', () async {
    final server = FakeServer();
    final kv = MemoryKeyValue();
    // 동기화 없이 하루를 보낸 기기
    final old = AppState(kv, clock: () => now, manifest: manifest);
    old.finishOnboarding(name: '민', minimi: const Minimi(), picked: [r('a'), r('b')]);
    old.completeMany(['a', 'b']); // 30 XP, 15코인
    final rug = shopCatalog.firstWhere((i) => i.id == 'rug_round');
    now = now.add(const Duration(days: 1));
    old.completeMany(['a', 'b']); // +30 XP, +15코인, 레벨 2 보너스 +20 → 50코인
    expect(old.buy(rug), isNot(BuyResult.notEnoughCoins)); // 30코인 남음
    expect(old.profile.coins, 30);

    await Future<void>.delayed(Duration.zero); // 기기 저장이 끝나도록
    final a = device(server, kv: kv);
    await a.sync.start();
    await settle(a.sync);
    expect(server.grants.keys, hasLength(2));
    expect(server.purchases, contains('rug_round'));
    expect(server.coins, 30);
    expect(server.level, 2);
    expect(server.state!['onboarded'], isTrue);
    expect(server.logs, hasLength(2));
    expect(a.s.profile.coins, 30);
    expect(a.s.profile.owned, contains('rug_round'));
  });
}
