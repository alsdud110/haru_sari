import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'store.dart';

/// 서버의 레벨·경험치·코인. 서버 값이 기준이다.
class Wallet {
  const Wallet({required this.level, required this.xp, required this.totalXp, required this.coins});
  final int level;
  final int xp;
  final int totalXp;
  final int coins;

  factory Wallet.fromRow(Map<String, dynamic> r) =>
      Wallet(level: r['level'] as int, xp: r['xp'] as int, totalXp: r['total_xp'] as int, coins: r['coins'] as int);
}

/// 서버에서 내려받은 한 사용자의 전부.
class RemoteSnapshot {
  const RemoteSnapshot({
    required this.state,
    required this.stateAt,
    required this.logs,
    required this.wallet,
    required this.purchases,
    required this.hasGrants,
  });

  /// user_state 의 nickname·onboarded·routines·profile (없으면 null)
  final Map<String, dynamic>? state;
  final DateTime? stateAt;

  /// 날짜 → (기록 JSON, 서버 저장 시각)
  final Map<String, ({Map<String, dynamic> data, DateTime at})> logs;
  final Wallet? wallet;
  final Set<String> purchases;

  /// 보상 지급 내역이 하나라도 있는지 (첫 동기화에서 기존 기록을 올릴지 판단)
  final bool hasGrants;
}

class BuyReply {
  const BuyReply({required this.ok, this.reason, required this.wallet});
  final bool ok;
  final String? reason;
  final Wallet wallet;
}

/// 광고 보상 요청의 답. [used]는 그날 서버가 지급한 횟수(이번 것 포함).
class AdReply {
  const AdReply({required this.ok, required this.used, required this.wallet});
  final bool ok;
  final int used;
  final Wallet wallet;
}

/// 서버가 요청을 받았지만 처리하지 못했다 (함수가 없거나 값이 맞지 않음). 다시 보내도 같으므로 버린다.
/// 연결이 끊긴 것과는 다르다 — 그때는 다른 예외가 나고, 요청을 남겨 두었다가 다시 보낸다.
class RemoteRejected implements Exception {
  const RemoteRejected(this.message);
  final String message;
  @override
  String toString() => 'RemoteRejected: $message';
}

/// 서버 접근. 실제는 SupabaseRemote, 테스트는 가짜를 쓴다.
abstract class Remote {
  Future<RemoteSnapshot> pull();
  Future<void> pushState({
    required String nickname,
    required bool onboarded,
    required List<dynamic> routines,
    required Map<String, dynamic> profile,
    required DateTime at,
  });
  Future<void> pushLogs(Map<String, ({Map<String, dynamic> data, DateTime at})> logs);
  Future<({int gainedXp, int gainedCoins, Wallet wallet})> claim(String day, int done, int total);
  Future<BuyReply> buy(String itemId, int price, int minLevel);

  /// 광고를 끝까지 본 보상. 하루 횟수를 넘으면 ok=false 로 지갑만 돌려준다.
  Future<AdReply> adReward(String day);
}

