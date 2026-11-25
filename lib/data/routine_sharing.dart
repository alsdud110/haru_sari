import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'friends.dart';
import 'store.dart';
import 'sync.dart';

/// 내 루틴 공유 상태 (PLAN_FRIEND_SHARE_STEP1.md 2-1).
///
/// - 서버의 내 공유 줄이 기준이다. 기기에는 코드·고른 루틴·마지막으로 올린 내용을 적어 두어
///   오프라인에서도 화면을 그리고, 바뀐 게 있으면 다음에 연결될 때 올린다.
/// - 공유 중에 공유한 루틴을 고치거나 지우면, 닉네임·미니미를 바꾸면 잠시 뒤 서버 스냅숏을 다시 올린다.
class RoutineSharing extends ChangeNotifier {
  RoutineSharing(this._s, this._remote, this._kv, {this.debounce = const Duration(seconds: 2)}) {
    _code = InviteCode.parse(_kv.read(_kCode));
    final ids = _kv.read(_kIds);
    if (ids != null) {
      try {
        _ids = {
          for (final e in jsonDecode(ids) as List)
            if (e is String) e,
        };
      } catch (_) {}
    }
    _sent = _kv.read(_kSent);
    _s.addListener(_onState);
  }

  final AppState _s;
  final Remote _remote;
  final KeyValue _kv;
  final Duration debounce;

  static const _kCode = 'share_code';
  static const _kIds = 'share_ids';
  static const _kSent = 'share_sent';

  /// 한 번에 공유할 수 있는 루틴 수 (서버와 같다).
  static const maxRoutines = 30;

  String? _code;
  Set<String> _ids = {};
  String? _sent;
  Timer? _timer;
  bool _pushing = false;
  bool _disposed = false;

  /// 공유 중이면 초대 코드.
  String? get code => _code;
  bool get isOn => _code != null;

  /// 공유하는 루틴 id (지금 있는 루틴만).
  Set<String> get ids => {
    for (final r in _s.routines)
      if (_ids.contains(r.id)) r.id,
  };

  /// 서버에 올릴 스냅숏 (루틴 목록 순서대로).
  List<SharedRoutine> snapshotFor(Set<String> ids) => [
    for (final r in _s.sortedRoutines)
      if (ids.contains(r.id)) SharedRoutine.fromRoutine(r),
  ];

  String _signature(Set<String> ids) => jsonEncode({
    'n': _s.profile.name,
    'l': SharedLook.fromProfile(_s.profile).toJson(),
    'r': [for (final r in snapshotFor(ids)) r.toJson()],
  });

  /// 바뀌어서 아직 서버에 올리지 못한 게 있는지.
  bool get dirty => isOn && _signature(ids) != _sent;

  /// 서버의 내 공유 줄로 맞춘다 (다른 기기에서 바꿨거나 멈췄을 수 있다).
  Future<void> refresh() async {
    final mine = await _remote.myRoutineShare();
    if (mine == null) {
      await _setLocal(code: null, ids: {}, sent: null);
    } else {
      final same = mine.code == _code && setEquals(mine.routineIds, _ids);
      await _setLocal(code: mine.code, ids: mine.routineIds, sent: same ? _sent : null);
      if (dirty) _schedule();
    }
  }

  /// [ids] 를 공유한다. 처음이면 서버가 코드를 만든다. 코드를 돌려준다.
  Future<String> share(Set<String> ids) async {
    final picked = ids.take(maxRoutines).toSet();
    final sig = _signature(picked);
    final code = await _remote.saveRoutineShare(
      nickname: _s.profile.name,
      look: SharedLook.fromProfile(_s.profile),
      routines: snapshotFor(picked),
    );
    _timer?.cancel();
    await _setLocal(code: code, ids: picked, sent: sig);
    return code;
  }

  /// 공유 중에 고른 루틴을 바꾼다. 잠시 뒤 서버에 올린다.
  Future<void> setIds(Set<String> ids) async {
    await _setLocal(code: _code, ids: ids.take(maxRoutines).toSet(), sent: _sent);
    if (dirty) _schedule();
  }

  /// 공유를 멈춘다. 코드가 사라지고 친구 관계도 끊긴다.
  Future<void> stop() async {
    _timer?.cancel();
    await _remote.stopRoutineShare();
    await _setLocal(code: null, ids: {}, sent: null);
  }

  /// 못 올린 게 있으면 지금 올린다 (앱을 켤 때·돌아올 때).
  Future<void> flush() async {
    _timer?.cancel();
    if (!dirty || _pushing || _disposed) return;
    _pushing = true;
    final current = ids;
    final sig = _signature(current);
    var ok = false;
    try {
      await _remote.saveRoutineShare(
        nickname: _s.profile.name,
        look: SharedLook.fromProfile(_s.profile),
        routines: snapshotFor(current),
      );
      ok = true;
      if (!_disposed) await _setLocal(code: _code, ids: _ids, sent: sig);
    } catch (e) {
      // 바로 다시 하지 않는다 (오프라인에서 계속 두드리지 않게). 다음 변경·앱 복귀·다음 실행 때 다시.
      debugPrint('routine share push failed: ${e.runtimeType}');
    } finally {
      _pushing = false;
    }
    // 올리는 사이에 또 바뀌었으면 한 번 더
    if (ok && dirty && !_disposed) _schedule();
  }

  void _onState() {
    if (!isOn || _disposed) return;
    if (dirty) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  Future<void> _setLocal({required String? code, required Set<String> ids, required String? sent}) async {
    final changed = code != _code || !setEquals(ids, _ids);
    _code = code;
    _ids = ids;
    _sent = sent;
    if (code == null) {
      await _kv.write(_kCode, '');
      await _kv.write(_kIds, '[]');
      await _kv.write(_kSent, '');
    } else {
      await _kv.write(_kCode, code);
      await _kv.write(_kIds, jsonEncode(ids.toList()..sort()));
      await _kv.write(_kSent, sent ?? '');
    }
    if (changed && !_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _s.removeListener(_onState);
    super.dispose();
  }
}
