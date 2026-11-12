import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/rewards.dart';
import '../theme/tokens.dart';
import 'motion.dart';
import 'records.dart';
import 'room/room_painter.dart';
import 'routines.dart';
import 'settings.dart';
import 'shell.dart';
import 'widgets.dart';

/// 한글이 낱말 중간에서 줄바꿈되지 않게, 붙어 있는 글자 사이에 폭 없는 이음자(U+200D)를 넣는다.
String keepWords(String s) => s.replaceAllMapped(RegExp(r'\S(?=\S)'), (m) => '${m[0]}\u200D');

/// 달성률에 따라 고르는 부드러운 한마디. 실패라는 말은 쓰지 않는다.
String gentleLine(int done, int total) {
  if (total == 0) return '';
  return keepWords(switch (done) {
    0 => '천천히 시작해도 괜찮아요. 하나만 해봐도 충분해요.',
    _ when done == total => '오늘을 온전히 살아냈어요. 정말 수고했어요.',
    _ when done / total >= RewardRules.threshold => '오늘 몫의 하루를 해냈어요. 남은 건 여유가 되면요.',
    _ => '벌써 $done개나 했어요. 이대로도 잘하고 있어요.',
  });
}

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  /// 한 번에 기록하기 모드에서 고른 루틴
  Set<String>? _batch;

  void _after(DailyReward? r) {
    if (!mounted) return;
    final badges = AppScope.read(context).takePendingBadges();
    if (r != null) {
      HapticFeedback.mediumImpact();
      showRewardSheet(context, r).then((_) {
        if (mounted) showNewBadges(context, badges);
      });
    } else {
      showNewBadges(context, badges);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final log = s.todayLog;
    final list = s.todayRoutines;
    final t = Theme.of(context).textTheme;
    final batching = _batch != null;
    final pending = list.where((r) => !log.completed.contains(r.id)).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Reveal(
                      index: 0,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('M월 d일 EEEE', 'ko_KR').format(s.today),
                              style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          const LevelChip(),
                          const SizedBox(width: Space.sm),
                          const CoinChip(),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Reveal(
                      index: 1,
                      child: Text('${s.profile.name.isEmpty ? '나' : s.profile.name}의 오늘', style: t.headlineMedium),
                    ),
                    const SizedBox(height: Space.lg),
                    Reveal(
                      index: 2,
                      child: _Summary(done: log.done, total: log.total, rewarded: log.rewarded),
                    ),
                    const SizedBox(height: Space.xl),
                    if (list.isNotEmpty)
                      Row(
                        children: [
                          Text(batching ? '완료한 것을 골라주세요' : '오늘의 루틴', style: t.titleMedium),
                          const Spacer(),
                          if (pending.length > 1 || batching)
                            TextButton(
                              onPressed: () => setState(() => _batch = batching ? null : <String>{}),
                              child: Text(batching ? '취소' : '한 번에 기록하기'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (list.isEmpty)
              SliverToBoxAdapter(
                child: EmptyHint(
                  emoji: s.routines.isEmpty ? '🌱' : '☕',
                  title: s.routines.isEmpty ? '아직 기록할 루틴이 없어요' : '오늘은 쉬어가는 날이에요',
                  body: s.routines.isEmpty ? '물 한 잔 마시기처럼 아주 작은 것부터 시작해봐요.' : '오늘 요일에 정해둔 루틴이 없어요. 편하게 보내세요.',
                  action: OutlinedButton(onPressed: () => addRoutineFlow(context), child: const Text('루틴 추가하기')),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                  itemBuilder: (context, i) {
                    final r = list[i];
                    final done = log.completed.contains(r.id);
                    if (batching) {
                      return _RoutineRow(
                        routine: r,
                        done: done,
                        selectable: !done,
                        selected: _batch!.contains(r.id),
                        onTap: done
                            ? null
                            : () => setState(() {
                                if (!_batch!.remove(r.id)) _batch!.add(r.id);
                              }),
                      );
                    }
                    return _RoutineRow(
                      routine: r,
                      done: done,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _after(s.toggle(r.id));
                      },
                    );
                  },
                ),
              ),
            if (list.isNotEmpty && !batching)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                sliver: SliverToBoxAdapter(
                  child: OutlinedButton.icon(
                    onPressed: () => addRoutineFlow(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('루틴 추가하기'),
                  ),
                ),
              ),
            if (!batching)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 120),
                sliver: SliverToBoxAdapter(child: _Shortcuts()),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      bottomSheet: batching
          ? SafeArea(
              child: Container(
                color: AppColors.background,
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.md),
                child: FilledButton(
                  onPressed: _batch!.isEmpty
                      ? null
                      : () {
                          final reward = s.completeMany(_batch!);
                          setState(() => _batch = null);
                          _after(reward);
                        },
                  child: Text(_batch!.isEmpty ? '완료한 루틴을 골라주세요' : '${_batch!.length}개 완료로 기록'),
                ),
              ),
            )
          : null,
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.done, required this.total, required this.rewarded});
  final int done;
  final int total;
  final bool rewarded;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = AppScope.of(context);
    final rate = total == 0 ? 0.0 : done / total;
    final need = (total * RewardRules.threshold).ceil();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                value: rate,
                size: 96,
                child: total == 0
                    ? Text('–', style: t.titleLarge?.copyWith(color: AppColors.textMuted))
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$done/$total', style: t.titleLarge),
                          Text('${(rate * 100).round()}%', style: t.bodySmall),
                        ],
                      ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: Motion.normal,
                      child: Text(
                        total == 0 ? '오늘은 기록할 루틴이 없어요.' : gentleLine(done, total),
                        key: ValueKey('$done/$total'),
                        style: t.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    if (total > 0 && !rewarded) Text('$need개를 마치면 경험치와 코인을 받아요', style: t.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (rewarded) ...[
            const SizedBox(height: Space.md),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.sage),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text('오늘의 보상을 받았어요', style: t.bodyMedium?.copyWith(color: AppColors.sage)),
                ),
                TextButton(
                  onPressed: () {
                    final r = s.todayReward;
                    if (r != null) showRewardSheet(context, r);
                  },
                  child: const Text('보상 확인'),
                ),
              ],
            ),
          ],
          const SizedBox(height: Space.md),
          const XpBar(),
        ],
      ),
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.routine,
    required this.done,
    required this.onTap,
    this.selectable = false,
    this.selected = false,
  });
  final Routine routine;
  final bool done;
  final VoidCallback? onTap;
  final bool selectable;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final highlight = selectable ? selected : done;
    final sub = [formatMinute(routine.minuteOfDay), if (routine.memo.isNotEmpty) routine.memo].join(' · ');
    return Semantics(
      button: true,
      checked: done || selected,
      label: '${routine.name}, $sub',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Motion.normal,
        curve: Motion.curve,
        decoration: BoxDecoration(
          color: done ? AppColors.sageSoft.withValues(alpha: 0.55) : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: selectable && selected ? AppColors.primary : AppColors.line.withValues(alpha: 0.7),
            width: selectable && selected ? 1.5 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
              child: Row(
                children: [
                  Text(routine.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.name,
                          style: t.titleMedium?.copyWith(color: done ? AppColors.textMuted : AppColors.text),
                        ),
                        Text(sub, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  SpringPop(
                    active: highlight,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: highlight ? (selectable ? AppColors.primary : AppColors.sage) : Colors.transparent,
                        border: Border.all(
                          color: highlight ? Colors.transparent : (done ? AppColors.sage : AppColors.line),
                          width: 2,
                        ),
                      ),
                      child: (highlight || done)
                          ? Icon(Icons.check_rounded, size: 20, color: highlight ? Colors.white : AppColors.sage)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 기록 돌아보기 · 미니미 방 · 오늘의 한마디
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('기록 돌아보기', style: t.titleMedium),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          children: [
            for (final (label, range) in [
              ('오늘', RecordRange.day),
              ('이번 주', RecordRange.week),
              ('이번 달', RecordRange.month),
            ])
              ActionChip(
                label: Text(label),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.line),
                onPressed: () => HomeShell.openRecords(context, range),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Expanded(
              child: _ShortcutCard(
                label: '미니미 방 보기',
                onTap: () => HomeShell.goTo(context, HomeShell.room),
                child: MinimiView(profile: s.profile, width: 44),
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: _ShortcutCard(
                label: '오늘의 한마디',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EncouragementScreen())),
                child: const Text('💌', style: TextStyle(fontSize: 34)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.label, required this.onTap, required this.child});
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(Radii.md),
    child: InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: onTap,
      // 큰 글씨에서는 칸이 글자만큼 늘어난다
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 112),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 56, child: Center(child: child)),
              const SizedBox(height: Space.sm),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 오늘의 한마디 (격려 메시지 화면)
class EncouragementScreen extends StatelessWidget {
  const EncouragementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final log = s.todayLog;
    final t = Theme.of(context).textTheme;
    final (title, body) = switch (log) {
      _ when log.total == 0 => ('쉬어가는 하루도 하루예요', '오늘은 정해 둔 루틴이 없어요. 편하게 숨 고르는 것도 충분히 잘 사는 거예요.'),
      _ when log.done == log.total => ('오늘을 온전히 살아냈어요', '작은 일 하나하나를 다 해낸 하루예요. 스스로를 꼭 칭찬해 주세요.'),
      _ when log.rewarded => ('오늘 몫을 해냈어요', '남은 건 여유가 될 때만 해도 괜찮아요. 이미 충분해요.'),
      _ => ('오늘도 충분히 잘 살아냈어요', '모든 루틴을 채우지 못해도 괜찮아요. 평범한 하루를 살아낸 것만으로도 충분해요.'),
    };
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Column(
            children: [
              const Spacer(),
              Reveal(index: 0, child: MinimiView(profile: s.profile, happy: true, width: 120)),
              const SizedBox(height: Space.xl),
              Reveal(
                index: 1,
                child: Text(title, style: t.headlineMedium, textAlign: TextAlign.center),
              ),
              const SizedBox(height: Space.md),
              Reveal(
                index: 2,
                child: Text(
                  keepWords(body),
                  style: t.bodyLarge?.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
              if (log.total > 0) ...[
                const SizedBox(height: Space.xl),
                Reveal(
                  index: 3,
                  child: Panel(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('오늘 완료한 루틴', style: t.bodyMedium),
                        const SizedBox(width: Space.md),
                        Text('${log.done} / ${log.total}', style: t.titleMedium),
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('홈으로 돌아가기')),
              const SizedBox(height: Space.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// 하루 보상 시트. 레벨업이면 '레벨 달성 확인하기'로 이어진다.
Future<void> showRewardSheet(BuildContext context, DailyReward r) {
  final s = AppScope.read(context);
  return showAppSheet<void>(
    context,
    showDragHandle: false,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Reveal(index: 0, child: MinimiView(profile: s.profile, happy: true)),
              const SizedBox(height: Space.lg),
              Reveal(
                index: 1,
                child: Text(
                  r.perfect ? '오늘을 온전히 살아냈어요' : '오늘 하루도 잘 해냈어요',
                  style: t.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Space.xs),
              Reveal(
                index: 2,
                child: Text('평범한 하루를 살아낸 것만으로도 충분해요.', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
              ),
              const SizedBox(height: Space.md),
              Reveal(
                index: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StatChip(
                      icon: Icons.eco_rounded,
                      label: '+${r.xp} XP',
                      color: AppColors.sage,
                      bg: AppColors.sageSoft,
                    ),
                    const SizedBox(width: Space.sm),
                    StatChip(
                      icon: Icons.circle,
                      label: '+${r.coins} 코인',
                      color: AppColors.coin,
                      bg: AppColors.coinSoft,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xl),
              if (r.leveledUp)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showLevelUp(context, r);
                  },
                  child: const Text('레벨 달성 확인하기'),
                )
              else
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    HomeShell.goTo(context, HomeShell.room);
                  },
                  child: const Text('방 꾸미러 가기'),
                ),
              const SizedBox(height: Space.sm),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
            ],
          ),
        ),
      );
    },
  );
}

/// 레벨 달성 모달: 새로 열린 아이템과 보너스 코인.
Future<void> showLevelUp(BuildContext context, DailyReward r) {
  final s = AppScope.read(context);
  final unlocked = [for (var l = r.newLevel - r.levelsGained + 1; l <= r.newLevel; l++) ...s.unlockedAt(l)];
  return showAppDialog<void>(
    context,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return Dialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Reveal(index: 0, child: Text('레벨 달성', style: t.bodySmall)),
              const SizedBox(height: Space.xs),
              Reveal(index: 1, child: Text('Lv.${r.newLevel}', style: t.headlineMedium)),
              const SizedBox(height: Space.xs),
              Reveal(
                index: 2,
                child: Text('꾸준히 쌓인 하루가 새로운 단계에 닿았어요', style: t.bodyMedium, textAlign: TextAlign.center),
              ),
              const SizedBox(height: Space.lg),
              Reveal(
                index: 3,
                child: StatChip(
                  icon: Icons.circle,
                  label: '보너스 +${RewardRules.levelUpCoins * r.levelsGained} 코인',
                  color: AppColors.coin,
                  bg: AppColors.coinSoft,
                ),
              ),
              if (unlocked.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                Text('새로 살 수 있게 됐어요', style: t.bodySmall),
                const SizedBox(height: Space.sm),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: Space.md,
                  runSpacing: Space.sm,
                  children: [
                    for (final i in unlocked)
                      SizedBox(
                        width: 76,
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(Radii.md),
                              ),
                              child: ItemThumb(i, size: 64, minimi: s.profile.minimi),
                            ),
                            const SizedBox(height: 4),
                            Text(i.name, style: t.bodySmall, textAlign: TextAlign.center, maxLines: 2),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Space.xl),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  HomeShell.openShop(context);
                },
                child: const Text('가구 보러 가기'),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
            ],
          ),
        ),
      );
    },
  );
}
