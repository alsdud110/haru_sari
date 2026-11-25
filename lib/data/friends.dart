import 'models.dart';

/// 나의 루틴 공유 (PLAN_FRIEND_SHARE_STEP1.md, supabase/migrations/20261125000000_routine_shares.sql).
///
/// 서버가 돌려준 값도, 카카오·붙여넣기로 들어온 코드도 밖에서 온 값이라 여기서 형식을 다시 확인한다.

/// 초대 코드. 서버의 `_normalize_share_code` 와 같은 규칙이다.
class InviteCode {
  InviteCode._();

  /// 헷갈리는 0 O 1 I L 을 뺀 31자.
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const length = 8;
  static final _valid = RegExp('^[$alphabet]{$length}\$');

  /// `HARU-K7QM-3XPD`, `k7qm 3xpd`, `K7QM3XPD` 를 모두 `K7QM3XPD` 로. 형식이 틀리면 null.
  static String? parse(String? raw) {
    if (raw == null || raw.length > 40) return null;
    var c = raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (c.length == 12 && c.startsWith('HARU')) c = c.substring(4);
    return _valid.hasMatch(c) ? c : null;
  }

  /// 보여 줄 때: `HARU-K7QM-3XPD`
  static String display(String code) => 'HARU-${code.substring(0, 4)}-${code.substring(4)}';

  /// 로그에 남길 때: 앞 2자만.
  static String masked(String code) => code.length < 2 ? '…' : '${code.substring(0, 2)}…';

  /// 붙여 넣은 글(공유 글 전체일 수도 있다)에서 코드를 찾는다.
  static String? find(String? text) {
    if (text == null) return null;
    final m = RegExp(r'HARU[\s-]*[A-Za-z0-9]{4}[\s-]*[A-Za-z0-9]{4}', caseSensitive: false).firstMatch(text);
    return parse(m?.group(0) ?? text.trim());
  }

  /// Play 설치 출처(Install Referrer)에서 코드를 꺼낸다. 공유 글의 Play 링크에 `&referrer=code%3DK7QM3XPD` 로 싣는다.
  static String? fromReferrer(String? referrer) {
    if (referrer == null || referrer.isEmpty || referrer.length > 200) return null;
    try {
      return parse(Uri.splitQueryString(referrer)['code']);
    } catch (_) {
      return null;
    }
  }
}

/// 초대 보상 (3단계, supabase/migrations/20261127000000_invite_rewards.sql 과 같다).
class InviteRules {
  InviteRules._();
  static const newFriendCoins = 30;
  static const inviterCoins = 30;
  static const inviterMax = 10;
}

enum ClaimResult { ok, notFound, self, claimed, notNew }

/// 공유하는 루틴 한 줄. 메모·알림 여부·쉬는 상태는 담지 않는다.
class SharedRoutine {
  const SharedRoutine({
    required this.id,
    required this.name,
    required this.emoji,
    required this.minuteOfDay,
    required this.weekdays,
    required this.category,
  });

  final String id;
  final String name;
  final String emoji;
  final int? minuteOfDay;

  /// 1(월)~7(일), 오름차순
  final List<int> weekdays;
  final String category;

  factory SharedRoutine.fromRoutine(Routine r) => SharedRoutine(
    id: r.id,
    name: r.name.trim(),
    emoji: r.emoji,
    minuteOfDay: r.minuteOfDay,
    weekdays: r.weekdays.toList()..sort(),
    category: r.category,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'minute': minuteOfDay,
    'weekdays': weekdays,
    'category': category,
  };

