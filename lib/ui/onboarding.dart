import 'package:flutter/material.dart' hide Text;

import '../app.dart';
import '../data/catalog.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import 'motion.dart';
import 'room/room_painter.dart';
import 'routines.dart';
import 'routine_icon.dart';
import 'widgets.dart';

/// 가입 직후 첫 설정: 닉네임 → 미니미 → 루틴 템플릿과 알림
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
  late final _name = TextEditingController(text: AppScope.read(context).profile.name);

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
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
      name: _name.text,
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
                  _Dots(step: _step, count: 3),
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
                  _NameStep(controller: _name, onNext: () => _go(1)),
                  _MinimiStep(
                    name: _name.text.trim(),
                    minimi: _minimi,
                    onChanged: (m) => setState(() => _minimi = m),
                    onNext: () => _go(2),
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
        margin: const EdgeInsets.symmetric(horizontal: Space.xs),
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

/// 첫 설정 한 장: 제목·설명·내용은 함께 세로로 넘겨 보고, 아래 버튼은 붙어 있다.
/// 키보드가 올라오거나 화면을 눕혀 높이가 모자라도 넘치지 않는다.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.title, required this.body, required this.content, required this.bottom});
  final String title;
  final String body;

  /// 제목·설명 아래에 이어지는 내용 (스스로 스크롤하지 않는 위젯들)
  final List<Widget> content;
  final Widget bottom;

  /// 버튼을 아래에 붙여 두기에 모자란 높이 (눕힌 화면에 키보드까지 올라왔을 때). 이보다 낮으면 버튼도 함께 넘겨 본다.
  static const _tooShort = 160.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scrolling = [
      const SizedBox(height: Space.xl),
      Reveal(index: 0, child: Text(title, style: t.headlineMedium)),
      const SizedBox(height: Space.sm),
      Reveal(
        index: 1,
        child: Text(keepWords(body), style: t.bodyLarge?.copyWith(color: AppColors.textMuted)),
      ),
      const SizedBox(height: Space.xl),
      ...content,
    ];
    final fixed = [bottom, const SizedBox(height: Space.lg)];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: LayoutBuilder(
        builder: (context, box) => box.maxHeight < _tooShort
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...scrolling,
                    const SizedBox(height: Space.md),
                    ...fixed,
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: ListView(children: scrolling)),
                  ...fixed,
                ],
              ),
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller, required this.onNext});
  final TextEditingController controller;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _StepScaffold(
    title: '뭐라고 불러드릴까요?',
    body: '앱 안에서만 쓰는 이름이에요. 나중에 계정 정보에서 바꿀 수 있어요.',
    content: [
      TextField(
        controller: controller,
        maxLength: 10,
        autofocus: controller.text.isEmpty,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(labelText: '닉네임', counterText: ''),
      ),
    ],
    bottom: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => FilledButton(
        onPressed: controller.text.trim().isEmpty
            ? null
            : () {
                FocusScope.of(context).unfocus();
                onNext();
              },
        child: const Text('다음'),
      ),
    ),
  );
}

class _MinimiStep extends StatelessWidget {
  const _MinimiStep({required this.name, required this.minimi, required this.onChanged, required this.onNext});
  final String name;
  final Minimi minimi;
  final ValueChanged<Minimi> onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // 제목은 올라가 사라지고, 미니미는 위에 붙어 남는다: 아래 색을 고르면서 바뀐 모습을 바로 본다.
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: Space.xl),
                      Reveal(index: 0, child: Text('$name님을 닮은\n미니미를 만들어요', style: t.headlineMedium)),
                      const SizedBox(height: Space.sm),
                      Reveal(
                        index: 1,
                        child: Text(
                          keepWords('이 친구가 앞으로 지낼 방을 함께 꾸며갈 거예요'),
                          style: t.bodyLarge?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(height: Space.md),
                    ],
                  ),
                ),
                SliverPersistentHeader(pinned: true, delegate: _PinnedMinimi(minimi)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: Space.md, bottom: Space.lg),
                    child: MinimiPicker(minimi: minimi, onChanged: onChanged, basic: true),
                  ),
                ),
              ],
            ),
          ),
          FilledButton(onPressed: onNext, child: const Text('이 모습이 좋아요')),
          const SizedBox(height: Space.lg),
        ],
      ),
    );
  }
}

