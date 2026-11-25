import 'package:flutter/material.dart' hide Text;

import '../../app.dart';
import '../../data/friends.dart';
import '../../theme/tokens.dart';
import '../motion.dart';
import '../routine_icon.dart';
import 'friend_widgets.dart';

/// 친구 한 명의 공유 루틴 (PLAN_FRIEND_SHARE_STEP1.md 2-2).
/// 친구를 끊으면 `true` 를 돌려준다.
class FriendRoutinesScreen extends StatefulWidget {
  const FriendRoutinesScreen({super.key, required this.friend});
  final FriendShare friend;

  @override
  State<FriendRoutinesScreen> createState() => _FriendRoutinesScreenState();
}

class _FriendRoutinesScreenState extends State<FriendRoutinesScreen> {
  bool _busy = false;

  /// 이 친구 루틴 중 알림을 켠 것
  late final Set<String> _alarmIds = {...widget.friend.alarmIds};

  Future<void> _toggleAlarm(SharedRoutine r) async {
    final f = widget.friend;
    final owner = f.owner;
    final s = AppScope.read(context);
    final remote = s.sync?.remote;
    if (owner == null || remote == null || _busy) return;
    final on = !_alarmIds.contains(r.id);
    if (on && r.minuteOfDay == null) {
      showAppToast(context, '시간이 정해진 루틴만 알림을 받을 수 있어요');
      return;
    }
    if (on) await s.reminders.requestPermission();
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final res = await remote.setFriendAlarm(owner, r.id, on);
      if (!mounted) return;
      switch (res) {
        case AlarmResult.ok:
          setState(() => on ? _alarmIds.add(r.id) : _alarmIds.remove(r.id));
          final alarm = FriendAlarm(owner: owner, nickname: f.displayName, routine: r);
          s.setFriendAlarms([
            for (final a in s.friendAlarms)
              if (a.key != alarm.key) a,
            if (on) alarm,
          ]);
          if (!on) {
            showAppToast(context, '알림을 껐어요');
          } else if (!s.profile.alarms.allOn) {
            showAppToast(context, '알림 전체 허용이 꺼져 있어 울리지 않아요. 나 → 알림에서 켜 주세요');
          } else {
            showAppToast(context, '${f.displayName}님의 ‘${r.name}’ 시간에 알려 드릴게요');
          }
        case AlarmResult.limit:
          showAppToast(context, '친구 루틴 알림은 $maxFriendAlarms개까지 켤 수 있어요');
        case AlarmResult.notFriend:
          showAppToast(context, friendLoadError);
      }
    } catch (e) {
      debugPrint('friend alarm toggle failed: ${e.runtimeType}');
      if (mounted) showAppToast(context, friendLoadError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unfollow() async {
    final f = widget.friend;
    final owner = f.owner;
    if (owner == null) return;
    final ok = await showAppDialog<bool>(
      context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('${f.displayName}님을 친구에서 뺄까요?'),
        content: const Text('상대에게 알림은 가지 않아요.\n내 루틴에 추가한 루틴은 그대로 남아요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('그대로 둘게요')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('친구 끊기', style: TextStyle(color: AppColors.primaryInk)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final remote = AppScope.read(context).sync?.remote;
    if (remote == null) return;
    setState(() => _busy = true);
    try {
      await remote.unfollow(owner);
      if (!mounted) return;
      // 서버에서는 친구 줄과 함께 알림 고른 것도 지워졌다
      final s = AppScope.read(context);
      s.setFriendAlarms([
        for (final a in s.friendAlarms)
          if (a.owner != owner) a,
      ]);
      showAppToast(context, '친구에서 뺐어요');
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('unfollow failed: ${e.runtimeType}');
      if (mounted) {
        showAppToast(context, friendLoadError);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context); // 내 루틴이 바뀌면 '추가함'을 다시 그린다
    final f = widget.friend;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${f.displayName}님의 루틴'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '더보기',
            enabled: !_busy,
            color: AppColors.surface,
            onSelected: (_) => _unfollow(),
            itemBuilder: (_) => const [PopupMenuItem(value: 'unfollow', child: Text('친구 끊기'))],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xl),
        children: [
          Center(child: FriendMinimi(f.look, width: 80)),
          const SizedBox(height: Space.lg),
          if (f.routines.isEmpty)
            Text('지금은 공유한 루틴이 없어요', style: t.bodySmall, textAlign: TextAlign.center)
          else ...[
            Text('마음에 드는 루틴을 내 루틴에 담아 보세요', style: t.bodySmall),
            const SizedBox(height: Space.sm),
            for (final r in f.routines) ...[
              SharedRoutineTile(
                r,
                added: r.isIn(s.routines),
                onAdd: () => addToMyRoutines(context, r),
                alarmOn: _alarmIds.contains(r.id),
                onAlarm: r.minuteOfDay == null || f.owner == null ? null : () => _toggleAlarm(r),
              ),
              const SizedBox(height: Space.sm),
            ],
            const SizedBox(height: Space.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RoutineIcon('🔔', size: 18),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    '종을 누르면 친구 루틴 시간에 알려 드려요 (모두 합쳐 $maxFriendAlarms개까지). '
                    '친구가 시간을 바꾸면 알림도 따라 바뀌어요.\n'
                    '담은 루틴은 알림이 꺼진 채로 추가되고, 친구가 나중에 바꿔도 그대로예요.',
                    style: t.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
