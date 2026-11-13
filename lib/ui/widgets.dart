import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import '../app.dart';
import '../data/rewards.dart';
import '../theme/tokens.dart';
import 'routine_icon.dart';

/// 흰 바탕의 기본 면. 테두리 없이 종이 위에 놓인 쪽지처럼 보이게 한다.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(Space.lg), this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Material(
    color: color ?? AppColors.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// 둥근 달성률 링.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 112, this.child});
  final double value;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1)),
      duration: Motion.slow,
      curve: Motion.curve,
      builder: (context, v, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(v),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v);
  final double v;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final r = Offset.zero & size;
    final rect = r.deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = AppColors.surfaceMuted
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (v <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * v,
      false,
      Paint()
        ..color = v >= RewardRules.threshold ? AppColors.sage : AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v;
}

/// 레벨 / 코인 작은 칩.
class StatChip extends StatelessWidget {
  const StatChip({super.key, required this.icon, required this.label, required this.color, required this.bg});
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text),
        ),
      ],
  );
}

class LevelChip extends StatelessWidget {
  const LevelChip({super.key});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).profile;
    return StatChip(icon: Icons.eco_rounded, label: 'Lv.${p.level}', color: AppColors.sage, bg: AppColors.sageSoft);
  }
}

class CoinChip extends StatelessWidget {
  const CoinChip({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return StatChip(icon: Icons.circle, label: '${s.profile.coins}', color: AppColors.coin, bg: AppColors.coinSoft);
  }
}

/// 경험치 막대.
class XpBar extends StatelessWidget {
  const XpBar({super.key});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).profile;
    final need = RewardRules.xpToNext(p.level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('다음 레벨까지', style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text('${p.xp} / $need XP', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: Space.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: p.xp / need),
            duration: Motion.slow,
            curve: Motion.curve,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: AppColors.surfaceMuted,
              color: AppColors.sage,
            ),
          ),
        ),
      ],
    );
  }
}

/// 빈 상태 안내.
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.emoji, required this.title, required this.body, this.action});
  final String emoji;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.xxl, horizontal: Space.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RoutineIcon(emoji, size: 64),
        const SizedBox(height: Space.md),
        Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: Space.xs),
        Text(
          body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        if (action != null) ...[const SizedBox(height: Space.lg), action!],
      ],
    ),
  );
}

const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

String formatMinute(int? m) {
  if (m == null) return '언제든';
  final h = m ~/ 60, mm = m % 60;
  final ampm = h < 12 ? '오전' : '오후';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$ampm $h12:${mm.toString().padLeft(2, '0')}';
}

String weekdaySummary(Set<int> d) {
  if (d.length == 7) return '매일';
  if (d.length == 5 && d.containsAll({1, 2, 3, 4, 5})) return '평일';
  if (d.length == 2 && d.containsAll({6, 7})) return '주말';
  final l = d.toList()..sort();
  return l.map((e) => weekdayLabels[e - 1]).join(' ');
}
