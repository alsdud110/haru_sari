/// 보상형 광고. 실제는 AdMobRewardAds(admob_ads.dart), 테스트는 가짜를 쓴다.
///
/// 광고를 끝까지 본 것([AdOutcome.earned])만 보상한다. 코인을 주는 일은 AppState.grantAdReward 가 한다.
library;

enum AdOutcome {
  /// 끝까지 봤다 → 보상한다
  earned,

  /// 중간에 닫았다 → 보상하지 않는다
  closedEarly,

  /// 광고를 불러오지 못했다 (연결 없음, 보여 줄 광고 없음 등)
  unavailable,
}

abstract class RewardAds {
  /// 이 기기·빌드에서 광고를 쓸 수 있는지. false 면 광고 버튼을 보여 주지 않는다.
  bool get available;

  /// 광고를 미리 불러 둔다 (버튼을 누르면 바로 뜨게). 여러 번 불러도 된다.
  void preload();

  /// 광고를 띄우고 닫힐 때까지 기다린다.
  Future<AdOutcome> show();
}

/// 광고 없음 (테스트, 광고 단위를 아직 넣지 않은 빌드).
class NoRewardAds implements RewardAds {
  const NoRewardAds();
  @override
  bool get available => false;
  @override
  void preload() {}
  @override
  Future<AdOutcome> show() async => AdOutcome.unavailable;
}
