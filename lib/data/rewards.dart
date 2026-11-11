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
