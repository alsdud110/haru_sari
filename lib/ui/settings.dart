import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../app.dart';
import '../data/auth.dart';
import '../data/badges.dart';
import '../theme/tokens.dart';
import 'motion.dart';
import 'auth_screens.dart';
import 'onboarding.dart';
import 'room/room_painter.dart';
import 'routines.dart';
import 'widgets.dart';

/// '나' 탭: 프로필·설정
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final auth = AuthScope.of(context);
    final p = s.profile;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('나')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: const BoxDecoration(color: AppColors.surfaceMuted, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(Space.sm),
                      child: MinimiView(profile: p, width: 48),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name.isEmpty ? '나' : p.name, style: t.titleLarge),
                          Text('Lv.${p.level} · 누적 ${p.totalXp} XP', style: t.bodySmall),
                        ],
                      ),
                    ),
                    const CoinChip(),
                  ],
                ),
                const SizedBox(height: Space.lg),
                const XpBar(),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),
          _Section('기록과 꾸미기', [
            _Tile(
              icon: Icons.checklist_rounded,
              title: '내 루틴 관리',
              subtitle: '${s.routines.length}개 · 카테고리·요일·알림',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutineManageScreen())),
            ),
            _Tile(
              icon: Icons.military_tech_outlined,
              title: '받은 배지',
              subtitle: '${p.badges.length} / ${badgeDefs.length}',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen())),
            ),
            _Tile(
              icon: Icons.palette_outlined,
              title: '미니미 색 바꾸기',
              subtitle: '피부·머리·옷 색',
              onTap: () => _editMinimi(context),
            ),
          ]),
          const SizedBox(height: Space.lg),
          _Section('알림', [
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
              title: Text('알림 전체 허용', style: t.titleMedium),
              subtitle: Text('앱의 모든 알림을 켜거나 꺼요', style: t.bodySmall),
              value: p.alarms.allOn,
              activeThumbColor: AppColors.primary,
              onChanged: (v) async {
                if (v) await s.reminders.requestPermission();
                s.updateAlarms(p.alarms..allOn = v);
              },
            ),
            _Tile(
              icon: Icons.tune_rounded,
              title: '알림 상세 설정',
              subtitle: '루틴 시작 · 하루 마감',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlarmSettingsScreen())),
            ),
          ]),
          const SizedBox(height: Space.lg),
          _Section('계정', [
            _Tile(
              icon: Icons.badge_outlined,
              title: '계정 정보',
              subtitle: accountLabel(auth.current),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
            ),
            _Tile(
              icon: Icons.logout_rounded,
              title: '로그아웃',
              subtitle: '기록은 이 기기에 남아요',
              onTap: () => confirmLogout(context),
            ),
          ]),
          const SizedBox(height: Space.xl),
          Text('루틴을 놓친 날에도 경험치·코인·가구는 그대로예요.\n다시 시작하는 날이 곧 좋은 날이에요.', style: t.bodySmall, textAlign: TextAlign.center),
          if (kDebugMode) ...[
            const SizedBox(height: Space.lg),
            TextButton(onPressed: () => _confirmReset(context, auth), child: const Text('초기화 (개발용)')),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, AuthService auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('전부 초기화할까요?'),
        content: const Text('이 기기의 모든 계정과 기록이 지워지고 첫 화면으로 돌아가요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('초기화')),
        ],
      ),
    );
    if (ok == true) await auth.debugReset();
  }

  void _editMinimi(BuildContext context) {
    showAppSheet<void>(
      context,
      isScrollControlled: false,
      builder: (ctx) {
        final s = AppScope.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MinimiView(profile: s.profile),
                const SizedBox(height: Space.lg),
                Flexible(
                  child: SingleChildScrollView(
                    child: MinimiPicker(minimi: s.profile.minimi, onChanged: s.updateMinimi),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: Space.xs, bottom: Space.sm),
        child: Text(title, style: Theme.of(context).textTheme.bodySmall),
      ),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.line),
              children[i],
            ],
          ],
        ),
      ),
    ],
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 64,
    leading: Icon(icon, color: AppColors.primary),
    title: Text(title, style: Theme.of(context).textTheme.titleMedium),
    subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    trailing: isApple
        ? const Icon(CupertinoIcons.chevron_forward, size: 16, color: AppColors.textMuted)
        : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
    onTap: onTap,
  );
}

