/// 루틴 카테고리.
const routineCategories = ['생활', '건강', '식사', '이동', '마음', '기타'];

/// 루틴: 사용자가 반복하는 일상 활동 하나.
class Routine {
  Routine({
    required this.id,
    required this.name,
    required this.emoji,
    this.minuteOfDay,
    Set<int>? weekdays,
    this.alarmOn = false,
    this.category = '생활',
    this.memo = '',
    this.active = true,
  }) : weekdays = weekdays ?? {1, 2, 3, 4, 5, 6, 7};

  final String id;
  String name;
  String emoji;

  /// 실행 예정 시각(0~1439분). null이면 '언제든'.
  int? minuteOfDay;

  /// DateTime.weekday 기준 1(월)~7(일).
  Set<int> weekdays;
  bool alarmOn;
  String category;

  /// 한 줄 메모 (선택)
  String memo;

  /// 꺼 두면 잠시 쉬는 루틴: 오늘 목록과 알림에서 빠진다.
  bool active;

  bool runsOn(DateTime day) => active && weekdays.contains(day.weekday);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'minute': minuteOfDay,
    'weekdays': weekdays.toList()..sort(),
    'alarmOn': alarmOn,
    'category': category,
    'memo': memo,
    'active': active,
  };

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
    id: j['id'] as String,
    name: j['name'] as String,
    emoji: j['emoji'] as String? ?? '✨',
    minuteOfDay: j['minute'] as int?,
    weekdays: (j['weekdays'] as List).cast<int>().toSet(),
    alarmOn: j['alarmOn'] as bool? ?? false,
    category: j['category'] as String? ?? '생활',
    memo: j['memo'] as String? ?? '',
    active: j['active'] as bool? ?? true,
  );

  Routine copy() => Routine(
    id: id,
    name: name,
    emoji: emoji,
    minuteOfDay: minuteOfDay,
    weekdays: {...weekdays},
    alarmOn: alarmOn,
    category: category,
    memo: memo,
    active: active,
  );
}

/// 하루 기록. 그날 처음 열렸을 때의 루틴 목록을 고정해 두어
/// 나중에 루틴을 고쳐도 지난 기록의 달성률이 바뀌지 않게 한다.
class DayLog {
  DayLog({
    required this.date,
    required this.scheduled,
    Set<String>? completed,
    this.rewarded = false,
    this.rewardXp = 0,
    this.rewardCoins = 0,
    this.memo = '',
  }) : completed = completed ?? {};

  final String date; // yyyy-MM-dd
  /// 그날 예정이던 루틴 (id → 표시 이름/이모지 스냅샷)
  final Map<String, String> scheduled;
  final Set<String> completed;
  bool rewarded;
  int rewardXp;
  int rewardCoins;

  /// 오늘 한 줄 메모
  String memo;

  int get total => scheduled.length;
  int get done => completed.where(scheduled.containsKey).length;
  double get rate => total == 0 ? 0 : done / total;

  Map<String, dynamic> toJson() => {
    'date': date,
    'scheduled': scheduled,
    'completed': completed.toList(),
    'rewarded': rewarded,
    'rewardXp': rewardXp,
    'rewardCoins': rewardCoins,
    'memo': memo,
  };

  factory DayLog.fromJson(Map<String, dynamic> j) => DayLog(
    date: j['date'] as String,
    scheduled: (j['scheduled'] as Map).cast<String, String>(),
    completed: (j['completed'] as List).cast<String>().toSet(),
    rewarded: j['rewarded'] as bool? ?? false,
    rewardXp: j['rewardXp'] as int? ?? 0,
    rewardCoins: j['rewardCoins'] as int? ?? 0,
    memo: j['memo'] as String? ?? '',
  );
}

/// 미니미 기본 외형 (색).
class Minimi {
  const Minimi({this.skin = 0, this.hair = 0, this.outfit = 0});
  final int skin;
  final int hair;

  /// 옷 색
  final int outfit;

  Minimi copyWith({int? skin, int? hair, int? outfit}) =>
      Minimi(skin: skin ?? this.skin, hair: hair ?? this.hair, outfit: outfit ?? this.outfit);

