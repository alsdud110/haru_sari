import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'badges.dart';
import 'catalog.dart';
import 'models.dart';
import 'reminders.dart';
import 'rewards.dart';

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

enum BuyResult { ok, alreadyOwned, levelTooLow, notEnoughCoins }

/// 앱 전체 상태. 루틴·하루 기록·프로필(경험치/코인/방/옷/배지)을 저장한다.
class AppState extends ChangeNotifier {
  AppState(this._kv, {DateTime Function()? clock, Reminders? reminders, String initialName = ''})
    : _clock = clock ?? DateTime.now,
      reminders = reminders ?? NoReminders() {
    _load();
    if (profile.name.isEmpty) profile.name = initialName;
  }

  final KeyValue _kv;
  final DateTime Function() _clock;
  final Reminders reminders;

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
  }

  Future<void> _save() async {
    await _kv.write(_kRoutines, jsonEncode(routines.map((e) => e.toJson()).toList()));
    await _kv.write(_kLogs, jsonEncode(logs.map((k, v) => MapEntry(k, v.toJson()))));
    await _kv.write(_kProfile, jsonEncode(profile.toJson()));
    await _kv.write(_kOnboarded, onboarded.toString());
  }

  void _commit({bool resync = false}) {
    _checkBadges();
    notifyListeners();
    _save();
    if (resync) syncReminders();
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

  DailyReward? _maybeReward(DayLog log) {
    if (log.rewarded) return null;
    final r = rewardFor(log.rate);
    if (r == null || log.total == 0) return null;
    log.rewarded = true;
    final lv = addXp(profile.level, profile.xp, r.xp);
    final coins = r.coins + lv.levelsGained * RewardRules.levelUpCoins;
    profile
      ..level = lv.level
      ..xp = lv.xp
      ..totalXp += r.xp
      ..coins += coins;
    log
      ..rewardXp = r.xp
      ..rewardCoins = coins;
    return DailyReward(xp: r.xp, coins: coins, perfect: r.perfect, levelsGained: lv.levelsGained, newLevel: lv.level);
  }

  /// 오늘 이미 받은 보상 (다시 보기용)
  DailyReward? get todayReward {
    final l = todayLog;
    if (!l.rewarded) return null;
    return DailyReward(
      xp: l.rewardXp,
      coins: l.rewardCoins,
      perfect: l.done == l.total,
      levelsGained: 0,
      newLevel: profile.level,
    );
  }

  // ───────── 상점·방·옷 ─────────

  BuyResult canBuy(ShopItem item) {
    if (profile.owned.contains(item.id)) return BuyResult.alreadyOwned;
    if (profile.level < item.level) return BuyResult.levelTooLow;
    if (profile.coins < item.price) return BuyResult.notEnoughCoins;
    return BuyResult.ok;
  }

  /// 사서 바로 쓴다(가구는 그 자리에 놓고, 옷은 입는다). 원래 것은 보관함으로 간다.
  BuyResult buy(ShopItem item) {
    final can = canBuy(item);
    if (can != BuyResult.ok) return can;
    profile.coins -= item.price;
    profile.owned.add(item.id);
    profile.acquired[item.id] = todayKey;
    _use(item);
    _commit();
    return BuyResult.ok;
  }

  void _use(ShopItem item) {
    switch (item.kind) {
      case ItemKind.furniture:
        profile.placed[item.slot!.name] = item.id;
      case ItemKind.outfit:
        profile.outfitId = item.id;
      case ItemKind.accessory:
        profile.accessoryId = item.id;
    }
  }

  /// 방에 놓기 / 입기
  void use(ShopItem item) {
    if (!profile.owned.contains(item.id)) return;
    _use(item);
    _commit();
  }

  /// 보관함으로 넣기 / 벗기
  void putAway(ShopItem item) {
    switch (item.kind) {
      case ItemKind.furniture:
        if (profile.placed[item.slot!.name] == item.id) profile.placed.remove(item.slot!.name);
      case ItemKind.outfit:
        if (profile.outfitId == item.id) profile.outfitId = null;
      case ItemKind.accessory:
        if (profile.accessoryId == item.id) profile.accessoryId = null;
    }
    _commit();
  }

  bool isInUse(ShopItem item) => switch (item.kind) {
    ItemKind.furniture => profile.placed[item.slot!.name] == item.id,
    ItemKind.outfit => profile.outfitId == item.id,
    ItemKind.accessory => profile.accessoryId == item.id,
  };

  List<ShopItem> get ownedItems => shopCatalog.where((i) => profile.owned.contains(i.id)).toList();

  /// 보관함: 갖고 있지만 쓰지 않는 것
  List<ShopItem> get storedItems => ownedItems.where((i) => !isInUse(i)).toList();

  List<ShopItem> get placedFurniture => profile.placed.values.map(itemById).nonNulls.toList();

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