/// 알림 상세 설정. 미완료를 재촉하는 알림은 두지 않는다 (PRD 원칙).
class AlarmSettingsScreen extends StatelessWidget {
  const AlarmSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final a = s.profile.alarms;
    final t = Theme.of(context).textTheme;
    final timed = s.sortedRoutines.where((r) => r.minuteOfDay != null).toList();
    final enabled = a.allOn;

    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
        children: [
          Text('원하는 시간에만, 살며시 알려드려요.', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: Panel(
                color: AppColors.coinSoft,
                child: Row(
                  children: [
                    const Expanded(child: Text('알림 전체가 꺼져 있어요.')),
                    TextButton(
                      onPressed: () async {
                        await s.reminders.requestPermission();
                        s.updateAlarms(a..allOn = true);
                      },
                      child: const Text('켜기'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Space.lg),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('루틴 시작 알림'),
                  subtitle: const Text('루틴마다 정해 둔 시간에 알려드려요'),
                  value: a.routineStart,
                  activeThumbColor: AppColors.primary,
                  onChanged: enabled ? (v) => s.updateAlarms(a..routineStart = v) : null,
                ),
                const Divider(height: 1, color: AppColors.line),
                SwitchListTile.adaptive(
                  title: const Text('하루 마감 알림'),
                  subtitle: const Text('오늘 하루를 돌아볼 시간을 알려드려요'),
                  value: a.dayEnd,
                  activeThumbColor: AppColors.primary,
                  onChanged: enabled ? (v) => s.updateAlarms(a..dayEnd = v) : null,
                ),
                ListTile(
                  enabled: enabled && a.dayEnd,
                  title: const Text('하루 마감 알림 시간'),
                  trailing: Text(formatMinute(a.dayEndMinute), style: t.labelLarge),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: a.dayEndMinute ~/ 60, minute: a.dayEndMinute % 60),
                    );
                    if (picked != null) s.updateAlarms(a..dayEndMinute = picked.hour * 60 + picked.minute);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          Text('루틴별 알림', style: t.titleMedium),
          const SizedBox(height: Space.sm),
          if (timed.isEmpty)
            Text('시간을 정해 둔 루틴이 없어요. 루틴 편집에서 시간을 정하면 알림을 켤 수 있어요.', style: t.bodySmall)
          else
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < timed.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.line),
                    SwitchListTile.adaptive(
                      title: Text('${timed[i].emoji} ${timed[i].name}'),
                      subtitle: Text(
                        '${weekdaySummary(timed[i].weekdays)} ${formatMinute(timed[i].minuteOfDay)}'
                        '${timed[i].active ? '' : ' · 쉬는 중'}',
                      ),
                      value: timed[i].alarmOn,
                      activeThumbColor: AppColors.primary,
                      onChanged: enabled && a.routineStart
                          ? (v) => s.upsertRoutine(timed[i].copy()..alarmOn = v)
                          : null,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).profile;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('받은 배지')),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: Space.sm,
          crossAxisSpacing: Space.sm,
          // 칸 높이는 글자 크기를 따라간다 (비율로 잡으면 좁은 화면·큰 글씨에서 넘친다)
          mainAxisExtent: MediaQuery.textScalerOf(context).scale(176),
        ),
        itemCount: badgeDefs.length,
        itemBuilder: (context, i) {
          final b = badgeDefs[i];
          final got = p.badges[b.id];
          return Panel(
            color: got != null ? AppColors.surface : AppColors.surfaceMuted.withValues(alpha: 0.6),
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: got != null ? 1 : 0.3,
                  child: Text(b.emoji, style: const TextStyle(fontSize: 36)),
                ),
                const SizedBox(height: Space.sm),
                Text(b.name, style: t.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text(b.desc, style: t.bodySmall, textAlign: TextAlign.center, maxLines: 2),
                if (got != null) ...[
                  const SizedBox(height: 4),
                  Text(got.replaceAll('-', '.'), style: t.bodySmall?.copyWith(color: AppColors.sage)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 새로 받은 배지를 보여준다.
void showNewBadges(BuildContext context, List<String> ids) {
  if (ids.isEmpty) return;
  final names = ids.map(badgeById).nonNulls.map((b) => '${b.emoji} ${b.name}').join('  ');
  showAppSnack(
    context,
    '새 배지를 받았어요  $names',
    actionLabel: '보기',
    onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen())),
  );
}
