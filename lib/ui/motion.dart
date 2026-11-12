import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/tokens.dart';

/// 앱 전체 모션 규칙. 화면에서 곡선·시간을 따로 정하지 말고 여기 것을 쓴다.
///
/// - 스낵바: 아래에서 슬라이드 · 들어올 때 ease-out, 나갈 때 ease-in
/// - 토스트: 제자리 페이드 인/아웃
/// - 팝업: 살짝 커지며(scale) ease-out
/// - 바텀시트: 아래에서 슬라이드 · 배경은 페이드로 어두워짐
/// - 좋아요(체크): 스프링으로 톡 튀는 scale
/// - 로딩: linear로 일정하게 회전
/// - 제목·순서: 한 줄씩 차례로 등장
class AppMotion {
  static const snackIn = Motion.curve;
  static const snackOut = Curves.easeIn;
  static const snackDuration = Duration(milliseconds: 280);
  static const snackReverse = Duration(milliseconds: 220);

  static const toastFade = Duration(milliseconds: 200);

  static const popupIn = Motion.curve;
  static const popupOut = Curves.easeIn;
  static const popupDuration = Duration(milliseconds: 220);
  static const popupFrom = 0.9;

  static const sheetIn = Motion.curve;
  static const sheetOut = Curves.easeIn;
  static const sheetDuration = Duration(milliseconds: 320);
  static const sheetReverse = Duration(milliseconds: 240);
  static const scrim = Color(0x73000000);

  /// 톡 튀는 스프링 (조금 넘쳤다가 돌아옴)
  static const likeSpring = SpringDescription(mass: 1, stiffness: 420, damping: 26);

  static const spinPeriod = Duration(milliseconds: 900);

  static const stagger = Duration(milliseconds: 60);
  static const revealDuration = Duration(milliseconds: 360);
  static const revealCurve = Motion.curve;

  static bool reduced(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

// ───────── 스낵바 ─────────

OverlayEntry? _snackEntry;
GlobalKey<_SnackHostState>? _snackKey;

/// 떠 있는 스낵바를 바로 내린다.
void hideAppSnack() => _snackKey?.currentState?.dismiss(immediate: true);

/// 아래에서 미끄러져 올라오는 스낵바. 같은 때 하나만 보인다.
void showAppSnack(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(milliseconds: 1400),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _snackKey?.currentState?.dismiss(immediate: true);
  final key = GlobalKey<_SnackHostState>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _SnackHost(
      key: key,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      onGone: () {
        entry.remove();
        if (identical(_snackEntry, entry)) {
          _snackEntry = null;
          _snackKey = null;
        }
      },
    ),
  );
  _snackEntry = entry;
  _snackKey = key;
  overlay.insert(entry);
}

class _SnackHost extends StatefulWidget {
  const _SnackHost({
    super.key,
    required this.message,
    required this.duration,
    required this.onGone,
    this.actionLabel,
    this.onAction,
  });
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onGone;

