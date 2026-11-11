import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import 'motion.dart';
import 'settings.dart';
import 'widgets.dart';

/// 루틴 편집 화면을 열고, 저장하면 고친 사본을 돌려준다.
Future<Routine?> editRoutine(BuildContext context, Routine r, {bool isNew = false}) => Navigator.of(context)
    .push<Routine>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RoutineEditorPage(initial: r.copy(), isNew: isNew),
      ),
    );

/// 새 루틴을 만들어 바로 저장한다.
Future<void> addRoutineFlow(BuildContext context) async {
  final s = AppScope.read(context);
  final r = await editRoutine(context, Routine(id: s.newId(), name: '', emoji: '✨'), isNew: true);
  if (r != null) s.upsertRoutine(r);
}

class RoutineManageScreen extends StatelessWidget {
  const RoutineManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.sortedRoutines;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 루틴 관리'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlarmSettingsScreen())),
            icon: const Icon(Icons.notifications_none_rounded, size: 20),
            label: const Text('알림 설정'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addRoutineFlow(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('새 루틴 추가하기'),
      ),
      body: list.isEmpty
          ? EmptyHint(
              emoji: '🌱',
              title: '아직 루틴이 없어요',
              body: '물 한 잔 마시기처럼 아주 작은 것부터 시작해도 충분해요.',
              action: OutlinedButton(onPressed: () => addRoutineFlow(context), child: const Text('첫 루틴 만들기')),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 120),
              itemCount: list.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
              itemBuilder: (context, i) {
                if (i == list.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: Text('스위치를 끄면 그 루틴은 잠시 쉬어요. 기록은 그대로예요.', style: t.bodySmall),
                  );
                }
                final r = list[i];
                return Opacity(
                  opacity: r.active ? 1 : 0.55,
                  child: Panel(
                    padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.xs, Space.xs),
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
                                '${r.category} · ${weekdaySummary(r.weekdays)} ${formatMinute(r.minuteOfDay)}${r.alarmOn ? ' · 알림' : ''}',
                                style: t.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: r.active,
                          activeThumbColor: AppColors.primary,
                          onChanged: (v) => s.setRoutineActive(r.id, v),
                        ),
                        PopupMenuButton<String>(
                          tooltip: '${r.name} 더보기',
                          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                          color: AppColors.surface,
                          onSelected: (v) async {
                            if (v == 'edit') {
                              final e = await editRoutine(context, r);
                              if (e != null) s.upsertRoutine(e);
                            } else if (context.mounted) {
                              _confirmDelete(context, r);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('편집')),
                            PopupMenuItem(value: 'delete', child: Text('삭제')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Routine r) async {
    final s = AppScope.read(context);
    final ok = await showAppDialog<bool>(
      context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('‘${r.name}’을(를) 지울까요?'),
        content: const Text('지금까지의 기록은 그대로 남아요.\n오늘 목록과 앞으로의 하루에서만 빠져요.\n잠시 쉬고 싶다면 스위치를 꺼도 돼요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('그대로 둘게요')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('지우기', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (ok == true) s.deleteRoutine(r.id);
  }
}

const _emojiChoices = ['🌤️', '💧', '👔', '🚇', '🍚', '🏃', '🏠', '🛁', '📖', '🧘', '💊', '🐶', '🪴', '✍️', '🎧', '✨'];

class RoutineEditorPage extends StatefulWidget {
  const RoutineEditorPage({super.key, required this.initial, this.isNew = false});
  final Routine initial;
  final bool isNew;

  @override
  State<RoutineEditorPage> createState() => _RoutineEditorPageState();
}

class _RoutineEditorPageState extends State<RoutineEditorPage> {
  late final Routine r = widget.initial;
  late final _name = TextEditingController(text: r.name);
  late final _memo = TextEditingController(text: r.memo);

  @override
  void dispose() {
    _name.dispose();
    _memo.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && r.weekdays.isNotEmpty;

  Future<void> _pickTime() async {
    final m = r.minuteOfDay ?? 8 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked != null) setState(() => r.minuteOfDay = picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? '루틴 추가' : '루틴 편집'),
        leading: IconButton(
          tooltip: '닫기',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
          children: [
            TextField(
              controller: _name,
              autofocus: widget.isNew,
              maxLength: 20,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: '루틴 이름', hintText: '예: 물 한 잔 마시기', counterText: ''),
            ),
            const SizedBox(height: Space.xl),
            Text('카테고리', style: t.titleMedium),
            const SizedBox(height: Space.sm),
            _ChoiceGrid(
              columns: 3,
              children: [
                for (final c in routineCategories)
                  _Choice(
                    selected: r.category == c,
                    semantics: '카테고리 $c',
                    onTap: () => setState(() => r.category = c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.md),
                      child: Text(c, style: t.labelLarge),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.xl),
            Text('아이콘', style: t.titleMedium),
            const SizedBox(height: Space.sm),
            _ChoiceGrid(
              columns: 6,
              children: [
                for (final e in _emojiChoices)
                  _Choice(
                    selected: r.emoji == e,
                    onTap: () => setState(() => r.emoji = e),
                    semantics: '아이콘 $e',
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
              ],
            ),
            const SizedBox(height: Space.xl),
            Text('반복 요일', style: t.titleMedium),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                for (var d = 1; d <= 7; d++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _Choice(
                        selected: r.weekdays.contains(d),
                        semantics: '${weekdayLabels[d - 1]}요일',
                        onTap: () => setState(() {
                          if (!r.weekdays.remove(d)) r.weekdays.add(d);
                        }),
                        child: Text(weekdayLabels[d - 1], style: t.labelLarge),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              children: [
                for (final (label, days) in [
                  ('매일', {1, 2, 3, 4, 5, 6, 7}),
                  ('평일', {1, 2, 3, 4, 5}),
                  ('주말', {6, 7}),
                ])
                  ActionChip(
                    label: Text(label),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.line),
                    onPressed: () => setState(() => r.weekdays = {...days}),
                  ),
              ],
            ),
            if (r.weekdays.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Text('요일을 하나 이상 골라주세요', style: t.bodySmall?.copyWith(color: AppColors.primary)),
              ),
            const SizedBox(height: Space.xl),
            Text('시간과 알림', style: t.titleMedium),
            const SizedBox(height: Space.sm),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('하는 시간'),
                    trailing: Text(formatMinute(r.minuteOfDay), style: t.labelLarge),
                    onTap: _pickTime,
                  ),
                  if (r.minuteOfDay != null)
                    ListTile(
                      title: const Text('시간 정하지 않기'),
                      leading: const Icon(Icons.schedule_rounded, color: AppColors.textMuted),
                      onTap: () => setState(() {
                        r.minuteOfDay = null;
                        r.alarmOn = false;
                      }),
                    ),
                  SwitchListTile.adaptive(
                    title: const Text('알림 받기'),
                    subtitle: Text(r.minuteOfDay == null ? '시간을 정하면 켤 수 있어요' : '그 시간에 살며시 알려드려요'),
                    value: r.alarmOn,
                    activeThumbColor: AppColors.primary,
                    onChanged: r.minuteOfDay == null ? null : (v) => setState(() => r.alarmOn = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            TextField(
              controller: _memo,
              maxLength: 40,
              maxLines: 2,
              minLines: 1,
              decoration: const InputDecoration(labelText: '한 줄 메모 (선택)', hintText: '예: 기상 후 바로'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.md),
          child: FilledButton(
            onPressed: _valid
                ? () {
                    r
                      ..name = _name.text.trim()
                      ..memo = _memo.text.trim();
                    Navigator.pop(context, r);
                  }
                : null,
            child: const Text('저장하기'),
          ),
        ),
      ),
    );
  }
}

/// 선택 버튼을 같은 폭의 칸으로 나란히 놓는다 (칸 높이 48).
class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({required this.columns, required this.children});
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView(
    shrinkWrap: true,
    padding: EdgeInsets.zero,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisExtent: 48,
      crossAxisSpacing: Space.sm,
      mainAxisSpacing: Space.sm,
    ),
    children: children,
  );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.selected, required this.onTap, required this.child, required this.semantics});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String semantics;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: semantics,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        height: 48,
        constraints: const BoxConstraints(minWidth: 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: selected ? 1.5 : 1),
        ),
        child: child,
      ),
    ),
  );
}
