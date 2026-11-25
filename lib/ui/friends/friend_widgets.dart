import 'package:flutter/material.dart' hide Text;

import '../../app.dart';
import '../../data/friends.dart';
import '../../theme/tokens.dart';
import '../motion.dart';
import '../room/room_painter.dart' show MinimiView;
import '../routine_icon.dart';
import '../widgets.dart';

/// 친구 화면들이 같이 쓰는 조각.

/// 친구 미니미.
class FriendMinimi extends StatelessWidget {
  const FriendMinimi(this.look, {super.key, this.width = 64});
  final SharedLook look;
  final double width;

  @override
  Widget build(BuildContext context) => MinimiView(profile: look.toProfile(), width: width);
}

/// 친구가 공유한 루틴 한 줄. [onAdd] 가 있으면 '내 루틴에 추가' 버튼을 단다.
class SharedRoutineTile extends StatelessWidget {
  const SharedRoutineTile(this.r, {super.key, this.onAdd, this.added = false, this.onAlarm, this.alarmOn = false});
  final SharedRoutine r;
  final VoidCallback? onAdd;
  final bool added;

  /// 있으면 🔔 버튼을 단다 (친구 루틴 알림, 2단계)
  final VoidCallback? onAlarm;
  final bool alarmOn;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Panel(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.xs, Space.sm),
      child: Row(
        children: [
          RoutineIcon(r.emoji),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, style: t.titleMedium),
                Text('${weekdaySummary(r.weekdays.toSet())} ${formatMinute(r.minuteOfDay)}', style: t.bodySmall),
              ],
            ),
          ),
          if (onAlarm != null)
            IconButton(
              tooltip: alarmOn ? '${r.name} 알림 끄기' : '${r.name} 알림 받기',
              onPressed: onAlarm,
              // 꺼짐: 흐린 종, 켜짐: 흔들리는 종 (assets/icons/bell*.png)
              icon: Opacity(
                opacity: alarmOn ? 1 : 0.45,
                child: Image.asset(
                  bellAsset(ringing: alarmOn),
                  width: 26,
                  height: 26,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          if (onAdd != null)
            added
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('추가함', style: t.bodySmall),
                        const SizedBox(width: 4),
                        const RoutineIcon('✔', size: 16),
                      ],
                    ),
                  )
                : TextButton(onPressed: onAdd, child: const Text('내 루틴에 추가')),
        ],
      ),
    );
  }
}

/// 친구 루틴을 내 루틴으로 복사한다.
void addToMyRoutines(BuildContext context, SharedRoutine r) {
  final s = AppScope.read(context);
  if (r.isIn(s.routines)) {
    showAppToast(context, '이미 내 루틴에 있어요');
    return;
  }
  s.upsertRoutine(r.toMyRoutine(s.newId()));
  showAppToast(context, '내 루틴에 추가했어요');
}

/// 친구 화면의 일반 오류 문구 (자세한 건 로그에만).
const friendLoadError = '지금은 불러오지 못했어요. 잠시 후 다시 해 주세요';