/// 기기 ↔ 서버 동기화.
///
/// - 앱은 늘 기기에 먼저 저장하고(오프라인에서도 동작), 바뀐 것을 서버에 올린다.
/// - 루틴·방·설정은 나중에 고친 쪽이 이긴다 (저장 시각 비교).
/// - 날짜별 기록은 날짜마다 나중에 고친 쪽이 이긴다.
/// - 레벨·경험치·코인은 서버가 기준이다. 보상 받기·사기는 서버 함수로 보내고,
///   서버가 돌려준 값으로 기기 값을 맞춘다. 보내지 못한 요청은 기기에 쌓아 두었다가 다시 보낸다.
class SyncEngine {
  SyncEngine(this._s, this._remote, this._kv, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppState _s;
  final Remote _remote;
  final KeyValue _kv;
  final DateTime Function() _clock;

  static const _kPending = 'sync/pending';
  static const _kStateAt = 'sync/stateAt';
  static const _kLogsAt = 'sync/logsAt';
  static const _kDirty = 'sync/dirty';

  /// 서버에서 처음 받아오는 중 (새 기기에서 첫 설정 화면을 잠깐 미룬다)
  final ValueNotifier<bool> pulling = ValueNotifier(false);

  bool _disposed = false;
  Future<void>? _running;
  bool _again = false;

  List<Map<String, dynamic>> get _pending =>
      ((jsonDecode(_kv.read(_kPending) ?? '[]') as List).cast<Map>()).map((e) => e.cast<String, dynamic>()).toList();
  void _setPending(List<Map<String, dynamic>> v) => _kv.write(_kPending, jsonEncode(v));

  DateTime? get _stateAt => DateTime.tryParse(_kv.read(_kStateAt) ?? '');
  Map<String, String> get _logsAt => ((jsonDecode(_kv.read(_kLogsAt) ?? '{}') as Map).cast<String, String>());

  /// 올려야 할 것: 'state' 와 날짜들
  Set<String> get _dirty => ((jsonDecode(_kv.read(_kDirty) ?? '[]') as List).cast<String>()).toSet();
  void _setDirty(Set<String> v) => _kv.write(_kDirty, jsonEncode(v.toList()));

  // ───────── 앱이 부르는 것 ─────────

  /// 로컬에서 무언가 바뀌었다. 상태와 [day] 기록을 올린다.
  void changed({String? day}) {
    final now = _clock().toUtc().toIso8601String();
    _kv.write(_kStateAt, now);
    final d = _dirty..add('state');
    if (day != null) {
      d.add(day);
      _kv.write(_kLogsAt, jsonEncode(_logsAt..[day] = now));
    }
    _setDirty(d);
    _kick();
  }

  void queueClaim(String day, int done, int total) {
    _setPending([
      ..._pending,
      {'op': 'claim', 'day': day, 'done': done, 'total': total},
    ]);
    _kick();
  }

  void queueBuy(String itemId, int price, int minLevel) {
    _setPending([
      ..._pending,
      {'op': 'buy', 'item': itemId, 'price': price, 'level': minLevel},
    ]);
    _kick();
  }

  void queueAd(String day) {
    _setPending([
      ..._pending,
      {'op': 'ad', 'day': day},
    ]);
    _kick();
  }

  /// 로그인·앱 시작 때: 서버에서 받아 합치고, 남은 것을 올린다.
  Future<void> start() async {
    pulling.value = true;
    try {
      final snap = await _remote.pull();
      if (_disposed) return;
      _merge(snap);
    } catch (e) {
      debugPrint('sync pull failed: $e');
    } finally {
      if (!_disposed) pulling.value = false;
    }
    await flush();
  }

  /// 쌓인 요청과 바뀐 것을 서버에 올린다. 실패하면 다음 기회에 다시 한다.
  Future<void> flush() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _flush().whenComplete(() {
      _running = null;
      if (_again && !_disposed) {
        _again = false;
        flush();
      }
    });
  }

  void _kick() {
    if (!_disposed) flush();
  }

  void dispose() {
    _disposed = true;
    pulling.dispose();
  }

  // ───────── 내부 ─────────

  Future<void> _flush() async {
    try {
      // 1) 보상·구매 요청을 순서대로
      Wallet? last;
      while (!_disposed) {
        final ops = _pending;
        if (ops.isEmpty) break;
        final op = ops.first;
        switch (op['op']) {
          case 'claim':
            last = (await _remote.claim(op['day'] as String, op['done'] as int, op['total'] as int)).wallet;
          case 'buy':
            final r = await _remote.buy(op['item'] as String, op['price'] as int, op['level'] as int);
            last = r.wallet;
            // 다른 기기에서 코인을 먼저 써서 서버가 거절하면 이 기기의 구매를 되돌린다.
            // (첫 동기화로 다시 보내는 예전 구매는 되돌리지 않는다)
            if (!r.ok && r.reason != 'already_owned' && op['seed'] != true) _s.revertPurchase(op['item'] as String);
          case 'ad':
            // 다른 기기에서 이미 다 봤으면 서버가 거절한다 → 서버 지갑과 횟수로 맞춘다.
            try {
              final r = await _remote.adReward(op['day'] as String);
              last = r.wallet;
              _s.applyAdCount(op['day'] as String, r.used);
            } on RemoteRejected catch (e) {
              debugPrint('ad reward dropped: $e');
            }
        }
        _setPending(_pending..removeAt(0));
      }
      if (_disposed) return;
      if (last != null && _pending.isEmpty) _s.applyWallet(last);

      // 2) 바뀐 상태와 기록
      final dirty = _dirty;
      if (dirty.isEmpty) return;
      if (dirty.contains('state')) {
        await _remote.pushState(
          nickname: _s.profile.name,
          onboarded: _s.onboarded,
          routines: _s.routines.map((e) => e.toJson()).toList(),
          profile: profileForServer(_s.profile.toJson()),
          at: _stateAt ?? _clock().toUtc(),
        );
      }
      final days = dirty.where((d) => d != 'state' && _s.logs.containsKey(d)).toList();
      if (days.isNotEmpty) {
        final at = _logsAt;
        await _remote.pushLogs({
          for (final d in days) d: (data: _s.logs[d]!.toJson(), at: DateTime.tryParse(at[d] ?? '') ?? _clock().toUtc()),
        });
      }
      if (_disposed) return;
      _setDirty(_dirty..removeAll(dirty));
    } catch (e) {
      // 오프라인 등. 요청과 표시는 그대로 두고 다음에 다시 보낸다.
      debugPrint('sync flush failed: $e');
    }
  }

