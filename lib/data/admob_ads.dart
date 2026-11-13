import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';
import 'ads.dart';

/// AdMob 보상형 광고.
///
/// - 광고 하나를 미리 불러 두었다가 버튼을 누르면 바로 띄운다. 닫히면 다음 광고를 다시 불러 둔다.
/// - 끝까지 봐서 AdMob 이 보상을 알려 준 경우에만 [AdOutcome.earned].
/// - 광고 단위 ID는 [AdConfig] 에서 고른다 (디버그 빌드는 늘 Google 테스트 광고).
class AdMobRewardAds implements RewardAds {
  AdMobRewardAds() {
    if (available) unawaited(_start());
  }

  final String? _unitId = AdConfig.rewardedUnitId;
  RewardedAd? _ad;
  Completer<void>? _loading;

  /// 광고를 기다리는 가장 긴 시간. 넘으면 '지금은 불러올 수 없어요'로 끝낸다.
  static const _loadTimeout = Duration(seconds: 12);

  @override
  bool get available => _unitId != null;

  Future<void> _start() async {
    try {
      await MobileAds.instance.initialize();
      preload();
    } catch (e) {
      debugPrint('ads init failed: $e');
    }
  }

  @override
  void preload() {
    if (!available || _ad != null || _loading != null) return;
    final done = _loading = Completer<void>();
    RewardedAd.load(
      adUnitId: _unitId!,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = null;
          done.complete();
        },
        onAdFailedToLoad: (e) {
          debugPrint('rewarded ad failed to load: ${e.message}');
          _loading = null;
          done.complete();
        },
      ),
    ).catchError((Object e) {
      debugPrint('rewarded ad load error: $e');
      _loading = null;
      if (!done.isCompleted) done.complete();
    });
  }

  @override
  Future<AdOutcome> show() async {
    if (!available) return AdOutcome.unavailable;
    if (_ad == null) {
      preload();
      try {
        await _loading?.future.timeout(_loadTimeout);
      } on TimeoutException {
        return AdOutcome.unavailable;
      }
    }
    final ad = _ad;
    if (ad == null) return AdOutcome.unavailable;
    _ad = null;

    final result = Completer<AdOutcome>();
    var earned = false;
    void finish(AdOutcome o) {
      if (!result.isCompleted) result.complete(o);
      ad.dispose();
      preload(); // 다음에 바로 볼 수 있게
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => finish(earned ? AdOutcome.earned : AdOutcome.closedEarly),
      onAdFailedToShowFullScreenContent: (_, e) {
        debugPrint('rewarded ad failed to show: ${e.message}');
        finish(AdOutcome.unavailable);
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
    } catch (e) {
      debugPrint('rewarded ad show error: $e');
      finish(AdOutcome.unavailable);
    }
    return result.future;
  }
}
