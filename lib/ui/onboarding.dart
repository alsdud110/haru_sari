import 'package:flutter/material.dart';

import '../app.dart';
import '../data/catalog.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import 'motion.dart';
import 'room/room_painter.dart';
import 'routines.dart';
import 'widgets.dart';

/// 가입 직후 첫 설정: 미니미 → 루틴 템플릿과 알림
class SetupFlow extends StatefulWidget {
  const SetupFlow({super.key});
  @override
  State<SetupFlow> createState() => _SetupFlowState();
}

class _SetupFlowState extends State<SetupFlow> {
  final _page = PageController();
  int _step = 0;
  Minimi _minimi = const Minimi();

  /// 고른 템플릿 → 사용자가 고친 루틴
  final Map<int, Routine> _picked = {};
  bool _routineAlarm = true;
  bool _dayEnd = false;
  bool _busy = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _go(int step) {
    setState(() => _step = step);
    _page.animateToPage(step, duration: Motion.normal, curve: Motion.curve);
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    final s = AppScope.read(context);
    final keys = _picked.keys.toList()..sort();
    final routines = [for (final k in keys) _picked[k]!..alarmOn = _routineAlarm && _picked[k]!.minuteOfDay != null];
    if (_routineAlarm || _dayEnd) await s.reminders.requestPermission();
    s.finishOnboarding(
      minimi: _minimi,
      picked: routines,
      alarms: AlarmSettings(allOn: true, routineStart: _routineAlarm, dayEnd: _dayEnd),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      onPressed: () => _go(_step - 1),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: '이전',
                    )
                  else
                    const SizedBox(height: 48, width: 48),
                  const Spacer(),
                  _Dots(step: _step, count: 2),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MinimiStep(
                    name: AppScope.of(context).profile.name,
                    minimi: _minimi,
                    onChanged: (m) => setState(() => _minimi = m),
                    onNext: () => _go(1),
                  ),
                  _TemplateStep(
                    picked: _picked,
                    routineAlarm: _routineAlarm,
                    dayEnd: _dayEnd,
                    onRoutineAlarm: (v) => setState(() => _routineAlarm = v),
                    onDayEnd: (v) => setState(() => _dayEnd = v),
                    onToggle: (i) => setState(() {
                      if (_picked.remove(i) == null) _picked[i] = routineTemplates[i].toRoutine('t$i');
                    }),
                    onEdit: (i) async {
                      final edited = await editRoutine(context, _picked[i]!);
                      if (edited != null) setState(() => _picked[i] = edited);
                    },
                    busy: _busy,
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.step, required this.count});
  final int step;
  final int count;
  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(
      count,
      (i) => AnimatedContainer(
        duration: Motion.normal,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: i == step ? 22 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: i <= step ? AppColors.primary : AppColors.line,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    ),
  );
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.title, required this.body, required this.content, required this.bottom});
  final String title;
  final String body;
  final Widget content;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Space.xl),
          Reveal(index: 0, child: Text(title, style: t.headlineMedium)),
          const SizedBox(height: Space.sm),
          Reveal(
            index: 1,
            child: Text(body, style: t.bodyLarge?.copyWith(color: AppColors.textMuted)),
          ),
          const SizedBox(height: Space.xl),
          Expanded(child: content),
          bottom,
          const SizedBox(height: Space.lg),
        ],
      ),
    );
  }
}

class _MinimiStep extends StatelessWidget {
  const _MinimiStep({required this.name, required this.minimi, required this.onChanged, required this.onNext});
  final String name;
  final Minimi minimi;
  final ValueChanged<Minimi> onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _StepScaffold(
    title: '$name님을 닮은\n미니미를 만들어요',
    body: '이 친구가 앞으로 지낼 방을 함께 꾸며갈 거예요.',
    content: SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(width: 140, height: 170, child: CustomPaint(painter: MinimiPainter(minimi, happy: true))),
          const SizedBox(height: Space.xl),
          MinimiPicker(minimi: minimi, onChanged: onChanged),
        ],
      ),
    ),
    bottom: FilledButton(onPressed: onNext, child: const Text('이 모습이 좋아요')),
  );
}

