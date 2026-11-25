import 'package:flutter/material.dart' hide Text;

import '../../app.dart';
import '../../data/friends.dart';
import '../../theme/tokens.dart';
import '../motion.dart';
import '../widgets.dart';
import 'friend_widgets.dart';
import 'friends_screen.dart' show askFriendCode;

/// 코드로 받은 루틴 구경 (PLAN_FRIEND_SHARE_STEP1.md 2-2).
/// 친구를 추가했거나 이미 친구면 `true` 를 돌려준다 (부른 쪽이 친구 목록을 새로 받는다).
class FriendPreviewScreen extends StatefulWidget {
  const FriendPreviewScreen({super.key, required this.code});

  /// [InviteCode.parse] 를 거친 8자.
  final String code;

  @override
  State<FriendPreviewScreen> createState() => _FriendPreviewScreenState();
}

class _FriendPreviewScreenState extends State<FriendPreviewScreen> {
  /// 지금 보는 코드 ("다른 코드 넣기"로 바뀔 수 있다)
  late String _code = widget.code;
  ShareLookup? _result;
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _result = null;
    });
    final remote = AppScope.read(context).sync?.remote;
    try {
      if (remote == null) throw StateError('no remote');
      final r = await remote.lookupShare(_code);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      debugPrint('share lookup failed (${InviteCode.masked(_code)}): ${e.runtimeType}');
      if (mounted) setState(() => _failed = true);
    }
  }

  /// 코드가 맞지 않을 때: 다시 넣으면 같은 화면에서 새 코드로 다시 불러온다.
  Future<void> _retry() async {
    final code = await askFriendCode(context);
    if (code == null || !mounted) return;
    _code = code;
    _load();
  }

  Future<void> _follow() async {
    final remote = AppScope.read(context).sync?.remote;
    if (remote == null) return;
    setState(() => _busy = true);
    try {
      final r = await remote.follow(_code);
      if (!mounted) return;
      switch (r) {
        case FollowResult.ok:
          showAppToast(context, '친구로 추가했어요');
          Navigator.pop(context, true);
        case FollowResult.limit:
          showAppToast(context, '친구는 $maxFriends명까지 추가할 수 있어요');
        case FollowResult.self:
          showAppToast(context, '내가 공유한 코드예요');
        case FollowResult.notFound:
          showAppToast(context, '공유가 끝났거나 코드가 맞지 않아요');
      }
    } catch (e) {
      debugPrint('follow failed: ${e.runtimeType}');
      if (mounted) showAppToast(context, friendLoadError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('친구 루틴 구경')),
      body: _failed
          ? Center(
              child: EmptyHint(
                emoji: '💬',
                title: '불러오지 못했어요',
                body: friendLoadError,
                action: OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
              ),
            )
          : r == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : switch (r.status) {
              LookupStatus.limited => const Center(
                child: EmptyHint(
                  emoji: '🌙',
                  title: '잠시 후 다시 해 주세요',
                  body: '코드를 너무 여러 번 확인했어요.\n내일 다시 해 주세요.',
                ),
              ),
              LookupStatus.notFound => Center(
                child: EmptyHint(
                  emoji: '📭',
                  title: '공유가 끝났거나 코드가 맞지 않아요',
                  body: '친구에게 코드를 다시 받아 주세요',
                  action: OutlinedButton(onPressed: _retry, child: const Text('다른 코드 넣기')),
                ),
              ),
              LookupStatus.ok => _found(r),
            },
    );
  }

  Widget _found(ShareLookup r) {
    final share = r.share!;
    final t = Theme.of(context).textTheme;
    final name = share.displayName;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xl),
      children: [
        Center(child: FriendMinimi(share.look, width: 88)),
        const SizedBox(height: Space.md),
        Text(
          r.isMe ? '내가 공유한 루틴이에요' : '$name님이 루틴을 공유했어요',
          style: t.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.lg),
        if (share.routines.isEmpty)
          Text('지금은 공유한 루틴이 없어요', style: t.bodySmall, textAlign: TextAlign.center)
        else
          for (final s in share.routines) ...[SharedRoutineTile(s), const SizedBox(height: Space.sm)],
        const SizedBox(height: Space.lg),
        if (r.isMe)
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))
        else if (r.following)
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('친구 루틴 보기'))
        else ...[
          FilledButton(
            onPressed: _busy ? null : _follow,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('친구 추가'),
          ),
          const SizedBox(height: Space.sm),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
        ],
      ],
    );
  }
}
