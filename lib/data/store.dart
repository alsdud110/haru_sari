import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads.dart';
import 'badges.dart';
import '../room/iso.dart';
import '../room/layout.dart';
import '../room/manifest.dart';
import '../room/occupancy.dart';
import 'catalog.dart';
import 'models.dart';
import 'reminders.dart';
import 'rewards.dart';
import 'sync.dart';

/// 저장소 추상화. 테스트에서는 메모리 저장소를 쓴다.
abstract class KeyValue {
  String? read(String key);
  Future<void> write(String key, String value);

  /// [prefix]로 시작하는 키를 모두 지운다 (계정 삭제용).
  Future<void> removePrefix(String prefix);
}

class PrefsKeyValue implements KeyValue {
  PrefsKeyValue(this._p);
  final SharedPreferences _p;
  @override
  String? read(String key) => _p.getString(key);
  @override
  Future<void> write(String key, String value) => _p.setString(key, value);
  @override
  Future<void> removePrefix(String prefix) async {
    for (final k in _p.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      await _p.remove(k);
    }
  }
}

class MemoryKeyValue implements KeyValue {
  final Map<String, String> data = {};
  @override
  String? read(String key) => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> removePrefix(String prefix) async => data.removeWhere((k, _) => k.startsWith(prefix));
}

/// 계정마다 저장 공간을 나눈다.
class PrefixedKeyValue implements KeyValue {
  PrefixedKeyValue(this._kv, this.prefix);
  final KeyValue _kv;
  final String prefix;
  @override
  String? read(String key) => _kv.read('$prefix$key');
  @override
  Future<void> write(String key, String value) => _kv.write('$prefix$key', value);
  @override
  Future<void> removePrefix(String p) => _kv.removePrefix('$prefix$p');
}

/// 계정별 데이터가 저장되는 접두어.
String userPrefix(String uid) => 'u/$uid/';

/// [okStored]: 샀지만 방에 빈 자리가 없어 보관함에 넣음 (buy의 결과로만 나온다)
enum BuyResult { ok, okStored, alreadyOwned, levelTooLow, notEnoughCoins }

/// 앱 전체 상태. 루틴·하루 기록·프로필(경험치/코인/방/옷/배지)을 저장한다.
const _catalogItem = itemById;

class AppState extends ChangeNotifier {
  AppState(
    this._kv, {
    DateTime Function()? clock,
    Reminders? reminders,
    RewardAds? ads,
    String initialName = '',
    PixelManifest? manifest,
  }) : _clock = clock ?? DateTime.now,
       reminders = reminders ?? NoReminders(),
       ads = ads ?? const NoRewardAds(),
       manifest = manifest ?? PixelManifest(version: 1, items: const {}, base: const {}) {
    _load();
    if (profile.name.isEmpty) profile.name = initialName;
  }

  final KeyValue _kv;
  final DateTime Function() _clock;
  final Reminders reminders;

  /// 보상형 광고 (없으면 광고 버튼이 보이지 않는다)
  final RewardAds ads;

  /// 가구 점유·회전 정보 (assets/pixel/manifest.json)
  final PixelManifest manifest;
  late final Occupancy occupancy = Occupancy(manifest);

  static const _kRoutines = 'routines';
  static const _kLogs = 'logs';
  static const _kProfile = 'profile';
  static const _kOnboarded = 'onboarded';

  final List<Routine> routines = [];
  final Map<String, DayLog> logs = {};
  Profile profile = Profile();
  bool onboarded = false;

  /// 방금 받은 배지 (화면이 꺼내 보여주고 비운다)
  final List<String> pendingBadges = [];

  DateTime get now => _clock();
  DateTime get today => dateOnly(now);
  String get todayKey => dateKey(today);

