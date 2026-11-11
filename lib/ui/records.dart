import 'package:flutter/cupertino.dart' show CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/rewards.dart';
import '../theme/tokens.dart';
import 'motion.dart';
import 'widgets.dart';

enum RecordRange { day, week, month }

/// 기록 탭. 기간과 기준 날짜는 홈 바로가기에서도 바꿀 수 있게 밖에서 받는다.
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key, required this.range, required this.anchor});
  final ValueNotifier<RecordRange> range;
  final ValueNotifier<DateTime?> anchor;

  DateTime _shift(RecordRange r, DateTime d, int dir) => switch (r) {
    RecordRange.day => d.add(Duration(days: dir)),
    RecordRange.week => d.add(Duration(days: 7 * dir)),
    RecordRange.month => DateTime(d.year, d.month + dir, 1),
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([range, anchor]),
      builder: (context, _) {
        final s = AppScope.of(context);
        final t = Theme.of(context).textTheme;
        final today = s.today;
        final r = range.value;
        final a = anchor.value ?? today;
        final canNext = switch (r) {
          RecordRange.day => a.isBefore(today),
          RecordRange.week => weekStart(a).isBefore(weekStart(today)),
          RecordRange.month => DateTime(a.year, a.month).isBefore(DateTime(today.year, today.month)),
        };
        final title = switch (r) {
          RecordRange.day => DateFormat('M월 d일 (E)', 'ko_KR').format(a),
          RecordRange.week =>
            '${DateFormat('M/d').format(weekStart(a))} – ${DateFormat('M/d').format(weekStart(a).add(const Duration(days: 6)))}',
          RecordRange.month => DateFormat('yyyy년 M월').format(a),
        };

        return Scaffold(
          appBar: AppBar(title: const Text('기록')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
            children: [
              if (isApple)
                CupertinoSlidingSegmentedControl<RecordRange>(
                  groupValue: r,
                  backgroundColor: AppColors.surfaceMuted,
                  thumbColor: AppColors.surface,
                  children: const {
                    RecordRange.day: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('일간')),
                    RecordRange.week: Text('주간'),
                    RecordRange.month: Text('월간'),
                  },
                  onValueChanged: (v) {
                    if (v != null) range.value = v;
                  },
                )
              else
                SegmentedButton<RecordRange>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.primarySoft,
                    side: const BorderSide(color: AppColors.line),
                  ),
                  segments: const [
                    ButtonSegment(value: RecordRange.day, label: Text('일간')),
                    ButtonSegment(value: RecordRange.week, label: Text('주간')),
                    ButtonSegment(value: RecordRange.month, label: Text('월간')),
                  ],
                  selected: {r},
                  onSelectionChanged: (v) => range.value = v.first,
                ),
              const SizedBox(height: Space.lg),
              Row(
                children: [
                  IconButton(
                    tooltip: '이전',
                    onPressed: () => anchor.value = _shift(r, a, -1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(title, style: t.titleMedium, textAlign: TextAlign.center),
                  ),
                  IconButton(
                    tooltip: '다음',
                    onPressed: canNext ? () => anchor.value = _shift(r, a, 1) : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              switch (r) {
                RecordRange.day => _DayView(day: a),
                RecordRange.week => _WeekView(
                  start: weekStart(a),
                  onPick: (d) {
                    range.value = RecordRange.day;
                    anchor.value = d;
                  },
                ),
                RecordRange.month => _MonthView(
                  month: DateTime(a.year, a.month),
                  onPick: (d) {
                    range.value = RecordRange.day;
                    anchor.value = d;
                  },
                ),
              },
              const SizedBox(height: Space.xl),
              Text('기록이 적은 날도 괜찮아요. 오늘 하나만 다시 해보면 돼요.', style: t.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }
}

DateTime weekStart(DateTime d) => dateOnly(d).subtract(Duration(days: d.weekday - 1));

class _DayView extends StatelessWidget {
  const _DayView({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final isToday = dateKey(day) == s.todayKey;
    final log = isToday ? s.todayLog : s.logs[dateKey(day)];
    if (log == null || log.total == 0) {
      return Panel(
        child: Column(
          children: [
            EmptyHint(
              emoji: '📭',
              title: log == null ? '기록이 없는 날이에요' : '루틴이 없던 날이에요',
              body: log == null ? '이 날은 앱을 열지 않았어요.' : '쉬어간 날도 하루예요.',
            ),
            if (log != null) _Memo(log: log, editable: isToday),
          ],
        ),
      );
    }
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                value: log.rate,
                size: 72,
                child: Text('${(log.rate * 100).round()}%', style: t.labelLarge),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${log.done}개를 해냈어요', style: t.titleMedium),
                    Text(log.rewarded ? '보상을 받은 날 · 루틴 ${log.total}개 중' : '루틴 ${log.total}개 중', style: t.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          for (final e in log.scheduled.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    log.completed.contains(e.key) ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 20,
                    color: log.completed.contains(e.key) ? AppColors.sage : AppColors.line,
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(child: Text(e.value, style: t.bodyLarge)),
                ],
              ),
            ),
          const SizedBox(height: Space.md),
          _Memo(log: log, editable: isToday),
        ],
      ),
    );
  }
}

/// 오늘 한 줄 메모. 오늘만 고칠 수 있다.
class _Memo extends StatelessWidget {
  const _Memo({required this.log, required this.editable});
  final DayLog log;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (!editable && log.memo.isEmpty) return const SizedBox.shrink();
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: editable ? () => _edit(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(editable ? '오늘 한 줄 메모' : '그날의 한 줄', style: t.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      log.memo.isEmpty ? '오늘을 한 줄로 남겨볼까요?' : log.memo,
                      style: t.bodyLarge?.copyWith(color: log.memo.isEmpty ? AppColors.textMuted : AppColors.text),
                    ),
                  ],
                ),
              ),
              if (editable) const Icon(Icons.edit_rounded, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final s = AppScope.read(context);
    final c = TextEditingController(text: log.memo);
    final text = await showAppDialog<String>(
      context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('오늘 한 줄 메모'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(hintText: '예: 오늘도 무사히 하루를 보냈다.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('저장')),
        ],
      ),
    );
    if (text != null) s.setTodayMemo(text);
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({required this.start, required this.onPick});
  final DateTime start;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final days = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
    final logs = [for (final d in days) s.logs[dateKey(d)]];
    final doneSum = logs.fold<int>(0, (a, l) => a + (l?.done ?? 0));
    final recorded = logs.where((l) => l != null && l.done > 0).length;

    return Column(
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$recorded일 기록, 작은 일 $doneSum개를 해냈어요', style: t.titleMedium),
              const SizedBox(height: Space.xl),
              SizedBox(
                height: 150,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: _Bar(
                          label: weekdayLabels[i],
                          log: logs[i],
                          future: days[i].isAfter(s.today),
                          today: dateKey(days[i]) == s.todayKey,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.line),
                ListTile(
                  enabled: !days[i].isAfter(s.today),
                  onTap: () => onPick(days[i]),
                  title: Text('${weekdayLabels[i]} ${DateFormat('M/d').format(days[i])}', style: t.titleMedium),
                  subtitle: Text(
                    switch (logs[i]) {
                      null => days[i].isAfter(s.today) ? '' : '기록 없음',
                      final l when l.total == 0 => '루틴이 없던 날',
                      final l => '루틴 ${l.done}개 완료${l.memo.isNotEmpty ? ' · ${l.memo}' : ''}',
                    },
                    style: t.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: logs[i] != null && logs[i]!.total > 0
                      ? Text('${logs[i]!.done} / ${logs[i]!.total}', style: t.labelLarge)
                      : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.log, required this.future, required this.today});
  final String label;
  final DayLog? log;
  final bool future;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final has = log != null && log!.total > 0;
    final rate = has ? log!.rate : 0.0;
    return Semantics(
      label: '$label요일 ${has ? '${(rate * 100).round()}%' : '기록 없음'}',
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: future ? Colors.transparent : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  if (has)
                    FractionallySizedBox(
                      heightFactor: rate.clamp(0.04, 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: rate >= RewardRules.threshold ? AppColors.sage : AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            label,
            style: t.bodySmall?.copyWith(
              color: today ? AppColors.primary : AppColors.textMuted,
              fontWeight: today ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({required this.month, required this.onPick});
  final DateTime month;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = Theme.of(context).textTheme;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = month.weekday - 1;
    final last = DateTime(month.year, month.month, daysInMonth);
    final logs = s.logsBetween(month, last).toList();
    final achievedDays = logs.where((l) => l.rewarded).length;
    final doneSum = logs.fold<int>(0, (a, l) => a + l.done);
    final perRoutine = s.perRoutine(month, last);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final w in weekdayLabels)
                    Expanded(
                      child: Center(child: Text(w, style: t.bodySmall)),
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (var i = 0; i < lead; i++) const SizedBox(),
                  for (var d = 1; d <= daysInMonth; d++) _cell(context, DateTime(month.year, month.month, d)),
                ],
              ),
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.md,
                runSpacing: Space.xs,
                children: [
                  _legend(AppColors.surfaceMuted, '기록 없음', t),
                  _legend(AppColors.primarySoft, '조금', t),
                  _legend(AppColors.sage, '${(RewardRules.threshold * 100).round()}% 이상', t),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        Text('이번 달 성취', style: t.titleMedium),
        const SizedBox(height: Space.sm),
        Panel(
          child: Row(
            children: [
              _Num(label: '보상 받은 날', value: '$achievedDays일'),
              _Num(label: '완료한 루틴', value: '$doneSum개'),
              _Num(label: '기록한 날', value: '${logs.where((l) => l.done > 0).length}일'),
            ],
          ),
        ),
        if (perRoutine.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          Text('루틴별 달성 현황', style: t.titleMedium),
          const SizedBox(height: Space.sm),
          Panel(
            child: Column(
              children: [
                for (final r in perRoutine)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(r.label, style: t.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            Text('${r.done} / ${r.total}', style: t.labelLarge),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: r.total == 0 ? 0 : r.done / r.total,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceMuted,
                            color: AppColors.sage,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.lg),
        Panel(
          color: AppColors.primarySoft.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('한 달을 살아낸 나에게', style: t.titleMedium),
              const SizedBox(height: Space.xs),
              Text('평범한 하루하루가 쌓여 한 달이 되었어요. 오늘도 잘 해냈어요.', style: t.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legend(Color c, String label, TextTheme t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: t.bodySmall),
    ],
  );

  Widget _cell(BuildContext context, DateTime d) {
    final s = AppScope.of(context);
    final l = s.logs[dateKey(d)];
    final future = d.isAfter(s.today);
    final isToday = dateKey(d) == s.todayKey;
    final has = l != null && l.done > 0;
    final color = !has
        ? (future ? Colors.transparent : AppColors.surfaceMuted)
        : (l.rate >= RewardRules.threshold ? AppColors.sage : AppColors.primarySoft);
    return Semantics(
      button: !future,
      label: '${d.day}일 ${has ? '${l.done}개 완료' : '기록 없음'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: future ? null : () => onPick(d),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isToday ? Border.all(color: AppColors.primary, width: 2) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${d.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: future ? AppColors.line : (has && l.rate >= RewardRules.threshold ? Colors.white : AppColors.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _Num extends StatelessWidget {
  const _Num({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: t.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: t.bodySmall),
        ],
      ),
    );
  }
}