  /// 서버 지갑 값은 올리지 않는다 (서버 함수만 바꾼다).
  static Map<String, dynamic> profileForServer(Map<String, dynamic> p) =>
      Map.of(p)..removeWhere((k, _) => const {'xp', 'totalXp', 'level', 'coins'}.contains(k));

  void _merge(RemoteSnapshot snap) {
    final dirty = _dirty;
    final localAt = _stateAt;

    // 상태: 서버가 첫 설정을 마쳤고, 기기에 고친 적이 없거나 서버가 더 최근이면 서버를 따른다.
    final st = snap.state;
    final serverReady = st != null && st['onboarded'] == true;
    final takeServer =
        serverReady && (localAt == null || !_s.onboarded || (snap.stateAt != null && snap.stateAt!.isAfter(localAt)));
    if (takeServer) {
      _s.applyRemoteState(
        nickname: st['nickname'] as String? ?? '',
        routines: (st['routines'] as List?) ?? const [],
        profile: ((st['profile'] as Map?) ?? const {}).cast<String, dynamic>(),
      );
      if (snap.stateAt != null) _kv.write(_kStateAt, snap.stateAt!.toUtc().toIso8601String());
      dirty.remove('state');
    } else if (_s.onboarded) {
      dirty.add('state');
    }

    // 기록: 날짜마다 나중 것
    final at = _logsAt;
    final taken = <String, Map<String, dynamic>>{};
    snap.logs.forEach((day, v) {
      final mine = DateTime.tryParse(at[day] ?? '');
      if (!_s.logs.containsKey(day) || mine == null || v.at.isAfter(mine)) {
        taken[day] = v.data;
        at[day] = v.at.toUtc().toIso8601String();
        dirty.remove(day);
      }
    });
    for (final day in _s.logs.keys) {
      if (!snap.logs.containsKey(day) && !taken.containsKey(day)) dirty.add(day);
    }
    if (taken.isNotEmpty) _s.applyRemoteLogs(taken);
    _kv.write(_kLogsAt, jsonEncode(at));

    // 산 물건: 양쪽을 합친다
    _s.addOwned(snap.purchases);

    // 서버에 아직 보상·구매 기록이 없는데 이 기기에는 있으면 (동기화 전부터 쓰던 기기)
    // 기록을 다시 보내 서버 지갑을 만든다. 같은 날짜·같은 물건은 서버가 한 번만 받는다.
    // 같은 날은 보상을 먼저 받고 산 것으로 본다.
    final seed = <({String at, Map<String, dynamic> op})>[];
    if (!snap.hasGrants && snap.purchases.isEmpty && _pending.isEmpty) {
      for (final l in _s.logs.values.where((l) => l.rewarded)) {
        seed.add((
          at: '${l.date} 0',
          op: {'op': 'claim', 'day': l.date, 'done': l.done, 'total': l.total, 'seed': true},
        ));
      }
      for (final id in _s.profile.owned) {
        final item = _s.itemById(id);
        if (item == null) continue;
        seed.add((
          at: '${_s.profile.acquired[id] ?? '9999'} 1',
          op: {'op': 'buy', 'item': id, 'price': item.price, 'level': item.level, 'seed': true},
        ));
      }
      seed.sort((a, b) => a.at.compareTo(b.at));
    }
    if (seed.isNotEmpty) {
      _setPending([for (final s in seed) s.op]);
    } else if (snap.wallet != null && _pending.isEmpty) {
      _s.applyWallet(snap.wallet!);
    }
    _setDirty(dirty);
  }
}