  void _load() {
    final r = _kv.read(_kRoutines);
    if (r != null) {
      routines.addAll((jsonDecode(r) as List).map((e) => Routine.fromJson((e as Map).cast<String, dynamic>())));
    }
    final l = _kv.read(_kLogs);
    if (l != null) {
      (jsonDecode(l) as Map).forEach((k, v) {
        logs[k as String] = DayLog.fromJson((v as Map).cast<String, dynamic>());
      });
    }
    final p = _kv.read(_kProfile);
    if (p != null) profile = Profile.fromJson((jsonDecode(p) as Map).cast<String, dynamic>());
    onboarded = _kv.read(_kOnboarded) == 'true';
    _migrateRoom();
  }

  /// 기존 사용자: room이 없으면 placed(자리 → id)에서 한 번 만든다. 코인·보유·기록은 건드리지 않는다.
  void _migrateRoom() {
    if (profile.room != null) return;
    final room = RoomLayout.fromLegacy(profile.placed);
    occupancy.repair(room); // 겹치면 옮기고, 자리가 없으면 빼서 보관함에 남긴다
    profile.room = room;
    if (_kv.read(_kProfile) != null) _save();
  }

  RoomLayout get room => profile.room ??= RoomLayout();

  Future<void> _save() async {
    await _kv.write(_kRoutines, jsonEncode(routines.map((e) => e.toJson()).toList()));
    await _kv.write(_kLogs, jsonEncode(logs.map((k, v) => MapEntry(k, v.toJson()))));
    await _kv.write(_kProfile, jsonEncode(profile.toJson()));
    await _kv.write(_kOnboarded, onboarded.toString());
  }

  /// 개발용: 누를 때마다 코인 +10000, 레벨 +1 (디버그 빌드의 코인 칩 누르기).
  /// 서버와 동기화하는 계정에서는 다음 동기화 때 서버 값으로 돌아간다. 개발자 모드 계정은 그대로 남는다.
  void debugTopUp() {
    profile
      ..coins += 10000
      ..level += 1;
    _commit();
  }

  void _commit({bool resync = false}) {
    _checkBadges();
    notifyListeners();
    _save();
    sync?.changed(day: logs.containsKey(todayKey) ? todayKey : null);
    if (resync) syncReminders();
  }

  // ───────── 서버 동기화 (sync.dart 가 부른다) ─────────

  /// 붙어 있으면 바뀐 것을 서버에 올린다. 없으면 기기에만 저장한다 (테스트 등).
  SyncEngine? sync;

  ShopItem? itemById(String id) => _catalogItem(id);

  /// 서버 지갑 값으로 맞춘다.
  void applyWallet(Wallet w) {
    if (profile.level == w.level && profile.xp == w.xp && profile.totalXp == w.totalXp && profile.coins == w.coins) {
      return;
    }
    profile
      ..level = w.level
      ..xp = w.xp
      ..totalXp = w.totalXp
      ..coins = w.coins;
    notifyListeners();
    _save();
  }

  /// 다른 기기에서 고친 루틴·방·설정을 받는다. 지갑 값은 그대로 둔다 (applyWallet 이 맞춘다).
  void applyRemoteState({
    required String nickname,
    required List<dynamic> routines,
    required Map<String, dynamic> profile,
  }) {
    final keep = this.profile;
    final p = Profile.fromJson(profile)
      ..level = keep.level
      ..xp = keep.xp
      ..totalXp = keep.totalXp
      ..coins = keep.coins;
    if (nickname.trim().isNotEmpty) p.name = nickname.trim();
    this.profile = p;
    this.routines
      ..clear()
      ..addAll(routines.map((e) => Routine.fromJson((e as Map).cast<String, dynamic>())));
    onboarded = true;
    _migrateRoom();
    _syncToday();
    notifyListeners();
    _save();
    syncReminders();
  }

  /// 다른 기기에서 쓴 날짜별 기록을 받는다.
  void applyRemoteLogs(Map<String, Map<String, dynamic>> days) {
    days.forEach((k, v) => logs[k] = DayLog.fromJson(v));
    if (days.containsKey(todayKey)) _syncToday();
    notifyListeners();
    _save();
  }

