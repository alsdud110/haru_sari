import 'package:flutter/material.dart' hide Text;

import '../app.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import 'motion.dart';
import 'settings.dart';
import 'routine_icon.dart';
import 'time_sheet.dart';
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
        backgroundColor: AppColors.text,
        foregroundColor: AppColors.background,
        icon: const Icon(Icons.add_rounded),
        label: const Text('새 루틴 추가하기'),
      ),
      body: list.isEmpty
          ? EmptyHint(
              emoji: '🌱',
              title: '아직 루틴이 없어요',
              body: '물 한 잔 마시기처럼 아주 작은 것부터 시작해도 충분해요',
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
                        RoutineIcon(r.emoji),
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
            child: const Text('지우기', style: TextStyle(color: AppColors.primaryInk)),
          ),
        ],
      ),
    );
    if (ok == true) s.deleteRoutine(r.id);
  }
}

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

  /// 아이콘을 직접 골랐는지. 아직 안 골랐으면 카테고리를 바꿀 때 그 카테고리 아이콘으로 따라 바뀐다.
  late bool _iconPicked = !widget.isNew;

  /// 카테고리를 전부 펼쳐 보는 중인지 (접혀 있으면 앞의 몇 개와 지금 고른 것만 보인다)
  bool _allCategories = false;

  /// 접혀 있을 때 보여 줄 카테고리 수 ('운동'까지)
  static const _categoryPreview = 5;

  /// 카테고리 칸에 보여 줄 목록. 예전 이름('생활' 등)이 저장된 루틴은 그 이름도 한 칸 보여 준다.
  List<String> get _categories {
    final shown = _allCategories ? routineCategories : routineCategories.take(_categoryPreview).toList();
    return [...shown, if (!shown.contains(r.category)) r.category];
  }

  /// 아이콘을 전부 펼쳐 보는 중인지 (접혀 있으면 고른 카테고리에 어울리는 것만 보인다)
  bool _allIcons = false;

  /// 이모지 뒤의 꾸밈 문자(U+FE0F)를 뗀다 ('🌤️'와 '🌤'를 같은 아이콘으로 본다).
  static String _plain(String e) => String.fromCharCodes(e.runes.where((c) => c != 0xFE0F));

  /// 접혀 있을 때 보여 줄 아이콘 수 (화살표 칸까지 한 줄 6칸)
  static const _iconPreview = 5;

  /// 아이콘 칸에 보여 줄 목록: 펼치면 전부, 접으면 다섯 개.
  /// 카테고리에 어울리는 것을 앞에 놓고 모자란 칸은 전체 목록 순서대로 채운다. 지금 고른 것은 늘 보인다.
  List<String> get _icons {
    if (_allIcons) return routineIconChoices;
    final picked = _plain(r.emoji);
    final suggested = routineCategoryIcons[r.category] ?? const <String>[];
    final shown = [
      ...suggested,
      ...routineIconChoices.where((e) => !suggested.contains(e)),
    ].take(_iconPreview).toList();
    if (!shown.contains(picked) && routineIconChoices.contains(picked)) shown[shown.length - 1] = picked;
    return shown;
  }

  @override
  void dispose() {
    _name.dispose();
    _memo.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && r.weekdays.isNotEmpty;

  Future<void> _pickTime() async {
    final m = r.minuteOfDay ?? 8 * 60;
    // 창에서 시간을 고르거나 "시간 없이, 언제든 할게요"를 고른다.
    final picked = await showTimeSheet(context, initialMinute: m, anytimeLabel: '시간 없이, 언제든 할게요');
    if (picked == null || !mounted) return;
    setState(() {
      if (picked == timeSheetAnytime) {
        r.minuteOfDay = null;
        r.alarmOn = false; // 시간이 없으면 알림도 없다
      } else {
        r.minuteOfDay = picked;
      }
    });
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
            Text('카테고리', style: t.titleMedium),
            const SizedBox(height: Space.sm),
            // 이름 길이가 제각각이라 칸 대신 글자 폭에 맞는 칩으로 흘려 놓는다.
            // 처음에는 앞의 몇 개만 보이고, 끝의 화살표 칸으로 펼치고 접는다.
            _Unfold(
              child: Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final c in _categories)
                    // IntrinsicWidth: 칩이 줄 전체로 늘어나지 않고 내용 폭만 차지하게 한다.
                    IntrinsicWidth(
                      child: _Choice(
                        selected: r.category == c,
                        semantics: '카테고리 $c',
                        onTap: () => setState(() {
                          r.category = c;
                          if (!_iconPicked) r.emoji = routineCategoryEmoji[c] ?? r.emoji;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.md),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (routineCategoryEmoji[c] case final e?) ...[
                                RoutineIcon(e, size: 22),
                                const SizedBox(width: Space.sm),
                              ],
                              Text(c, style: t.labelLarge),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    key: const ValueKey('category-arrow'),
                    width: 48,
                    child: _UnfoldArrow(
                      open: _allCategories,
                      what: '카테고리',
                      onTap: () => setState(() => _allCategories = !_allCategories),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            Text('아이콘', style: t.titleMedium),
            const SizedBox(height: Space.sm),
            _Unfold(
              child: _ChoiceGrid(
                columns: 6,
                children: [
                  for (final e in _icons)
                    _Choice(
                      selected: _plain(r.emoji) == e,
                      onTap: () => setState(() {
                        r.emoji = e;
                        _iconPicked = true;
                      }),
                      semantics: '아이콘 $e',
                      child: RoutineIcon(e, size: 30),
                    ),
                  _UnfoldArrow(
                    key: const ValueKey('icon-arrow'),
                    open: _allIcons,
                    what: '아이콘',
                    onTap: () => setState(() => _allIcons = !_allIcons),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            TextField(
              controller: _name,
              maxLength: 20,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: '루틴 이름', hintText: '예: 물 한 잔 마시기', counterText: ''),
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
                child: Text('요일을 하나 이상 골라주세요', style: t.bodySmall?.copyWith(color: AppColors.primaryInk)),
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
                    trailing: Text(r.minuteOfDay == null ? '설정 안 함' : formatMinute(r.minuteOfDay), style: t.labelLarge),
                    onTap: _pickTime,
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

/// 펼치고 접을 때 높이가 부드럽게 늘고 준다. 새로 드러나는 칸은 위에서부터 차례로 보인다.
class _Unfold extends StatelessWidget {
  const _Unfold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.unfoldDuration,
    curve: AppMotion.unfoldCurve,
    alignment: Alignment.topCenter,
    child: child,
  );
}

/// 펼치기·접기 칸. 아래 화살표가 반 바퀴 돌아 위 화살표가 된다.
class _UnfoldArrow extends StatelessWidget {
  const _UnfoldArrow({super.key, required this.open, required this.what, required this.onTap});
  final bool open;
  final String what;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Choice(
    selected: false,
    onTap: onTap,
    semantics: open ? '$what 접기' : '$what 펼치기',
    child: AnimatedRotation(
      turns: open ? 0.5 : 0,
      duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.unfoldDuration,
      curve: AppMotion.unfoldCurve,
      child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
    ),
  );
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
          color: selected ? AppColors.selected : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: selected ? AppColors.text : AppColors.line, width: 1.5),
        ),
        child: child,
      ),
    ),
  );
}
