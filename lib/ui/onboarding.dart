import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../app.dart';
import '../data/catalog.dart';
import '../data/models.dart';
import '../room/registry.dart';
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
                    child: MinimiPicker(minimi: minimi, onChanged: onChanged),
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
  double get maxExtent => 168;
  @override
  double get minExtent => 132;

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

/// 미니미 꾸미기: 헤어·얼굴·옷 탭. 고를 것마다 그 모습의 미리보기를 보여 줘서 눌러 보지 않아도 고를 수 있다.
/// 첫 설정과 설정 화면에서 같이 쓴다.
class MinimiPicker extends StatefulWidget {
  const MinimiPicker({
    super.key,
    required this.minimi,
    required this.onChanged,
    this.fill = false,
    this.clothes = const [],
    this.top,
    this.bottom,
    this.itemColors = const {},
    this.onDress,
  });
  final Minimi minimi;
  final ValueChanged<Minimi> onChanged;

  /// 산 옷 (상의·하의·원피스). 기본 옷과 같은 칸에 상점 표시를 달고 보여 준다
  final List<ShopItem> clothes;

  /// 입은 산 옷 (없으면 기본 옷)과 산 옷에 고른 색
  final String? top, bottom;
  final Map<String, int> itemColors;

  /// 입을 옷·산 옷 색이 바뀔 때 (상의, 하의, 색). 없으면 산 옷을 보이지 않는다 (첫 설정)
  final void Function(String? top, String? bottom, Map<String, int> colors)? onDress;

  /// 남은 높이를 채우고 탭은 위에 둔 채 고르는 칸만 넘겨 본다 (꾸미기 페이지). 아니면 부모가 통째로 넘긴다 (첫 설정).
  final bool fill;

  @override
  State<MinimiPicker> createState() => _MinimiPickerState();
}

enum _Tab { hair, face, outfit }

/// 썸네일에서 보여 줄 부분 (미니미 그림 높이 대비 위·아래 비율)
typedef _Crop = (double, double);
const _Crop _hairCrop = (0, 0.74), _faceCrop = (0.18, 0.52), _topCrop = (0.5, 0.77), _bottomCrop = (0.66, 1);
const _Crop _setCrop = (0.5, 1);

class _MinimiPickerState extends State<MinimiPicker> {
  var _tab = _Tab.hair;

  Minimi get m => widget.minimi;
  void _set(Minimi v) => widget.onChanged(v);