  Map<String, dynamic> toJson() => {'skin': skin, 'hair': hair, 'outfit': outfit};
  factory Minimi.fromJson(Map<String, dynamic> j) =>
      Minimi(skin: j['skin'] as int? ?? 0, hair: j['hair'] as int? ?? 0, outfit: j['outfit'] as int? ?? 0);
}

/// 알림 설정. 미완료를 재촉하는 알림은 두지 않는다 (PRD 원칙).
class AlarmSettings {
  AlarmSettings({this.allOn = true, this.routineStart = true, this.dayEnd = false, this.dayEndMinute = 22 * 60});

  /// 앱 알림 전체
  bool allOn;

  /// 루틴별로 켜 둔 시간에 시작 알림
  bool routineStart;

  /// 하루를 돌아보는 마감 알림
  bool dayEnd;
  int dayEndMinute;

  Map<String, dynamic> toJson() => {
    'allOn': allOn,
    'routineStart': routineStart,
    'dayEnd': dayEnd,
    'dayEndMinute': dayEndMinute,
  };

  factory AlarmSettings.fromJson(Map<String, dynamic> j) => AlarmSettings(
    allOn: j['allOn'] as bool? ?? true,
    routineStart: j['routineStart'] as bool? ?? true,
    dayEnd: j['dayEnd'] as bool? ?? false,
    dayEndMinute: j['dayEndMinute'] as int? ?? 22 * 60,
  );
}

class Profile {
  Profile({
    this.name = '',
    this.xp = 0,
    this.totalXp = 0,
    this.level = 1,
    this.coins = 0,
    this.minimi = const Minimi(),
    this.outfitId,
    this.accessoryId,
    Set<String>? owned,
    Map<String, String>? placed,
    Map<String, String>? badges,
    Map<String, String>? acquired,
    AlarmSettings? alarms,
  }) : owned = owned ?? {},
       placed = placed ?? {},
       badges = badges ?? {},
       acquired = acquired ?? {},
       alarms = alarms ?? AlarmSettings();

  String name;

  /// 현재 레벨 안에서 쌓인 경험치.
  int xp;

  /// 지금까지 받은 경험치 합계.
  int totalXp;
  int level;
  int coins;
  Minimi minimi;

  /// 입고 있는 옷 / 액세서리 아이템 id (없으면 기본 옷)
  String? outfitId;
  String? accessoryId;

  /// 산 아이템 id.
  final Set<String> owned;

  /// 방 자리 → 배치된 가구 id.
  final Map<String, String> placed;

  /// 배지 id → 받은 날짜.
  final Map<String, String> badges;

  /// 아이템 id → 산 날짜.
  final Map<String, String> acquired;
  AlarmSettings alarms;

  Map<String, dynamic> toJson() => {
    'name': name,
    'xp': xp,
    'totalXp': totalXp,
    'level': level,
    'coins': coins,
    'minimi': minimi.toJson(),
    'outfitId': outfitId,
    'accessoryId': accessoryId,
    'owned': owned.toList(),
    'placed': placed,
    'badges': badges,
    'acquired': acquired,
    'alarms': alarms.toJson(),
  };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    name: j['name'] as String? ?? '',
    xp: j['xp'] as int? ?? 0,
    totalXp: j['totalXp'] as int? ?? 0,
    level: j['level'] as int? ?? 1,
    coins: j['coins'] as int? ?? 0,
    minimi: Minimi.fromJson((j['minimi'] as Map?)?.cast<String, dynamic>() ?? {}),
    outfitId: j['outfitId'] as String?,
    accessoryId: j['accessoryId'] as String?,
    owned: ((j['owned'] as List?) ?? []).cast<String>().toSet(),
    placed: ((j['placed'] as Map?) ?? {}).cast<String, String>(),
    badges: ((j['badges'] as Map?) ?? {}).cast<String, String>(),
    acquired: ((j['acquired'] as Map?) ?? {}).cast<String, String>(),
    alarms: AlarmSettings.fromJson((j['alarms'] as Map?)?.cast<String, dynamic>() ?? {}),
  );
}

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime parseDateKey(String k) {
  final p = k.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}