  /// 서버 값에서 읽는다. 모양이 틀린 줄은 null (목록에서 빠진다).
  static SharedRoutine? tryParse(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], name = j['name'], emoji = j['emoji'], minute = j['minute'], days = j['weekdays'];
    if (id is! String || name is! String || emoji is! String || days is! List) return null;
    if (minute != null && (minute is! int || minute < 0 || minute > 1439)) return null;
    final weekdays = days.whereType<int>().where((d) => d >= 1 && d <= 7).toSet().toList()..sort();
    if (weekdays.isEmpty || name.trim().isEmpty) return null;
    final category = j['category'];
    return SharedRoutine(
      id: id,
      name: name,
      emoji: emoji,
      minuteOfDay: minute as int?,
      weekdays: weekdays,
      category: category is String ? category : '기타',
    );
  }

  /// 내 루틴 중에 이미 같은 것(이름·이모지·시간·요일)이 있는지. '추가함' 표시에 쓴다.
  bool isIn(Iterable<Routine> mine) => mine.any(
    (r) =>
        r.name.trim() == name.trim() &&
        r.emoji == emoji &&
        r.minuteOfDay == minuteOfDay &&
        r.weekdays.length == weekdays.length &&
        r.weekdays.containsAll(weekdays),
  );

  /// 친구 루틴을 내 루틴으로 복사. 알림은 꺼 둔 채, 메모 없이.
  Routine toMyRoutine(String newId) => Routine(
    id: newId,
    name: name,
    emoji: emoji,
    minuteOfDay: minuteOfDay,
    weekdays: weekdays.toSet(),
    alarmOn: false,
    category: category,
  );
}

/// 친구 화면에 미니미를 그리는 데 필요한 것만.
class SharedLook {
  const SharedLook({
    this.minimi = const Minimi(),
    this.outfitId,
    this.accessoryId,
    this.earringId,
    this.bottomId,
    this.itemColors = const {},
  });

  final Minimi minimi;
  final String? outfitId;
  final String? accessoryId;
  final String? earringId;
  final String? bottomId;
  final Map<String, int> itemColors;

