import 'package:flutter/material.dart';

import '../../app.dart';
import '../../data/friends.dart';
import '../../data/kakao_share.dart';
import '../../data/store.dart';
import '../../data/sync.dart';
import 'friend_preview_screen.dart';
import 'friends_screen.dart';
import 'invite_reward.dart';

/// 받은 초대 코드를 들고 있다가, 로그인·첫 설정이 끝난 홈에서 구경 화면을 연다
/// (PLAN_FRIEND_SHARE_STEP1.md 2-2). 앱이 꺼져도 남도록 기기에 적어 둔다.
class PendingInvite extends ValueNotifier<String?> {
  PendingInvite(this._kv) : super(InviteCode.parse(_kv.read(_key)));

  final KeyValue _kv;

  /// 계정과 무관하게 기기에 하나 (로그인 전에 받을 수 있으므로).
  static const _key = 'pending_friend_code';

  void receive(String code) {
    final c = InviteCode.parse(code);
    if (c == null) return;
    _kv.write(_key, c);
    value = c;
  }

  /// 꺼내면서 비운다 (한 번만 연다).
  String? take() {
    final c = value;
    if (c == null) return null;
    _kv.write(_key, '');
    value = null;
    return c;
  }

  /// 초대 보상 안내를 이 계정에서 이미 마쳤는지 (보여 줬거나, 받았거나, 대상이 아니었거나).
  bool rewardAsked(String uid) => _kv.read('$_askedKey$uid') == 'true';
  void markRewardAsked(String uid) => _kv.write('$_askedKey$uid', 'true');
  static const _askedKey = 'invite_reward_asked_';
}

class InviteScope extends InheritedWidget {
  const InviteScope({super.key, required this.pending, this.invites, required super.child});

  final PendingInvite pending;

  /// 카카오톡 공유. 없으면 카카오톡 버튼을 숨긴다 (테스트·초기화 실패).
  final FriendInvites? invites;

  static InviteScope? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<InviteScope>();

  @override
  bool updateShouldNotify(InviteScope old) => old.pending != pending || old.invites != invites;
}

/// 홈 위에 씌운다. 받은 코드가 있으면 구경 화면을 연다.
class InviteOpener extends StatefulWidget {
  const InviteOpener({super.key, required this.child});
  final Widget child;

  @override
  State<InviteOpener> createState() => _InviteOpenerState();
}

class _InviteOpenerState extends State<InviteOpener> {
  PendingInvite? _pending;
  bool _opening = false;
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = InviteScope.maybeOf(context)?.pending;
    if (p == _pending) return;
    _pending?.removeListener(_check);
    _pending = p?..addListener(_check);
    _check();
    if (!_asked) {
      _asked = true;
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => _askReward())
        ..ensureVisualUpdate();
    }
  }

  String? get _uid => AuthScope.read(context).current?.uid;

  /// 가입 직후 한 번: 초대 보상 대상이면 코드를 묻는다 (3단계).
  /// 카톡 카드로 받은 코드가 이미 있으면 그쪽([_open])에서 받으므로 묻지 않는다.
  Future<void> _askReward() async {
    final uid = _uid, pending = _pending;
    final remote = AppScope.read(context).sync?.remote;
    if (!mounted || uid == null || pending == null || remote == null) return;
    if (pending.rewardAsked(uid) || pending.value != null || _opening) return;
    final bool eligible;
    try {
      eligible = await remote.inviteEligible();
    } catch (e) {
      debugPrint('invite status failed: ${e.runtimeType}');
      return; // 다음에 켤 때 다시
    }
    if (!mounted) return;
    pending.markRewardAsked(uid);
    if (!eligible) return;
    final referrer = await InviteScope.maybeOf(context)?.invites?.installReferrerCode();
    if (!mounted || _opening) return;
    _opening = true;
    try {
      final got = await askInviteCode(context, prefill: referrer);
      if (got != null && mounted) await _rewarded(got.code, got.claim);
    } finally {
      _opening = false;
    }
    if (mounted) _check();
  }

  /// 보상을 받았다: 지갑을 맞추고 축하 창 → 원하면 구경 화면.
  Future<void> _rewarded(String code, InviteClaim claim) async {
    final w = claim.wallet;
    if (w != null) AppScope.read(context).applyWallet(w);
    final view = await showInviteRewardDone(context, claim.gained);
    if (view && mounted) await _preview(code);
  }

  /// 카톡 카드로 받은 코드: 보상 대상이면 먼저 받는다. 받았으면 true.
  Future<bool> _claimIfNew(String code) async {
    final uid = _uid, pending = _pending;
    final remote = AppScope.read(context).sync?.remote;
    if (uid == null || pending == null || remote == null || pending.rewardAsked(uid)) return false;
    try {
      if (!await remote.inviteEligible()) {
        pending.markRewardAsked(uid);
        return false;
      }
      final r = await remote.claimInvite(code);
      pending.markRewardAsked(uid);
      if (r.result != ClaimResult.ok || !mounted) return false;
      await _rewarded(code, r);
      return true;
    } catch (e) {
      debugPrint('invite claim failed: ${e.runtimeType}');
      return false;
    }
  }

  Future<void> _preview(String code) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FriendPreviewScreen(code: code)),
    );
    if (added == true && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FriendsScreen()));
    }
  }

  @override
  void dispose() {
    _pending?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (_opening || _pending?.value == null) return;
    // 그리는 중일 수 있으니 그린 뒤에 연다. 바뀐 게 없으면 다음 프레임이 오지 않으므로 직접 청한다.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _open())
      ..ensureVisualUpdate();
  }

  Future<void> _open() async {
    if (_opening || !mounted) return;
    final code = _pending?.take();
    if (code == null) return;
    _opening = true;
    try {
      // 새 계정이면 보상을 먼저 (축하 창에서 구경 여부를 고른다). 아니면 바로 구경.
      if (!await _claimIfNew(code) && mounted) await _preview(code);
    } finally {
      _opening = false;
    }
    // 열려 있는 사이에 또 받았으면 이어서
    if (mounted) _check();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
