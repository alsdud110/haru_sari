import '../room/layout.dart';

/// 루틴 카테고리. 하루에 실제로 하는 일을 기준으로 나눴다 (이름 → 칩에 함께 보이는 이모지).
/// 예전 값('생활' 등)이 저장된 루틴은 편집 화면에서 그 이름 그대로 한 칸 더 보여 준다.
const routineCategoryEmoji = <String, String>{
  '기상·수면': '🌙', // 일어나기, 잠자리 들기, 낮잠
  '씻기·단장': '🧼', // 세수, 샤워, 양치, 스킨케어, 출근 준비
  '식사': '🍚', // 아침·점심·저녁, 도시락, 간식
  '물·영양': '💧', // 물 마시기, 영양제, 약
  '운동': '🏃', // 걷기, 스트레칭, 헬스, 요가
  '건강': '🩺', // 병원, 자세, 눈 쉬기, 체중 재기
  '이동': '🚇', // 출근, 퇴근, 등하교
  '일·업무': '💼', // 업무 시작, 회의 준비, 할 일 정리
  '공부': '📚', // 강의, 자격증, 외국어, 독서
  '집안일': '🧹', // 청소, 빨래, 설거지, 장보기, 분리수거
  '돌봄': '🐶', // 반려동물, 식물, 가족 챙기기
  '마음': '🧘', // 명상, 일기, 감사, 산책하며 쉬기
  '취미·여가': '🎧', // 음악, 게임, 그림, 영상
  '관계': '💬', // 안부 연락, 가족 통화, 약속
  '돈 관리': '💰', // 가계부, 저축, 지출 확인
  '기타': '✨',
};
final routineCategories = routineCategoryEmoji.keys.toList(growable: false);

/// 카테고리를 고르면 먼저 보여 줄 아이콘 (첫 칸은 카테고리 아이콘). 나머지는 '전체 보기'로 고른다.
const routineCategoryIcons = <String, List<String>>{
  '기상·수면': ['🌙', '🌤', '🛏'],
  '씻기·단장': ['🧼', '🪥', '🛁', '👔'],
  '식사': ['🍚', '🍴', '☕'],
  '물·영양': ['💧', '🥛', '💊'],
  '운동': ['🏃', '🏋'],
  '건강': ['🩺', '💊', '🧘'],
  '이동': ['🚇', '🚌', '🏠'],
  '일·업무': ['💼', '✍', '☕'],
  '공부': ['📚', '📖', '✍'],
  '집안일': ['🧹', '🏠', '🪴'],
  '돌봄': ['🐶', '🪴'],
  '마음': ['🧘', '✍', '🎵'],
  '취미·여가': ['🎧', '🎵', '📖'],
  '관계': ['💬'],
  '돈 관리': ['💰'],
  '기타': ['✨'],
};

/// 루틴: 사용자가 반복하는 일상 활동 하나.
class Routine {
  Routine({
    required this.id,
    required this.name,
    required this.emoji,
    this.minuteOfDay,
    Set<int>? weekdays,
    this.alarmOn = false,
    this.category = '기타',
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
    category: j['category'] as String? ?? '기타',
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
    this.perfectPaid = false,
    this.rewardXp = 0,
    this.rewardCoins = 0,
    this.memo = '',
  }) : completed = completed ?? {};

  final String date; // yyyy-MM-dd
  /// 그날 예정이던 루틴 (id → 표시 이름/이모지 스냅샷)
  final Map<String, String> scheduled;
  final Set<String> completed;
  bool rewarded;

  /// 100% 보너스를 받았는지 (70%로 먼저 받고 나중에 100%가 되면 보너스만 더 받는다)
  bool perfectPaid;
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
    'perfectPaid': perfectPaid,
    'rewardXp': rewardXp,
    'rewardCoins': rewardCoins,
    'memo': memo,
  };

  factory DayLog.fromJson(Map<String, dynamic> j) => DayLog(
    date: j['date'] as String,
    scheduled: (j['scheduled'] as Map).cast<String, String>(),
    completed: (j['completed'] as List).cast<String>().toSet(),
    rewarded: j['rewarded'] as bool? ?? false,
    perfectPaid: j['perfectPaid'] as bool? ?? false,
    rewardXp: j['rewardXp'] as int? ?? 0,
    rewardCoins: j['rewardCoins'] as int? ?? 0,
    memo: j['memo'] as String? ?? '',
  );
}

/// 미니미 기본 외형. 값은 모두 번호다 (색은 PixelPalette, 모양은 tool/draw_minimi.dart와 같은 순서).
class Minimi {
  const Minimi({this.skin = 0, this.hair = 0, this.outfit = 0, this.hairStyle = 0, this.eyes = 0, this.mouth = 0});
  final int skin;

