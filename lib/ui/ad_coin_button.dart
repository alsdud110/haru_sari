import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../app.dart';
import '../data/ads.dart';
import '../data/rewards.dart';
import '../theme/tokens.dart';
import 'motion.dart';
import 'routine_icon.dart';

/// '광고 보고 코인 받기' 버튼. 남은 횟수를 (5/5)처럼 함께 보여 준다.
///
/// - 하루 [AdRules.perDay]번. 다 보면 눌리지 않고 내일 다시 볼 수 있다고 알려 준다.
/// - 끝까지 본 광고만 코인을 준다. 중간에 닫거나 광고를 못 불러오면 횟수는 줄지 않는다.
/// - 광고를 쓸 수 없는 빌드(광고 단위 없음, 테스트)에서는 아무것도 그리지 않는다.
class AdCoinButton extends StatefulWidget {
  const AdCoinButton({super.key});

  @override
  State<AdCoinButton> createState() => _AdCoinButtonState();
}

class _AdCoinButtonState extends State<AdCoinButton> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 버튼이 보이는 동안 광고를 미리 불러 둔다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).ads.preload();
    });
  }

  Future<void> _watch() async {
    final s = AppScope.read(context);
    setState(() => _busy = true);
    final outcome = await s.ads.show();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (outcome) {
      case AdOutcome.earned:
        if (s.grantAdReward()) {
          HapticFeedback.mediumImpact();
          showAppToast(context, '코인 ${AdRules.coins}개를 받았어요');
        }
      case AdOutcome.closedEarly:
        showAppToast(context, '끝까지 보면 코인을 받을 수 있어요');
      case AdOutcome.unavailable:
        showAppToast(context, '지금은 광고를 불러올 수 없어요. 잠시 뒤 다시 해 주세요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (!s.ads.available) return const SizedBox.shrink();
    final left = s.adsLeftToday;
    final count = '($left/${AdRules.perDay})';
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: left == 0 || _busy ? null : _watch,
        child: _busy
            ? const AppSpinner()
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 앱 그림 스티커: 볼 수 있을 때는 재생 버튼, 다 봤으면 달 (내일 다시)
                  if (left == 0)
                    const Opacity(opacity: 0.6, child: RoutineIcon('🌙', size: 22))
                  else
                    Image.asset(
                      'assets/icons/play.png',
                      width: 24,
                      height: 24,
                      filterQuality: FilterQuality.medium,
                      excludeFromSemantics: true,
                    ),
                  const SizedBox(width: Space.sm),
                  Flexible(
                    child: Text(
                      left == 0 ? '오늘 광고는 다 봤어요 $count' : '광고 보고 코인 ${AdRules.coins}개 받기 $count',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