  /// 다른 기기에서 산 물건을 보관함에 더한다.
  void addOwned(Set<String> ids) {
    final add = ids.difference(profile.owned).where((id) => itemById(id) != null).toList();
    if (add.isEmpty) return;
    for (final id in add) {
      profile.owned.add(id);
      profile.acquired.putIfAbsent(id, () => todayKey);
    }
    notifyListeners();
    _save();
  }

  /// 서버가 구매를 거절했을 때 (다른 기기에서 코인을 먼저 썼을 때) 되돌린다.
  void revertPurchase(String id) {
    final item = itemById(id);
    if (item == null || !profile.owned.contains(id)) return;
    putAway(item);
    profile.owned.remove(id);
    profile.acquired.remove(id);
    notifyListeners();
    _save();
  }

  Future<void> syncReminders() => reminders.sync(routines: routines, settings: profile.alarms);

  void _checkBadges() {
    final ids = newlyEarned(profile: profile, logs: logs, todayKey: todayKey);
    for (final id in ids) {
      profile.badges[id] = todayKey;
      pendingBadges.add(id);
    }
  }

  List<String> takePendingBadges() {
    final out = [...pendingBadges];
    pendingBadges.clear();
    return out;
  }

  // ───────── 첫 설정 ─────────

  void finishOnboarding({String? name, required Minimi minimi, required List<Routine> picked, AlarmSettings? alarms}) {
    if (name != null && name.trim().isNotEmpty) profile.name = name.trim();
    profile.minimi = minimi;
    if (alarms != null) profile.alarms = alarms;
    routines
      ..clear()
      ..addAll(picked);
    onboarded = true;
    _syncToday();
    _commit(resync: true);
  }

  // ───────── 루틴 관리 ─────────

  String newId() => '${now.microsecondsSinceEpoch}${routines.length}';

  List<Routine> get sortedRoutines => [...routines]..sort(_byTime);

  static int _byTime(Routine a, Routine b) => (a.minuteOfDay ?? 9999).compareTo(b.minuteOfDay ?? 9999);