  /// 머리색
  final int hair;

  /// 옷 색
  final int outfit;
  final int hairStyle;
  final int eyes;
  final int mouth;

  static const skinNames = ['크림', '헬시', '태닝', '브론즈', '밀키', '스산', '창백', '노블레스'];
  static const hairStyleNames = ['단발', '짧은 머리', '긴 머리', '스크래치', '포니테일', '양갈래', '똥머리', '곱슬', '가르마', '삐죽'];
  static const eyeNames = ['기본', '반짝', '감은 눈', '웃는 눈', '윙크', '졸린 눈'];
  static const mouthNames = ['미소', '활짝', '시무룩', '놀람', '무표정', '고양이'];

  Minimi copyWith({int? skin, int? hair, int? outfit, int? hairStyle, int? eyes, int? mouth}) => Minimi(
    skin: skin ?? this.skin,
    hair: hair ?? this.hair,
    outfit: outfit ?? this.outfit,
    hairStyle: hairStyle ?? this.hairStyle,
    eyes: eyes ?? this.eyes,
    mouth: mouth ?? this.mouth,
  );

  Map<String, dynamic> toJson() => {
    'skin': skin,
    'hair': hair,
    'outfit': outfit,
    'hairStyle': hairStyle,
    'eyes': eyes,
    'mouth': mouth,
  };
  factory Minimi.fromJson(Map<String, dynamic> j) => Minimi(
    skin: j['skin'] as int? ?? 0,
    hair: j['hair'] as int? ?? 0,
    outfit: j['outfit'] as int? ?? 0,
    hairStyle: j['hairStyle'] as int? ?? 0,
    eyes: j['eyes'] as int? ?? 0,
    mouth: j['mouth'] as int? ?? 0,
  );
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
    this.earringId,
    Set<String>? owned,
    Map<String, String>? placed,
    Map<String, String>? badges,
    Map<String, String>? acquired,
    AlarmSettings? alarms,
    this.room,
    this.adDay,
    this.adCount = 0,
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

  /// 입고 있는 옷 / 액세서리 / 귀고리 아이템 id (없으면 기본 옷). 귀고리는 액세서리와 따로 찬다.
  String? outfitId;
  String? accessoryId;
  String? earringId;

  /// 산 아이템 id.
  final Set<String> owned;

  /// 방 자리 → 배치된 가구 id.
  final Map<String, String> placed;

  /// 배지 id → 받은 날짜.
  final Map<String, String> badges;

  /// 아이템 id → 산 날짜.
  final Map<String, String> acquired;
  AlarmSettings alarms;

  /// 아이소메트릭 방 배치 (docs/asset-system/02 §5). 없으면 불러올 때 [placed]에서 만든다.
  /// [placed]는 기존 데이터 호환을 위해 지우지 않고 남겨 둔다.
  RoomLayout? room;

  /// 광고 보상을 마지막으로 받은 날(yyyy-MM-dd)과 그날 받은 횟수. 날이 바뀌면 0번으로 본다.
  String? adDay;
  int adCount;

  Map<String, dynamic> toJson() => {
    'name': name,
    'xp': xp,
    'totalXp': totalXp,
    'level': level,
    'coins': coins,
    'minimi': minimi.toJson(),
    'outfitId': outfitId,
    'accessoryId': accessoryId,
    'earringId': earringId,
    'owned': owned.toList(),
    'placed': placed,
    'badges': badges,
    'acquired': acquired,
    'alarms': alarms.toJson(),
    if (room != null) 'room': room!.toJson(),
    if (adDay != null) 'adDay': adDay,
    if (adDay != null) 'adCount': adCount,
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
    earringId: j['earringId'] as String?,
    adDay: j['adDay'] as String?,
    adCount: j['adCount'] as int? ?? 0,
    owned: ((j['owned'] as List?) ?? []).cast<String>().toSet(),
    placed: ((j['placed'] as Map?) ?? {}).cast<String, String>(),
    badges: ((j['badges'] as Map?) ?? {}).cast<String, String>(),
    acquired: ((j['acquired'] as Map?) ?? {}).cast<String, String>(),
    alarms: AlarmSettings.fromJson((j['alarms'] as Map?)?.cast<String, dynamic>() ?? {}),
    room: j['room'] is Map ? RoomLayout.fromJson((j['room'] as Map).cast<String, dynamic>()) : null,
  );
}

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime parseDateKey(String k) {
  final p = k.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}