  /// 지금 입은 것의 색만 보낸다 (산 옷 전체 목록을 드러내지 않게).
  factory SharedLook.fromProfile(Profile p) {
    final worn = [p.outfitId, p.accessoryId, p.earringId, p.bottomId].whereType<String>().toSet();
    return SharedLook(
      minimi: p.minimi,
      outfitId: p.outfitId,
      accessoryId: p.accessoryId,
      earringId: p.earringId,
      bottomId: p.bottomId,
      itemColors: {
        for (final e in p.itemColors.entries)
          if (worn.contains(e.key)) e.key: e.value,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'minimi': minimi.toJson(),
    if (outfitId != null) 'outfitId': outfitId,
    if (accessoryId != null) 'accessoryId': accessoryId,
    if (earringId != null) 'earringId': earringId,
    if (bottomId != null) 'bottomId': bottomId,
    'itemColors': itemColors,
  };

  factory SharedLook.fromJson(Object? j) {
    if (j is! Map) return const SharedLook();
    String? id(String k) => j[k] is String ? j[k] as String : null;
    final m = j['minimi'];
    final colors = j['itemColors'];
    return SharedLook(
      minimi: m is Map
          ? Minimi.fromJson({
              for (final e in m.entries)
                if (e.value is int) '${e.key}': e.value,
            })
          : const Minimi(),
      outfitId: id('outfitId'),
      accessoryId: id('accessoryId'),
      earringId: id('earringId'),
      bottomId: id('bottomId'),
      itemColors: colors is Map
          ? {
              for (final e in colors.entries)
                if (e.value is int) '${e.key}': e.value as int,
            }
          : const {},
    );
  }

  /// MinimiView 가 Profile 을 받으므로 모습만 채운 Profile 을 만든다.
  Profile toProfile() => Profile(
    minimi: minimi,
    outfitId: outfitId,
    accessoryId: accessoryId,
    earringId: earringId,
    bottomId: bottomId,
    itemColors: Map.of(itemColors),
  );
}

/// 다른 사람이 공유한 루틴 묶음.
class FriendShare {
  const FriendShare({
    this.owner,
    required this.nickname,
    required this.look,
    required this.routines,
    this.updatedAt,
    this.alarmIds = const {},
  });

  /// 내가 알림을 켠 이 친구의 루틴 id (친구 목록에서만 온다)
  final Set<String> alarmIds;

  /// 친구 끊기에 쓰는 계정 id. 코드로 구경할 때는 없다.
  final String? owner;
  final String nickname;
  final SharedLook look;
  final List<SharedRoutine> routines;
  final DateTime? updatedAt;

  /// 화면에 부를 이름. 닉네임이 없으면 '친구'.
  String get displayName => nickname.trim().isEmpty ? '친구' : nickname.trim();

  factory FriendShare.fromRow(Map<String, dynamic> r) {
    final raw = r['routines'];
    return FriendShare(
      owner: r['owner'] is String ? r['owner'] as String : null,
      nickname: r['nickname'] is String ? r['nickname'] as String : '',
      look: SharedLook.fromJson(r['look']),
      routines: raw is List ? raw.map(SharedRoutine.tryParse).whereType<SharedRoutine>().toList() : const [],
      updatedAt: r['updated_at'] is String ? DateTime.tryParse(r['updated_at'] as String) : null,
      alarmIds: {
        if (r['alarm_ids'] is List)
          for (final e in r['alarm_ids'] as List)
            if (e is String) e,
      },
    );
  }

  /// 내가 알림을 켰고, 시간이 정해져 있어 울릴 수 있는 루틴.
  List<FriendAlarm> get alarms => [
    for (final r in routines)
      if (alarmIds.contains(r.id) && r.minuteOfDay != null && owner != null) FriendAlarm(owner: owner!, nickname: displayName, routine: r),
  ];
}

/// 친구 루틴 알림 한 개 (2단계). 기기에 적어 두었다가 알림 예약에 쓴다.
class FriendAlarm {
  const FriendAlarm({required this.owner, required this.nickname, required this.routine});
  final String owner;
  final String nickname;
  final SharedRoutine routine;

  /// 친구 + 루틴으로 구분한다
  String get key => '$owner/${routine.id}';

  Map<String, dynamic> toJson() => {'owner': owner, 'nickname': nickname, 'routine': routine.toJson()};

  static FriendAlarm? tryParse(Object? j) {
    if (j is! Map || j['owner'] is! String || j['nickname'] is! String) return null;
    final r = SharedRoutine.tryParse(j['routine']);
    if (r == null || r.minuteOfDay == null) return null;
    return FriendAlarm(owner: j['owner'] as String, nickname: j['nickname'] as String, routine: r);
  }
}

/// 친구 루틴 알림은 한 사람당 이만큼까지 (서버 set_friend_alarm 과 같다).
const maxFriendAlarms = 5;

enum AlarmResult { ok, limit, notFriend }

enum LookupStatus { ok, notFound, limited }

/// 코드로 구경한 결과.
class ShareLookup {
  const ShareLookup(this.status, {this.share, this.isMe = false, this.following = false});
  final LookupStatus status;
  final FriendShare? share;
  final bool isMe;
  final bool following;

  static const notFound = ShareLookup(LookupStatus.notFound);
  static const limited = ShareLookup(LookupStatus.limited);

  factory ShareLookup.fromRow(Map<String, dynamic> r) => switch (r['status']) {
    'ok' => ShareLookup(
      LookupStatus.ok,
      share: FriendShare.fromRow(r),
      isMe: r['is_me'] == true,
      following: r['following'] == true,
    ),
    'limited' => limited,
    _ => notFound,
  };
}

enum FollowResult { ok, notFound, self, limit }

/// 친구는 한 사람당 이만큼까지 (서버 follow_share 와 같다).
const maxFriends = 10;

/// 내 공유 상태 (서버의 내 줄).
class MyShare {
  const MyShare({required this.code, required this.routineIds});
  final String code;
  final Set<String> routineIds;
}
