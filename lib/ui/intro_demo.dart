import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/tokens.dart';
import 'motion.dart';
import 'room/room_painter.dart';
import 'routine_icon.dart';
import 'widgets.dart';

/// 소개 화면에서 앱이 어떻게 생겼는지 미리 보여 주는 작은 장면들.
///
/// 실제 화면의 조각(루틴 카드, 달성률 원, 미니미)을 줄여서 쓰고, 장이 보일 때 한 번 재생한 뒤 멈춘다.
/// 보여 주기만 하는 그림이라 눌러도 반응하지 않는다. 움직임 줄이기 설정에서는 완성된 모습만 보인다.
abstract class _Demo extends StatefulWidget {
  const _Demo({super.key, required this.active});

  /// 지금 보이는 장인지. 보이게 될 때마다 처음부터 다시 재생한다.
  final bool active;
}

abstract class _DemoState<T extends _Demo> extends State<T> with SingleTickerProviderStateMixin {
  /// 한 장면의 전체 길이 (2초 안쪽)
  static const _length = Duration(milliseconds: 1900);
  late final c = AnimationController(vsync: this, duration: _length);
  bool _started = false;

  void _play() {
    if (AppMotion.reduced(context)) {
      c.value = 1;
    } else {
      c.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && widget.active) {
      _started = true;
      _play();
    }
  }

  @override
  void didUpdateWidget(T old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _started = true;
      _play();
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  /// [from]에서 시작해 [span] 동안 0→1로 가는 값
  double part(double from, [double span = 0.2]) => ((c.value - from) / span).clamp(0.0, 1.0);

  Widget scene(BuildContext context);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(animation: c, builder: (context, _) => scene(context)),
  );
}

/// 아래에서 떠오르며 나타난다.
class _Rise extends StatelessWidget {
  const _Rise({required this.t, required this.child});
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final v = Motion.curve.transform(t);
    return Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
    );
  }
}

/// 1장: 루틴 카드 세 장이 차례로 놓이고, 위에서부터 둘이 체크된다.
class IntroRoutinesDemo extends _Demo {
  const IntroRoutinesDemo({super.key, required super.active});
  @override
  State<IntroRoutinesDemo> createState() => _IntroRoutinesDemoState();
}

class _IntroRoutinesDemoState extends _DemoState<IntroRoutinesDemo> {
  static const _rows = [('🌤', '일어나기', '오전 7:00'), ('💧', '물 한 잔 마시기', '오전 7:10'), ('🍚', '점심 챙겨 먹기', '오후 12:00')];

  @override
  Widget scene(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return IgnorePointer(
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _rows.length; i++) ...[
              if (i > 0) const SizedBox(height: Space.sm),
              _Rise(
                t: part(0.12 * i, 0.22),
                child: _row(t, _rows[i], done: i < 2 && c.value >= 0.58 + 0.2 * i),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(TextTheme t, (String, String, String) r, {required bool done}) => AnimatedContainer(
    duration: Motion.normal,
    padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
    decoration: BoxDecoration(
      color: done ? AppColors.sageSoft.withValues(alpha: 0.55) : AppColors.surface,
      borderRadius: BorderRadius.circular(Radii.md),
      border: Border.all(color: AppColors.line.withValues(alpha: 0.7)),
    ),
    child: Row(
      children: [
        RoutineIcon(r.$1),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.$2, style: t.titleMedium?.copyWith(color: done ? AppColors.textMuted : AppColors.text)),
              Text(r.$3, style: t.bodySmall),
            ],
          ),
        ),
        SpringPop(
          active: done,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.sage : Colors.transparent,
              border: Border.all(color: done ? Colors.transparent : AppColors.line, width: 2),
            ),
            child: done ? const Icon(Icons.check_rounded, size: 20, color: Colors.white) : null,
          ),
        ),
      ],
    ),
  );
}

/// 2장: 달성률 원이 1/3에서 멈추고, 그래도 괜찮다는 한마디가 나온다.
class IntroProgressDemo extends _Demo {
  const IntroProgressDemo({super.key, required super.active});
  @override
  State<IntroProgressDemo> createState() => _IntroProgressDemoState();
}

class _IntroProgressDemoState extends _DemoState<IntroProgressDemo> {
  @override
  Widget scene(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final filled = c.value >= 0.2;
    return IgnorePointer(
      child: SizedBox(
        width: 300,
        child: _Rise(
          t: part(0, 0.2),
          child: Panel(
            child: Row(
              children: [
                ProgressRing(
                  value: filled ? 1 / 3 : 0,
                  size: 92,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(filled ? '1/3' : '0/3', style: t.titleLarge?.copyWith(fontSize: 20)),
                      Text(filled ? '33%' : '0%', style: t.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: _Rise(
                    t: part(0.62, 0.25),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('벌써 1개나 했어요.\n이대로도 잘하고 있어요.', style: t.bodyLarge?.cheer, softWrap: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 3장: 미니미 곁에 가구가 하나씩 놓인다. [onMinimiDoubleTap]은 개발자 모드 진입에 쓴다.
///
/// 가구는 방에서 쓰는 픽셀 그림 그대로다 (미니미와 같은 그림체): 작은 화분, 협탁, 더블 침대.
class IntroRoomDemo extends _Demo {
  const IntroRoomDemo({super.key, required super.active, this.onMinimiDoubleTap});
  final VoidCallback? onMinimiDoubleTap;
  @override
  State<IntroRoomDemo> createState() => _IntroRoomDemoState();
}

class _IntroRoomDemoState extends _DemoState<IntroRoomDemo> {
  static const _plant = 'assets/pixel/furniture/decorations/plant_small_r0.png'; // 64×72
  static const _nightstand = 'assets/pixel/furniture/storage/nightstand_r0.png'; // 64×80
  static const _bed = 'assets/pixel/furniture/beds/bed_double_r1.png'; // 128×120

  /// 제자리에서 뽁 하고 튀어나온다 (조금 넘쳤다가 제자리).
  Widget _furniture(String asset, double w, double h, double from) => IgnorePointer(
    child: Transform.scale(
      scale: Curves.easeOutBack.transform(part(from, 0.22)),
      child: SizedBox(
        child: Image.asset(
          asset,
          width: w,
          height: h,
          filterQuality: FilterQuality.none, // 픽셀이 뭉개지지 않게
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => SizedBox(width: w, height: h),
        ),
      ),
    ),
  );

  @override
  Widget scene(BuildContext context) => SizedBox(
    width: 344,
    height: 196,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        // 미니미는 가운데. 가구는 오른쪽 위 → 왼쪽 가운데 → 오른쪽 아래 순서로 톡톡 튀어나온다.
        Align(alignment: const Alignment(-1, 0.1), child: _furniture(_bed, 128, 120, 0.42)),
        Align(
          alignment: const Alignment(0.12, 0),
          child: GestureDetector(
            key: const ValueKey('intro-minimi'),
            onDoubleTap: widget.onMinimiDoubleTap,
            child: Breathing(child: MinimiView(profile: Profile(), happy: true, width: 120)),
          ),
        ),
        Align(alignment: const Alignment(1, -1), child: _furniture(_nightstand, 64, 80, 0.18)),
        Align(alignment: const Alignment(0.9, 1), child: _furniture(_plant, 64, 72, 0.66)),
      ],
    ),
  );
}