/// 스크롤해도 위에 붙어 있는 미니미. 붙으면 조금 작아져 고르는 칸에 자리를 내준다.
class _PinnedMinimi extends SliverPersistentHeaderDelegate {
  const _PinnedMinimi(this.minimi);
  final Minimi minimi;

  @override
  double get maxExtent => 124;
  @override
  double get minExtent => 108;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.background, // 아래로 지나가는 칸이 비치지 않게
      border: Border(
        bottom: BorderSide(color: overlapsContent ? AppColors.line.withValues(alpha: 0.7) : Colors.transparent),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: FittedBox(
        child: Breathing(
          child: MinimiView(profile: Profile(minimi: minimi), happy: true, width: 140),
        ),
      ),
    ),
  );

  @override
  bool shouldRebuild(_PinnedMinimi old) => old.minimi != minimi;
}

/// 피부·머리·얼굴·옷 색 고르기. 설정 화면에서도 쓴다.
class MinimiPicker extends StatelessWidget {
  const MinimiPicker({super.key, required this.minimi, required this.onChanged, this.basic = false});
  final Minimi minimi;
  final ValueChanged<Minimi> onChanged;

  /// 첫 설정에서는 피부·머리·눈·입만 고른다 (염색·옷 색은 설정 화면에서)
  final bool basic;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _row(context, '피부', skinTones, minimi.skin, (i) => onChanged(minimi.copyWith(skin: i)), Minimi.skinNames),
      _chips(context, '머리', Minimi.hairStyleNames, minimi.hairStyle, (i) => onChanged(minimi.copyWith(hairStyle: i))),
      if (!basic) _row(context, '염색', hairColors, minimi.hair, (i) => onChanged(minimi.copyWith(hair: i))),
      _chips(context, '눈', Minimi.eyeNames, minimi.eyes, (i) => onChanged(minimi.copyWith(eyes: i))),
      _chips(context, '입', Minimi.mouthNames, minimi.mouth, (i) => onChanged(minimi.copyWith(mouth: i))),
      if (!basic) _row(context, '옷 색', outfitColors, minimi.outfit, (i) => onChanged(minimi.copyWith(outfit: i))),
    ],
  );

  Widget _chips(BuildContext context, String label, List<String> names, int sel, ValueChanged<int> on) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Space.md),
          child: SizedBox(width: 64, child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
        ),
        Expanded(
          child: Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              for (var i = 0; i < names.length; i++)
                ChoiceChip(
                  label: Text(names[i]),
                  selected: i == sel,
                  onSelected: (_) => on(i),
                  showCheckmark: false,
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.selected,
                  side: const BorderSide(color: AppColors.line),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _row(
    BuildContext context,
    String label,
    List<Color> colors,
    int sel,
    ValueChanged<int> on, [
    List<String>? names,
  ]) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                if (names != null) Text(names[sel % names.length], style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: Space.md,
            runSpacing: Space.md,
            children: [
              for (var i = 0; i < colors.length; i++)
                Semantics(
                  button: true,
                  selected: i == sel,
                  label: names != null ? '${names[i]} $label' : '$label ${i + 1}번',
                  child: GestureDetector(
                    onTap: () => on(i),
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors[i],
                        shape: BoxShape.circle,
                        // 밝은 피부색도 바탕과 구분되게 옅은 테두리를 둔다
                        border: Border.all(
                          color: i == sel ? AppColors.text : AppColors.line,
                          width: i == sel ? 2.5 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
      content: [
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
              SwitchListTile.adaptive(
                title: const Text('루틴 시간에 알림 받기'),
                subtitle: const Text('고른 루틴의 시간에 살며시 알려드려요'),
                value: routineAlarm,
                activeThumbColor: AppColors.primary,
                onChanged: onRoutineAlarm,
              ),
              SwitchListTile.adaptive(
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
        Text('알림은 나중에 \'나\' 탭에서 바꿀 수 있어요', style: t.bodySmall),
        const SizedBox(height: Space.md),
      ],
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: on ? AppColors.text : Colors.transparent, width: 1.5),
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
                RoutineIcon(r.emoji),
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
                  color: on ? AppColors.sage : AppColors.line,
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
