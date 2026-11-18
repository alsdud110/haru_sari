import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../config.dart';
import '../data/badges.dart';
import '../data/catalog.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import 'motion.dart';
import 'auth_screens.dart';
import 'licenses.dart';
import 'onboarding.dart';
import 'room/room_painter.dart';
import 'room/room_screen.dart';
import 'routines.dart';
import 'routine_icon.dart';
import 'time_sheet.dart';
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
              title: '미니미 꾸미기',
              subtitle: '헤어·얼굴·옷',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MinimiEditScreen())),
            ),
          ]),
          const SizedBox(height: Space.lg),
          _Section('알림', [
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.notifications_none_rounded, color: AppColors.textMuted),
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
          const SizedBox(height: Space.lg),
          _Section('앱 정보', [
            _Tile(
              icon: Icons.shield_outlined,
              title: '개인정보 처리방침',
              subtitle: '수집하는 정보와 계정 삭제 안내',
              // 웹 페이지(docs/privacy)를 브라우저로 연다
              onTap: () async {
                final ok = await launchUrl(Uri.parse(AppLinks.privacy), mode: LaunchMode.externalApplication);
                if (!ok && context.mounted) showAppToast(context, '페이지를 열지 못했어요. 잠시 뒤 다시 해 주세요');
              },
            ),
            _Tile(
              icon: Icons.description_outlined,
              title: '오픈소스 라이선스',
              subtitle: '글꼴과 오픈소스 고지',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LicensesScreen())),
            ),
          ]),
          const SizedBox(height: Space.xl),
          Text(
            '루틴을 놓친 날에도 경험치·코인·가구는 그대로예요.\n다시 시작하는 날이 곧 좋은 날이에요.',
            style: t.bodySmall?.cheer,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 미니미 꾸미기 페이지. 고르는 동안은 미리보기만 바뀌고, 저장을 눌러야 내 미니미가 바뀐다.
class MinimiEditScreen extends StatefulWidget {
  const MinimiEditScreen({super.key});

  @override
  State<MinimiEditScreen> createState() => _MinimiEditScreenState();
}

class _MinimiEditScreenState extends State<MinimiEditScreen> {
  late Minimi _draft = AppScope.read(context).profile.minimi;

  /// 산 옷의 색 (아이템 id → 색 번호)
  late Map<String, int> _colors = {...AppScope.read(context).profile.itemColors};

  /// 입을 산 옷 (없으면 기본 옷)
  late String? _top = AppScope.read(context).profile.outfitId;
  late String? _bottom = AppScope.read(context).profile.bottomId;

  bool get _dirty {
    final p = AppScope.read(context).profile;
    return _draft != p.minimi || !mapEquals(_colors, p.itemColors) || _top != p.outfitId || _bottom != p.bottomId;
  }

  void _save() {
    AppScope.read(context)
      ..updateMinimi(_draft)
      ..updateItemColors(_colors)
      ..dress(top: _top, bottom: _bottom);
    HapticFeedback.mediumImpact();
    showAppToast(context, '새 모습을 저장했어요');
    Navigator.pop(context);
  }

  /// 저장하지 않고 나가려 하면 물어본다
  Future<void> _leave() async {
    final save = await showAppDialog<bool>(
      context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('바꾼 모습을 저장할까요?'),
        content: const Text('저장하지 않으면 원래 모습으로 돌아가요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('저장 안 함')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장')),
        ],
      ),
    );
    if (save == null || !mounted) return;
    if (save) return _save();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.profile;
    final dirty = _dirty;
    // 산 옷 (상의·하의·원피스)
    final clothes = s.ownedItems.where((i) => i.kind == ItemKind.outfit).toList()
      // 최근에 산 옷이 맨 앞 (들인 날 'yyyy-mm-dd' 는 글자 순서가 날짜 순서)
      ..sort((a, b) => (p.acquired[b.id] ?? '').compareTo(p.acquired[a.id] ?? ''));
    // 눕힌 화면에서도 고르는 칸이 보이게 미리보기 높이를 화면에 맞춘다
    final stage = (MediaQuery.sizeOf(context).height * 0.28).clamp(120.0, 240.0);
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('미니미 꾸미기'),
          actions: [
            if (dirty)
              TextButton(
                onPressed: () => setState(() {
                  _draft = p.minimi;
                  _colors = {...p.itemColors};
                  _top = p.outfitId;
                  _bottom = p.bottomId;
                }),
                child: const Text('되돌리기'),
              ),
            IconButton(
              tooltip: '미니미 상점',
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen(minimi: true))),
              icon: const Icon(Icons.checkroom_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 미리보기: 상점 옷·액세서리도 입은 채로 보여 준다
                Container(
                  height: stage,
                  margin: const EdgeInsets.only(bottom: Space.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  padding: const EdgeInsets.all(Space.lg),
                  child: FittedBox(
                    child: Breathing(
                      child: MinimiView(
                        profile: Profile(
                          minimi: _draft,
                          outfitId: _top,
                          bottomId: _bottom,
                          accessoryId: p.accessoryId,
                          earringId: p.earringId,
                          itemColors: _colors,
                        ),
                        happy: true,
                        width: 160,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: MinimiPicker(
                    minimi: _draft,
                    onChanged: (m) => setState(() => _draft = m),
                    fill: true,
                    clothes: clothes,
                    top: _top,
                    bottom: _bottom,
                    itemColors: _colors,
                    onDress: (top, bottom, colors) => setState(() {
                      _top = top;
                      _bottom = bottom;
                      _colors = colors;
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm, bottom: Space.lg),
                  child: FilledButton(onPressed: dirty ? _save : null, child: const Text('저장')),
                ),
              ],
            ),
          ),
        ),
      ),
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
    leading: Icon(icon, color: AppColors.textMuted),
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
          Text('원하는 시간에만, 살며시 알려드려요', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: Panel(
                color: AppColors.coinSoft,
                child: Row(
                  children: [
                    const Expanded(child: Text('알림 전체가 꺼져 있어요')),
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
                    final picked = await showTimeSheet(context, initialMinute: a.dayEndMinute);
                    if (picked != null) s.updateAlarms(a..dayEndMinute = picked);
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
                      title: RoutineLabel('${timed[i].emoji} ${timed[i].name}', style: t.bodyLarge),
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
                Opacity(opacity: got != null ? 1 : 0.3, child: RoutineIcon(b.emoji, size: 48)),
                const SizedBox(height: Space.sm),
                Text(b.name, style: t.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text(b.desc, style: t.bodySmall, textAlign: TextAlign.center, maxLines: 2),
                if (got != null) ...[
                  const SizedBox(height: 4),
                  Text(got.replaceAll('-', '.'), style: t.bodySmall?.copyWith(color: AppColors.sageInk)),
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
  showAppSnack(
    context,
    '새 배지를 받았어요',
    actionLabel: '보기',
    onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen())),
  );
}