/// 피부·머리·옷 색 고르기. 설정 화면에서도 쓴다.
class MinimiPicker extends StatelessWidget {
  const MinimiPicker({super.key, required this.minimi, required this.onChanged});
  final Minimi minimi;
  final ValueChanged<Minimi> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _row(context, '피부', skinTones, minimi.skin, (i) => onChanged(minimi.copyWith(skin: i))),
      _row(context, '머리', hairColors, minimi.hair, (i) => onChanged(minimi.copyWith(hair: i))),
      _row(context, '옷 색', outfitColors, minimi.outfit, (i) => onChanged(minimi.copyWith(outfit: i))),
    ],
  );

  Widget _row(BuildContext context, String label, List<Color> colors, int sel, ValueChanged<int> on) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.xs),
    child: Row(
      children: [
        SizedBox(width: 56, child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
        for (var i = 0; i < colors.length; i++)
          Semantics(
            button: true,
            selected: i == sel,
            label: '$label ${i + 1}번',
            child: GestureDetector(
              onTap: () => on(i),
              child: AnimatedContainer(
                duration: Motion.fast,
                margin: const EdgeInsets.only(right: Space.sm),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(color: i == sel ? AppColors.text : Colors.transparent, width: 2.5),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _TemplateStep extends StatelessWidget {
  const _TemplateStep({
    required this.picked,
    required this.routineAlarm,
    required this.dayEnd,
    required this.onRoutineAlarm,
    required this.onDayEnd,
    required this.onToggle,
    required this.onEdit,
    required this.onFinish,
    this.busy = false,
  });
  final Map<int, Routine> picked;
  final bool routineAlarm;
  final bool dayEnd;
  final ValueChanged<bool> onRoutineAlarm;
  final ValueChanged<bool> onDayEnd;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onEdit;
  final VoidCallback onFinish;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _StepScaffold(
      title: '하루를 이루는\n작은 일들을 골라요',
      body: '마음에 드는 것만 고르세요. 연필을 누르면 시간·요일을 고칠 수 있어요.',
      content: ListView(
        children: [
          for (var i = 0; i < routineTemplates.length; i++) ...[
            _TemplateRow(
              routine: picked[i] ?? routineTemplates[i].toRoutine('t$i'),
              on: picked.containsKey(i),
              onTap: () => onToggle(i),
              onEdit: () => onEdit(i),
            ),
            const SizedBox(height: Space.sm),
          ],
          const SizedBox(height: Space.lg),
          Text('알림', style: t.titleMedium),
          const SizedBox(height: Space.sm),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('루틴 시간에 알림 받기'),
                  subtitle: const Text('고른 루틴의 시간에 살며시 알려드려요'),
                  value: routineAlarm,
                  activeThumbColor: AppColors.primary,
                  onChanged: onRoutineAlarm,
                ),
                SwitchListTile(
                  title: const Text('하루 마무리 알림'),
                  subtitle: const Text('오후 10시, 오늘을 돌아볼 시간을 알려드려요'),
                  value: dayEnd,
                  activeThumbColor: AppColors.primary,
                  onChanged: onDayEnd,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
          Text('알림은 나중에 \'나\' 탭에서 바꿀 수 있어요.', style: t.bodySmall),
          const SizedBox(height: Space.md),
        ],
      ),
      bottom: Column(
        children: [
          const SizedBox(height: Space.md),
          FilledButton(
            onPressed: busy ? () {} : onFinish, // 로딩 중에도 버튼 색은 유지
            child: busy ? const AppSpinner() : Text(picked.isEmpty ? '직접 만들게요' : '${picked.length}개로 시작하기'),
          ),
        ],
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({required this.routine, required this.on, required this.onTap, required this.onEdit});
  final Routine routine;
  final bool on;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = routine;
    return AnimatedContainer(
      duration: Motion.fast,
      decoration: BoxDecoration(
        color: on ? AppColors.primarySoft.withValues(alpha: 0.5) : AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: on ? AppColors.primary : AppColors.line),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.sm, Space.md),
            child: Row(
              children: [
                Text(r.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name, style: t.titleMedium),
                      Text(
                        '${weekdaySummary(r.weekdays)} · ${formatMinute(r.minuteOfDay)} · ${r.category}',
                        style: t.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (on)
                  IconButton(
                    tooltip: '${r.name} 고치기',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.textMuted),
                  ),
                Icon(
                  on ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: on ? AppColors.primary : AppColors.line,
                ),
                const SizedBox(width: Space.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
