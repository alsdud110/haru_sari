import 'models.dart';

/// 배지. 연속 기록은 쓰지 않는다 — 끊겨도 잃지 않는 누적·순간만 기념한다 (PRD 원칙).
class BadgeDef {
  const BadgeDef(this.id, this.emoji, this.name, this.desc);
  final String id;
  final String emoji;
  final String name;
  final String desc;
}

const badgeDefs = <BadgeDef>[
  BadgeDef('first_check', '🌱', '첫 기록', '처음으로 루틴 하나를 체크했어요'),
  BadgeDef('first_day', '🌤️', '해낸 하루', '처음으로 하루 몫을 해냈어요'),
  BadgeDef('perfect_day', '🌕', '온전한 하루', '하루 루틴을 모두 마쳤어요'),
  BadgeDef('comeback', '🌈', '다시 시작', '며칠 쉬었다가 다시 기록했어요'),
  BadgeDef('days_10', '🍀', '10일의 하루들', '기록한 날이 10일 쌓였어요'),
  BadgeDef('days_30', '🌳', '30일의 하루들', '기록한 날이 30일 쌓였어요'),
  BadgeDef('days_100', '🏡', '100일의 하루들', '기록한 날이 100일 쌓였어요'),
  BadgeDef('first_item', '🛋️', '첫 살림', '처음으로 방에 무언가를 들였어요'),
  BadgeDef('room_5', '🪴', '제법 내 방', '방에 가구 5개를 놓았어요'),
  BadgeDef('first_outfit', '👕', '새 옷', '미니미에게 처음 옷을 입혔어요'),
  BadgeDef('level_5', '⭐', '레벨 5', '레벨 5가 되었어요'),
  BadgeDef('level_10', '🌟', '레벨 10', '레벨 10이 되었어요'),
];

BadgeDef? badgeById(String id) {
  for (final b in badgeDefs) {
    if (b.id == id) return b;
  }
  return null;
}

/// 지금 상태로 새로 받을 수 있는 배지 id들.
List<String> newlyEarned({required Profile profile, required Map<String, DayLog> logs, required String todayKey}) {
  final has = profile.badges.containsKey;
  final out = <String>[];
  void check(String id, bool cond) {
    if (!has(id) && cond) out.add(id);
  }

  final recordedDays = logs.values.where((l) => l.done > 0).map((l) => l.date).toList()..sort();
  final today = logs[todayKey];

  check('first_check', recordedDays.isNotEmpty);
  check('first_day', logs.values.any((l) => l.rewarded));
  check('perfect_day', logs.values.any((l) => l.total > 0 && l.done == l.total));
  check('days_10', recordedDays.length >= 10);
  check('days_30', recordedDays.length >= 30);
  check('days_100', recordedDays.length >= 100);

  // 오늘 기록했고, 그 직전 기록일과 3일 이상 떨어져 있으면 '다시 시작'
  if (today != null && today.done > 0) {
    final before = recordedDays.where((d) => d.compareTo(todayKey) < 0).toList();
    if (before.isNotEmpty) {
      final gap = parseDateKey(todayKey).difference(parseDateKey(before.last)).inDays;
      check('comeback', gap >= 4);
    }
  }

  final placedFurniture = profile.placed.length;
  check('first_item', profile.owned.isNotEmpty);
  check('room_5', placedFurniture >= 5);
  check('first_outfit', profile.outfitId != null);
  check('level_5', profile.level >= 5);
  check('level_10', profile.level >= 10);
  return out;
}