  /// 피부는 그대로 두고 나머지를 아무렇게나 골라 본다. 옷은 기본 옷과 산 옷 중에서 같은 확률로 고른다.
  void _shuffle() {
    final r = math.Random();
    int pick(int n) => r.nextInt(n);
    HapticFeedback.selectionClick();
    final tops = _clothes.where((i) => !i.isBottom).toList(), bottoms = _clothes.where((i) => i.isBottom).toList();
    // 상의: 기본 티셔츠 무늬 5칸 + 산 상의·원피스 / 하의: 기본 하의 8칸 + 산 하의 (화면의 칸 하나하나가 같은 확률)
    final t = pick(Minimi.patternNames.length + tops.length);
    final b = pick(Minimi.bottomNames.length + bottoms.length);
    final top = t < Minimi.patternNames.length ? null : tops[t - Minimi.patternNames.length];
    final bottom = (top?.isSet ?? false) || b < Minimi.bottomNames.length
        ? null
        : bottoms[b - Minimi.bottomNames.length];
    _set(
      m.copyWith(
        hairStyle: Minimi.hairStyleOrder[pick(Minimi.hairStyleOrder.length)],
        hair: pick(Minimi.hairNames.length),
        eyes: pick(Minimi.eyeNames.length),
        mouth: pick(Minimi.mouthNames.length),
        outfit: pick(Minimi.outfitNames.length),
        pattern: t < Minimi.patternNames.length ? t : pick(Minimi.patternNames.length),
        bottom: b < Minimi.bottomNames.length ? b : pick(Minimi.bottomNames.length),
        bottomColor: pick(Minimi.bottomColorNames.length),
      ),
    );
    if (!_shop) return;
    // 산 옷 색도 섞는다 (원래 색 포함)
    final colors = {...widget.itemColors};
    for (final i in [top, bottom].nonNulls) {
      final c = pick(Minimi.outfitNames.length + 1);
      c == 0 ? colors.remove(i.id) : colors[i.id] = c - 1;
    }
    _dress(top?.id, bottom?.id, colors);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = Row(
      children: [
        Expanded(child: _tabs()),
        const SizedBox(width: Space.sm),
        IconButton.outlined(
          tooltip: '아무렇게나 꾸며 보기',
          onPressed: _shuffle,
          style: IconButton.styleFrom(side: const BorderSide(color: AppColors.line)),
          icon: const Icon(Icons.casino_outlined),
        ),
      ],
    );
    // 탭마다 따로 둔다: 같은 자리의 동그라미가 썸네일로 늘어나는 애니메이션이 생기지 않게
    final content = KeyedSubtree(
      key: ValueKey(_tab),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _options()),
    );
    if (!widget.fill) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tabs, content]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tabs,
        Expanded(
          child: SingleChildScrollView(
            key: PageStorageKey(_tab),
            padding: const EdgeInsets.only(bottom: Space.lg),
            child: content,
          ),
        ),
      ],
    );
  }

  Widget _tabs() {
    const labels = {_Tab.hair: '헤어', _Tab.face: '얼굴', _Tab.outfit: '옷'};
    if (isApple) {
      return CupertinoSlidingSegmentedControl<_Tab>(
        groupValue: _tab,
        backgroundColor: AppColors.surfaceMuted,
        thumbColor: AppColors.surface,
        children: {
          for (final e in labels.entries)
            e.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Text(e.value),
            ),
        },
        onValueChanged: (v) => setState(() => _tab = v ?? _tab),
      );
    }
    return SegmentedButton<_Tab>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.selected,
        side: const BorderSide(color: AppColors.line),
      ),
      segments: [for (final e in labels.entries) ButtonSegment(value: e.key, label: Text(e.value))],
      selected: {_tab},
      onSelectionChanged: (v) => setState(() => _tab = v.first),
    );
  }

  List<Widget> _options() => switch (_tab) {
    _Tab.hair => [
      _title('스타일'),
      _thumbs([
        for (final i in Minimi.hairStyleOrder) (Minimi.hairStyleNames[i], m.copyWith(hairStyle: i), i == m.hairStyle),
      ], _hairCrop),
      _title('머리색', Minimi.hairNames[m.hair % Minimi.hairNames.length]),
      _swatches(hairColors, m.hair, Minimi.hairNames, (i) => _set(m.copyWith(hair: i))),
    ],
    _Tab.face => [
      _title('피부', Minimi.skinNames[m.skin % Minimi.skinNames.length]),
      _swatches(skinTones, m.skin, Minimi.skinNames, (i) => _set(m.copyWith(skin: i))),
      _title('눈'),
      _thumbs([
        for (var i = 0; i < Minimi.eyeNames.length; i++) (Minimi.eyeNames[i], m.copyWith(eyes: i), i == m.eyes),
      ], _faceCrop),
      _title('입'),
      _thumbs([
        for (var i = 0; i < Minimi.mouthNames.length; i++) (Minimi.mouthNames[i], m.copyWith(mouth: i), i == m.mouth),
      ], _faceCrop),
    ],
    _Tab.outfit => _outfitOptions(),
  };

  bool get _shop => widget.onDress != null;
  List<ShopItem> get _clothes => _shop ? widget.clothes : const [];
  ShopItem? _worn(String? id) => _clothes.where((i) => i.id == id).firstOrNull;
  void _dress(String? top, String? bottom, [Map<String, int>? colors]) =>
      widget.onDress?.call(top, bottom, colors ?? widget.itemColors);

  /// 옷 탭: 상의(기본 티셔츠 + 산 상의·원피스) → 색 → 무늬, 하의(기본 하의 + 산 하의) → 색
  List<Widget> _outfitOptions() {
    final top = _worn(widget.top), bottom = _worn(widget.bottom);
    final setOn = top?.isSet ?? false; // 원피스·세트를 입으면 하의 없음
    // 옷 썸네일은 긴 머리가 옷을 가리지 않게 짧은 머리로 보여 준다
    Profile look({Minimi? mm, String? t, String? b}) =>
        Profile(minimi: (mm ?? m).copyWith(hairStyle: 1), outfitId: t, bottomId: b, itemColors: widget.itemColors);
    return [
      _title('상의'),
      _grid(cell: 76, gap: Space.sm, [
        // 산 옷이 앞, 기본 옷은 뒤로 (살수록 기본 옷이 밀려난다)
        for (final i in _clothes.where((i) => !i.isBottom))
          _tile(
            name: i.name,
            selected: i.id == top?.id,
            shop: true,
            onTap: () => _dress(i.id, i.isSet ? null : bottom?.id),
            child: _CroppedMinimi(look(t: i.id), i.isSet ? _setCrop : _topCrop),
          ),
        // 기본 티셔츠는 무늬마다 한 칸씩 (색은 아래에서)
        for (var i = 0; i < Minimi.patternNames.length; i++)
          _tile(
            name: '${Minimi.patternNames[i]} 티셔츠',
            selected: top == null && m.pattern == i,
            onTap: () {
              _set(m.copyWith(pattern: i));
              if (top != null) _dress(null, bottom?.id);
            },
            child: _CroppedMinimi(look(mm: m.copyWith(pattern: i)), _topCrop),
          ),
      ]),
      ..._colors('상의 색상', top, outfitColors, Minimi.outfitNames, m.outfit, (i) => _set(m.copyWith(outfit: i))),
      _title('하의', setOn ? '원피스·세트를 입는 동안에는 하의가 없어요' : null),
      _grid(cell: 76, gap: Space.sm, [
        for (final i in _clothes.where((i) => i.isBottom))
          _tile(
            name: i.name,
            selected: i.id == bottom?.id,
            shop: true,
            onTap: () => _dress(setOn ? null : top?.id, i.id),
            child: _CroppedMinimi(look(b: i.id), _bottomCrop),
          ),
        for (var i = 0; i < Minimi.bottomNames.length; i++)
          _tile(
            name: Minimi.bottomNames[i],
            selected: !setOn && bottom == null && m.bottom == i,
            onTap: () {
              _set(m.copyWith(bottom: i));
              if (setOn || bottom != null) _dress(setOn ? null : top?.id, null);
            },
            child: _CroppedMinimi(look(mm: m.copyWith(bottom: i)), _bottomCrop),
          ),
      ]),
      if (!setOn)
        ..._colors(
          '하의 색상',
          bottom,
          bottomColors,
          Minimi.bottomColorNames,
          m.bottomColor,
          (i) => _set(m.copyWith(bottomColor: i)),
        ),
    ];
  }

  /// 색 고르기. 기본 옷이면 기본 옷 색, 산 옷이면 원래 색 + 기본 옷 색 12가지
  List<Widget> _colors(
    String label,
    ShopItem? item,
    List<Color> colors,
    List<String> names,
    int sel,
    ValueChanged<int> onDefault,
  ) {
    if (item == null) {
      return [_title(label, names[sel % names.length]), _swatches(colors, sel, names, onDefault)];
    }
    final picked = widget.itemColors[item.id];
    final original = RegistryScope.of(context)?.manifest[item.id]?.recolor?[1] ?? 0xEADBC7;
    return [
      _title(
        label,
        '${item.name} · ${picked == null ? '원래 색' : Minimi.outfitNames[picked % Minimi.outfitNames.length]}',
      ),
      _swatches(
        [Color(0xFF000000 | original), ...outfitColors],
        picked == null ? 0 : picked % outfitColors.length + 1,
        ['원래 색', ...Minimi.outfitNames],
        firstIcon: Icons.replay_rounded, // 원래 색: 같은 색 동그라미와 헷갈리지 않게
        (i) {
          final next = {...widget.itemColors};
          i == 0 ? next.remove(item.id) : next[item.id] = i - 1; // 0번 = 원래 색
          _dress(widget.top, widget.bottom, next);
        },
      ),
    ];
  }

  Widget _title(String label, [String? value]) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg, bottom: Space.sm),
      child: Row(
        children: [
          Text(label, style: t.titleMedium),
          if (value != null) ...[const SizedBox(width: Space.sm), Text(value, style: t.bodySmall)],
        ],
      ),
    );
  }

  /// 고를 것마다 그 모습의 미니미 일부를 보여 준다. 누르면 [options]의 모습으로 바뀐다.
  Widget _thumbs(List<(String, Minimi, bool)> options, _Crop crop) => _grid(cell: 76, gap: Space.sm, [
    for (final (name, look, selected) in options)
      _tile(
        name: name,
        selected: selected,
        onTap: () => _set(look),
        child: _CroppedMinimi(Profile(minimi: look), crop),
      ),
  ]);

  /// 썸네일 한 칸. [shop]이면 오른쪽 위에 작은 상점 표시를 단다 (기본 옷과 구별)
  Widget _tile({
    required String name,
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
    bool shop = false,
  }) => Semantics(
    // 칸이 밀려 같은 자리에 색 동그라미가 오더라도 서로 재사용하지 않게 (원↔둥근 네모 애니메이션은 깨진다)
    key: ValueKey(('tile', name)),
    button: true,
    selected: selected,
    label: shop ? '$name, 산 옷' : name,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.only(bottom: Space.xs),
        decoration: BoxDecoration(
          color: selected ? AppColors.selected : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: selected ? AppColors.text : AppColors.line, width: selected ? 2 : 1),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                ExcludeSemantics(child: child),
                Text(name, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
            if (shop) const Positioned(top: 4, right: 4, child: _ShopBadge()),
          ],
        ),
      ),
    ),
  );

  Widget _swatches(List<Color> colors, int sel, List<String> names, ValueChanged<int> onPick, {IconData? firstIcon}) =>
      _grid(cell: 40, gap: Space.md, [
        for (var i = 0; i < colors.length; i++)
          Semantics(
            key: ValueKey(('swatch', names[i])),
            button: true,
            selected: i == sel % colors.length,
            label: names[i],
            child: GestureDetector(
              onTap: () => onPick(i),
              child: AnimatedContainer(
                duration: Motion.fast,
                height: 48,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  // 밝은 색도 바탕과 구분되게 옅은 테두리를 둔다
                  border: Border.all(
                    color: i == sel % colors.length ? AppColors.text : AppColors.line,
                    width: i == sel % colors.length ? 2.5 : 1,
                  ),
                ),
                child: i == 0 && firstIcon != null ? Icon(firstIcon, size: 20, color: AppColors.text) : null,
              ),
            ),
          ),
      ]);

  /// 칸을 폭에 맞게 나눠([cell] 이상) 양 끝을 위 탭·아래 버튼과 맞춘다
  Widget _grid(List<Widget> cells, {required double cell, required double gap}) => LayoutBuilder(
    builder: (context, c) {
      final n = math.max(1, ((c.maxWidth + gap) / (cell + gap)).floor());
      final w = ((c.maxWidth - gap * (n - 1)) / n).floorToDouble(); // 반올림으로 줄이 일찍 넘어가지 않게 내림
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final x in cells) SizedBox(width: w, child: x)],
      );
    },
  );
}

/// 미니미 그림의 [crop] 부분만 64px 높이로 키워 보여 준다.
class _CroppedMinimi extends StatelessWidget {
  const _CroppedMinimi(this.profile, this.crop);
  final Profile profile;
  final _Crop crop;

  static const _h = 64.0;

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = crop;
    final figure = _h / (bottom - top); // 미니미 그림 전체 높이
    final width = figure / 1.2; // MinimiView 높이 = 너비 × 1.2
    return SizedBox(
      height: _h,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxWidth: width,
          maxHeight: figure,
          child: Transform.translate(
            offset: Offset(0, -top * figure),
            child: MinimiView(profile: profile, width: width),
          ),
        ),
      ),
    );
  }
}

/// 상점에서 산 옷 표시 (썸네일 오른쪽 위): 코인 색 동그라미 안 상점 아이콘
class _ShopBadge extends StatelessWidget {
  const _ShopBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: const BoxDecoration(color: AppColors.coinSoft, shape: BoxShape.circle),
    child: const Icon(Icons.storefront_rounded, size: 11, color: AppColors.text),
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
