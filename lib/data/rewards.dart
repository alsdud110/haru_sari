/// 보상 규칙 (manyfast 정책 PL-BBQESH).
/// 수치는 정책에서 바뀌면 여기만 고친다.
class RewardRules {
  /// 하루 보상을 받는 달성률 기준. (PL-BBQESH: 70% 이상)
  static const threshold = 0.7;
  static const baseXp = 20;
  static const baseCoins = 10;
  static const perfectBonusXp = 10;
  static const perfectBonusCoins = 5;
  static const levelUpCoins = 20;

  static int xpToNext(int level) => level * 50;
}

/// 광고 보상 규칙. 광고를 끝까지 보면 코인을 받는다 (경험치는 주지 않는다).
/// 서버(claim_ad_reward)도 같은 값으로 지급하고 하루 횟수를 지킨다.
class AdRules {
  /// 하루에 볼 수 있는 횟수
  static const perDay = 3;

  /// 한 번 볼 때 받는 코인. 세 번 다 보면 15코인으로, 하루를 모두 해낸 날의 코인과 같다
  /// (루틴이 여전히 코인의 주된 길이 되게 그보다 크게 잡지 않는다).
  static const coins = 5;
}

class DailyReward {
  const DailyReward({
    required this.xp,
    required this.coins,
    required this.perfect,
    required this.levelsGained,
    required this.newLevel,
  });
  final int xp;
  final int coins;
  final bool perfect;
  final int levelsGained;
  final int newLevel;

  bool get leveledUp => levelsGained > 0;
}

/// 달성률로 하루 보상을 계산한다. 기준 미달이면 null.
({int xp, int coins, bool perfect})? rewardFor(double rate) {
  if (rate < RewardRules.threshold) return null;
  final perfect = rate >= 1.0;
  return (
    xp: RewardRules.baseXp + (perfect ? RewardRules.perfectBonusXp : 0),
    coins: RewardRules.baseCoins + (perfect ? RewardRules.perfectBonusCoins : 0),
    perfect: perfect,
  );
}

/// 경험치를 더하고 레벨업을 처리한 결과.
({int level, int xp, int levelsGained}) addXp(int level, int xp, int gained) {
  var l = level;
  var x = xp + gained;
  var ups = 0;
  while (x >= RewardRules.xpToNext(l)) {
    x -= RewardRules.xpToNext(l);
    l++;
    ups++;
  }
  return (level: l, xp: x, levelsGained: ups);
}