  @override
  State<_SnackHost> createState() => _SnackHostState();
}

class _SnackHostState extends State<_SnackHost> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: AppMotion.snackDuration,
    reverseDuration: AppMotion.snackReverse,
  );
  late final _slide = Tween(
    begin: const Offset(0, 1.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: AppMotion.snackIn, reverseCurve: AppMotion.snackOut));
  Timer? _timer;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(widget.duration, dismiss);
  }

  Future<void> dismiss({bool immediate = false}) async {
    if (_gone) return;
    _gone = true;
    _timer?.cancel();
    if (!immediate && mounted) await _c.reverse();
    widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom + 84; // 하단 탭 위
    return Positioned(
      left: Space.gutter,
      right: Space.gutter,
      bottom: bottom,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: AppColors.text,
          elevation: 6,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.xs, Space.xs),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.message, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
                  ),
                  if (widget.actionLabel != null)
                    TextButton(
                      onPressed: () {
                        widget.onAction?.call();
                        dismiss();
                      },
                      child: Text(widget.actionLabel!, style: const TextStyle(color: AppColors.primarySoft)),
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

// ───────── 토스트 ─────────

OverlayEntry? _toastEntry;

/// 제자리에서 페이드로 나타났다 사라지는 짧은 알림.
void showAppToast(BuildContext context, String message, {Duration hold = const Duration(milliseconds: 1600)}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _toastEntry?.remove();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastHost(
      message: message,
      hold: hold,
      onGone: () {
        entry.remove();
        if (identical(_toastEntry, entry)) _toastEntry = null;
      },
    ),
  );
  _toastEntry = entry;
  overlay.insert(entry);
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({required this.message, required this.hold, required this.onGone});
  final String message;
  final Duration hold;
  final VoidCallback onGone;
  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: AppMotion.toastFade);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(widget.hold, () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onGone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom + 96;
    return Positioned(
      left: Space.gutter,
      right: Space.gutter,
      bottom: bottom,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _c,
            child: Material(
              color: AppColors.text.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(99),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                child: Text(widget.message, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────── 팝업 ─────────

/// 살짝 커지며 나오는 팝업 (scale + ease-out). 배경은 페이드로 어두워진다.
Future<T?> showAppDialog<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  hideAppSnack(); // 스낵바가 팝업 버튼을 가리지 않게
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: AppMotion.scrim,
    transitionDuration: AppMotion.popupDuration,
    pageBuilder: (ctx, _, _) => SafeArea(child: Builder(builder: builder)),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: AppMotion.popupIn, reverseCurve: AppMotion.popupOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: AppMotion.reduced(ctx) ? 1.0 : AppMotion.popupFrom, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

// ───────── 바텀시트 ─────────

/// 아래에서 올라오는 바텀시트. 뒤 배경은 페이드로 어두워진다.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool showDragHandle = true,
  bool isScrollControlled = true,
}) {
  hideAppSnack(); // 스낵바가 시트 버튼을 가리지 않게
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    backgroundColor: AppColors.background,
    showDragHandle: showDragHandle,
    isScrollControlled: isScrollControlled,
    barrierColor: AppMotion.scrim,
    sheetAnimationStyle: const AnimationStyle(
      duration: AppMotion.sheetDuration,
      reverseDuration: AppMotion.sheetReverse,
      curve: AppMotion.sheetIn,
      reverseCurve: AppMotion.sheetOut,
    ),
  );
}

// ───────── 좋아요(체크) 스프링 ─────────

/// [active]가 true가 되는 순간 스프링으로 톡 튀며 커진다. 꺼질 때는 조용히 줄어든다.
class SpringPop extends StatefulWidget {
  const SpringPop({super.key, required this.active, required this.child, this.restScale = 0.86});
  final bool active;
  final Widget child;
  final double restScale;

  @override
  State<SpringPop> createState() => _SpringPopState();
}

class _SpringPopState extends State<SpringPop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController.unbounded(vsync: this, value: widget.active ? 1.0 : widget.restScale);

  @override
  void didUpdateWidget(SpringPop old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;
    if (AppMotion.reduced(context)) {
      _c.value = widget.active ? 1.0 : widget.restScale;
    } else if (widget.active) {
      // 작게 눌렸다가 스프링으로 튀어 오름
      _c.value = 0.6;
      _c.animateWith(SpringSimulation(AppMotion.likeSpring, 0.6, 1.0, 4));
    } else {
      _c.animateTo(widget.restScale, duration: Motion.fast, curve: Curves.easeIn);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Transform.scale(scale: _c.value, child: child),
    child: widget.child,
  );
}

// ───────── 로딩 ─────────

/// 일정한 속도(linear)로 계속 도는 로딩 표시.
class AppSpinner extends StatefulWidget {
  const AppSpinner({super.key, this.size = 22, this.color = AppColors.text});
  final double size;
  final Color color;
  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: AppMotion.spinPeriod)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '불러오는 중',
    child: RotationTransition(
      turns: _c, // AnimationController 기본 곡선이 linear
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: _ArcPainter(widget.color)),
      ),
    ),
  );
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.12;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 0.6,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}

// ───────── 제목·순서: 한 줄씩 ─────────

/// [index]번째 줄로 차례를 기다렸다가 아래에서 살짝 올라오며 나타난다.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  /// 위젯 목록에 차례 번호를 매겨 감싼다.
  static List<Widget> lines(List<Widget> children, {int start = 0}) => [
    for (var i = 0; i < children.length; i++) Reveal(index: start + i, child: children[i]),
  ];

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: AppMotion.revealDuration);
  late final _curved = CurvedAnimation(parent: _c, curve: AppMotion.revealCurve);
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status != AnimationStatus.dismissed || _timer != null) return;
    if (AppMotion.reduced(context)) {
      _c.value = 1;
      return;
    }
    _timer = Timer(AppMotion.stagger * widget.index, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curved,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(_curved),
      child: widget.child,
    ),
  );
}

/// 숨 쉬듯 위아래로 살짝 움직인다. '동작 줄이기'가 켜져 있으면 가만히 있는다.
class Breathing extends StatefulWidget {
  const Breathing({super.key, required this.child});
  final Widget child;

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing> with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: _breath,
      builder: (_, child) =>
          Transform.translate(offset: Offset(0, reduceMotion ? 0 : -2 * _breath.value), child: child),
      child: widget.child,
    );
  }
}