  void upsertRoutine(Routine r) {
    final i = routines.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      routines[i] = r;
    } else {
      routines.add(r);
    }
    _syncToday();
    _commit(resync: true);
  }

  void setRoutineActive(String id, bool active) {
    final r = routines.where((e) => e.id == id).firstOrNull;
    if (r == null) return;
    r.active = active;
    _syncToday();
    _commit(resync: true);
  }

  void deleteRoutine(String id) {
    routines.removeWhere((e) => e.id == id);
    _syncToday();
    _commit(resync: true);
  }

  void updateProfileName(String name) {
    profile.name = name.trim();
    _commit();
  }

  void updateMinimi(Minimi m) {
    profile.minimi = m;
    _commit();
  }

  void updateAlarms(AlarmSettings a) {
    profile.alarms = a;
    _commit(resync: true);
  }

  // ───────── 오늘의 기록 ─────────

  /// 오늘 기록. 없으면 오늘 요일에 맞는 루틴으로 만든다.
  DayLog get todayLog {
    final existing = logs[todayKey];
    if (existing != null) return existing;
    final log = DayLog(date: todayKey, scheduled: _scheduledFor(today));
    logs[todayKey] = log;
    _save();
    return log;
  }

  Map<String, String> _scheduledFor(DateTime day) => {
    for (final r in sortedRoutines.where((r) => r.runsOn(day))) r.id: '${r.emoji} ${r.name}',
  };

  /// 루틴이 바뀌면 오늘 기록만 다시 맞춘다. 지난 기록은 그대로 둔다.
  void _syncToday() {
    final log = logs[todayKey];
    final scheduled = _scheduledFor(today);
    if (log == null) {
      logs[todayKey] = DayLog(date: todayKey, scheduled: scheduled);
      return;
    }
    log.scheduled
      ..clear()
      ..addAll(scheduled);
    log.completed.removeWhere((id) => !scheduled.containsKey(id));
  }

  List<Routine> get todayRoutines {
    final ids = todayLog.scheduled.keys.toSet();
    return sortedRoutines.where((r) => ids.contains(r.id)).toList();
  }

  bool isDoneToday(String id) => todayLog.completed.contains(id);

  /// 체크/해제. 기준을 처음 넘으면 그날 보상을 돌려준다.
  DailyReward? toggle(String id) {
    final log = todayLog;
    if (!log.scheduled.containsKey(id)) return null;
    if (!log.completed.remove(id)) log.completed.add(id);
    final reward = _maybeReward(log);
    _commit();
    return reward;
  }

  /// 여러 개 한 번에 완료.
  DailyReward? completeMany(Iterable<String> ids) {
    final log = todayLog;
    log.completed.addAll(ids.where(log.scheduled.containsKey));
    final reward = _maybeReward(log);
    _commit();
    return reward;
  }

  /// 오늘 한 줄 메모. 지난 날은 고칠 수 없다.
  void setTodayMemo(String memo) {
    todayLog.memo = memo.trim();
    _commit();
  }

  /// 하루 보상. 기준을 처음 넘을 때 한 번, 그 뒤 그날 100%가 되면 보너스만 한 번 더 준다 (PL-BBQESH).
  /// 서버(claim_daily_reward)도 같은 규칙으로 날짜당 한 번만 지급한다.
  DailyReward? _maybeReward(DayLog log) {
    if (log.total == 0) return null;
    final int xp;
    final int baseCoins;
    if (!log.rewarded) {
      final r = rewardFor(log.rate);
      if (r == null) return null;
      xp = r.xp;
      baseCoins = r.coins;
      log
        ..rewarded = true
        ..perfectPaid = r.perfect;
    } else if (!log.perfectPaid && log.done == log.total) {
      xp = RewardRules.perfectBonusXp;
      baseCoins = RewardRules.perfectBonusCoins;
      log.perfectPaid = true;
    } else {
      return null;
    }
    final lv = addXp(profile.level, profile.xp, xp);
    final coins = baseCoins + lv.levelsGained * RewardRules.levelUpCoins;
    profile
      ..level = lv.level
      ..xp = lv.xp
      ..totalXp += xp
      ..coins += coins;
    log
      ..rewardXp += xp
      ..rewardCoins += coins;
    sync?.queueClaim(log.date, log.done, log.total);
    return DailyReward(
      xp: xp,
      coins: coins,
      perfect: log.perfectPaid,
      levelsGained: lv.levelsGained,
      newLevel: lv.level,
    );
  }

  /// 오늘 이미 받은 보상 (다시 보기용)
  DailyReward? get todayReward {
    final l = todayLog;
    if (!l.rewarded) return null;
    return DailyReward(
      xp: l.rewardXp,
      coins: l.rewardCoins,
      perfect: l.perfectPaid,
      levelsGained: 0,
      newLevel: profile.level,
    );
  }

  // ───────── 광고 보상 ─────────

  /// 오늘 광고 보상을 받은 횟수
  int get adsUsedToday => profile.adDay == todayKey ? profile.adCount : 0;

  /// 오늘 더 볼 수 있는 횟수 (하루 [AdRules.perDay]번)
  int get adsLeftToday => (AdRules.perDay - adsUsedToday).clamp(0, AdRules.perDay);

  /// 광고를 끝까지 봤을 때 코인을 준다. 오늘 횟수를 다 썼으면 주지 않고 false.
  bool grantAdReward() {
    if (adsLeftToday <= 0) return false;
    final used = adsUsedToday;
    profile
      ..adDay = todayKey
      ..adCount = used + 1
      ..coins += AdRules.coins;
    _commit();
    sync?.queueAd(todayKey);
    return true;
  }

  /// 서버가 센 오늘의 횟수로 맞춘다 (다른 기기에서 본 것까지 더해진 값).
  void applyAdCount(String day, int used) {
    if (day != todayKey || (profile.adDay == day && profile.adCount == used)) return;
    profile
      ..adDay = day
      ..adCount = used;
    notifyListeners();
    _save();
  }

  // ───────── 상점·방·옷 ─────────

  BuyResult canBuy(ShopItem item) {
    if (profile.owned.contains(item.id)) return BuyResult.alreadyOwned;
    if (profile.level < item.level) return BuyResult.levelTooLow;
    if (profile.coins < item.price) return BuyResult.notEnoughCoins;
    return BuyResult.ok;
  }

  /// 사서 바로 쓴다. 가구는 빈 자리에 놓고(자리가 없으면 보관함), 옷·액세서리는 입는다.
  /// 같은 분류 가구가 이미 있어도 교체하지 않고 함께 둔다. 벽지는 하나만이라 교체한다.
  BuyResult buy(ShopItem item) {
    final can = canBuy(item);
    if (can != BuyResult.ok) return can;
    profile.coins -= item.price;
    profile.owned.add(item.id);
    profile.acquired[item.id] = todayKey;
    final used = _use(item);
    _commit();
    sync?.queueBuy(item.id, item.price, item.level);
    return used ? BuyResult.ok : BuyResult.okStored;
  }

  /// 놓기·입기. 방에 자리가 없으면 false.
  bool _use(ShopItem item) {
    switch (item.kind) {
      case ItemKind.outfit:
        profile.outfitId = item.id;
        return true;
      case ItemKind.accessory:
        item.isEarring ? profile.earringId = item.id : profile.accessoryId = item.id;
        return true;
      case ItemKind.furniture:
        final art = manifest[item.id];
        if (art == null) return false;
        final r = room;
        switch (art.layer) {
          case ArtLayer.surface:
            item.slot == RoomSlot.floor ? r.floorSurface = item.id : r.wallSurface = item.id;
            return true;
          case ArtLayer.wall:
            final spot = occupancy.findWallSpot(r, item.id, prefer: r.lastWall[item.id]);
            if (spot == null) return false;
            r.wall[item.id] = spot;
            return true;
          case ArtLayer.object || ArtLayer.floorDecor:
            final spot = occupancy.findFloorSpot(r, item.id, prefer: r.lastFloor[item.id]);
            if (spot == null) return false;
            r.floor[item.id] = spot;
            r.minimi = occupancy.minimiSpot(r, r.minimi);
            return true;
          case ArtLayer.character:
            return false;
        }
    }
  }

  /// 방에 놓기 / 입기. 방에 빈 자리가 없으면 false.
  bool use(ShopItem item) {
    if (!profile.owned.contains(item.id)) return false;
    final ok = _use(item);
    if (ok) _commit();
    return ok;
  }

  /// 보관함으로 넣기 / 벗기. 가구는 마지막 위치를 기억해 다시 놓을 때 먼저 쓴다.
  void putAway(ShopItem item) {
    switch (item.kind) {
      case ItemKind.furniture:
        final r = room;
        if (r.floor.remove(item.id) case final p?) r.lastFloor[item.id] = p;
        if (r.wall.remove(item.id) case final p?) r.lastWall[item.id] = p;
        if (r.wallSurface == item.id) r.wallSurface = null;
        if (r.floorSurface == item.id) r.floorSurface = null;
      case ItemKind.outfit:
        if (profile.outfitId == item.id) profile.outfitId = null;
      case ItemKind.accessory:
        if (profile.accessoryId == item.id) profile.accessoryId = null;
        if (profile.earringId == item.id) profile.earringId = null;
    }
    _commit();
  }

  bool isInUse(ShopItem item) => switch (item.kind) {
    ItemKind.furniture => room.contains(item.id),
    ItemKind.outfit => profile.outfitId == item.id,
    ItemKind.accessory => profile.accessoryId == item.id || profile.earringId == item.id,
  };

  List<ShopItem> get ownedItems => [
    for (final i in shopCatalog) ...[
      if (profile.owned.contains(i.id)) i,
      if (i.isFurniture)
        for (final c in ItemColor.values)
          if (profile.owned.contains('${i.id}~${c.name}')) i.withColor(c),
    ],
  ];

  /// 보관함: 갖고 있지만 쓰지 않는 것
  List<ShopItem> get storedItems => ownedItems.where((i) => !isInUse(i)).toList();

  List<ShopItem> get placedFurniture => room.ids.map(itemById).nonNulls.toList();

  /// 기존 정면 2D 방(대체 그림)용: 자리마다 하나씩. 같은 자리 가구가 여럿이면 먼저 놓인 것.
  Map<RoomSlot, ShopItem> get legacyPlacedView {
    final out = <RoomSlot, ShopItem>{};
    for (final item in placedFurniture) {
      out.putIfAbsent(item.slot!, () => item);
    }
    return out;
  }

  // ───────── 방 꾸미기 (편집 화면) ─────────

  /// 바닥 가구 옮기기·회전. 놓을 수 없으면 그대로 두고 이유를 돌려준다.
  PlaceCheck moveFloor(String id, FloorPos to) {
    final r = room;
    if (!r.floor.containsKey(id)) return const PlaceCheck(PlaceStatus.notPlaceable);
    final c = occupancy.canPlaceFloor(r, id, to);
    if (!c.ok) return c;
    r.floor[id] = to;
    r.minimi = occupancy.minimiSpot(r, r.minimi);
    _commit();
    return c;
  }

  /// 제자리에서 회전. 회전하면 겹치면 그대로 둔다.
  PlaceCheck rotateFloor(String id) {
    final p = room.floor[id];
    if (p == null) return const PlaceCheck(PlaceStatus.notPlaceable);
    // 다음 방향부터 차례로, 놓을 수 있는 첫 방향으로 돌린다
    var last = const PlaceCheck(PlaceStatus.notPlaceable);
    for (var i = 1; i < Rot.values.length; i++) {
      last = moveFloor(id, FloorPos(p.x, p.y, Rot.values[(p.r.index + i) % Rot.values.length]));
      if (last.ok) break;
    }
    return last;
  }

  PlaceCheck moveWall(String id, WallPos to) {
    final r = room;
    if (!r.wall.containsKey(id)) return const PlaceCheck(PlaceStatus.notPlaceable);
    final c = occupancy.canPlaceWall(r, id, to);
    if (!c.ok) return c;
    r.wall[id] = to;
    _commit();
    return c;
  }

  /// 미니미가 설 수 있는 칸인지 (방 안이고 가구가 막지 않은 칸).
  bool canStandAt((int, int) to) => IsoGrid.inRoom(to.$1, to.$2) && !occupancy.tileBlocked(room, to.$1, to.$2);

  /// 미니미 옮기기 (방 꾸미기). 설 수 없는 칸이면 그대로 두고 false.
  bool moveMinimi((int, int) to) {
    if (!canStandAt(to)) return false;
    room.minimi = to;
    _commit();
    return true;
  }

  /// 레벨업으로 새로 열린 아이템.
  List<ShopItem> unlockedAt(int level) => shopCatalog.where((i) => i.level == level).toList();

  // ───────── 기록 통계 ─────────

  /// [from]~[to] (포함) 사이 기록들
  Iterable<DayLog> logsBetween(DateTime from, DateTime to) {
    final a = dateKey(from), b = dateKey(to);
    return logs.values.where((l) => l.date.compareTo(a) >= 0 && l.date.compareTo(b) <= 0);
  }

  /// 기간 안의 루틴별 (완료 수, 예정 수). 이름은 그때의 스냅샷.
  List<({String label, int done, int total})> perRoutine(DateTime from, DateTime to) {
    final done = <String, int>{}, total = <String, int>{}, label = <String, String>{};
    for (final l in logsBetween(from, to)) {
      l.scheduled.forEach((id, name) {
        total[id] = (total[id] ?? 0) + 1;
        label[id] = name;
        if (l.completed.contains(id)) done[id] = (done[id] ?? 0) + 1;
      });
    }
    final out = [for (final id in total.keys) (label: label[id]!, done: done[id] ?? 0, total: total[id]!)];
    out.sort((a, b) => b.done.compareTo(a.done));
    return out;
  }
}
