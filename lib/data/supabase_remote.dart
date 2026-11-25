import 'package:supabase_flutter/supabase_flutter.dart';

import 'friends.dart';
import 'sync.dart';

/// Supabase 테이블·함수 (supabase/migrations/20261112000000_init.sql) 에 맞춘 [Remote].
/// 모든 접근은 로그인한 사용자 자신의 행으로만 제한된다 (RLS).
class SupabaseRemote implements Remote {
  SupabaseRemote(this.uid);
  final String uid;

  SupabaseClient get _c => Supabase.instance.client;

  @override
  Future<RemoteSnapshot> pull() async {
    final results = await Future.wait<dynamic>([
      _c.from('user_state').select().eq('user_id', uid).maybeSingle(),
      _c.from('day_logs').select('day, data, updated_at').eq('user_id', uid),
      _c.from('wallets').select().eq('user_id', uid).maybeSingle(),
      _c.from('purchases').select('item_id').eq('user_id', uid),
      _c.from('reward_grants').select('day').eq('user_id', uid).limit(1),
    ]);
    final st = results[0] as Map<String, dynamic>?;
    final logs = (results[1] as List).cast<Map<String, dynamic>>();
    final w = results[2] as Map<String, dynamic>?;
    final purchases = (results[3] as List).cast<Map<String, dynamic>>();
    final grants = results[4] as List;
    return RemoteSnapshot(
      state: st,
      stateAt: st == null ? null : DateTime.tryParse(st['updated_at'] as String? ?? ''),
      logs: {
        for (final r in logs)
          r['day'] as String: (
            data: (r['data'] as Map).cast<String, dynamic>(),
            at: DateTime.parse(r['updated_at'] as String),
          ),
      },
      wallet: w == null ? null : Wallet.fromRow(w),
      purchases: {for (final r in purchases) r['item_id'] as String},
      hasGrants: grants.isNotEmpty,
    );
  }

  @override
  Future<void> pushState({
    required String nickname,
    required bool onboarded,
    required List<dynamic> routines,
    required Map<String, dynamic> profile,
    required DateTime at,
  }) => _c.from('user_state').upsert({
    'user_id': uid,
    'nickname': nickname,
    'onboarded': onboarded,
    'routines': routines,
    'profile': profile,
    'updated_at': at.toUtc().toIso8601String(),
  });

  @override
  Future<void> pushLogs(Map<String, ({Map<String, dynamic> data, DateTime at})> logs) => _c.from('day_logs').upsert([
    for (final e in logs.entries)
      {'user_id': uid, 'day': e.key, 'data': e.value.data, 'updated_at': e.value.at.toUtc().toIso8601String()},
  ]);

  @override
  Future<({int gainedXp, int gainedCoins, Wallet wallet})> claim(String day, int done, int total) async {
    final rows = await _c.rpc<List<dynamic>>(
      'claim_daily_reward',
      params: {'p_day': day, 'p_done': done, 'p_total': total},
    );
    final r = (rows.first as Map).cast<String, dynamic>();
    return (gainedXp: r['gained_xp'] as int, gainedCoins: r['gained_coins'] as int, wallet: Wallet.fromRow(r));
  }

  @override
  Future<BuyReply> buy(String itemId, int price, int minLevel) async {
    final rows = await _c.rpc<List<dynamic>>(
      'buy_item',
      params: {'p_item_id': itemId, 'p_price': price, 'p_min_level': minLevel},
    );
    final r = (rows.first as Map).cast<String, dynamic>();
    return BuyReply(ok: r['ok'] as bool, reason: r['reason'] as String?, wallet: Wallet.fromRow(r));
  }

  @override
  Future<AdReply> adReward(String day) async {
    try {
      final rows = await _c.rpc<List<dynamic>>('claim_ad_reward', params: {'p_day': day});
      final r = (rows.first as Map).cast<String, dynamic>();
      return AdReply(ok: r['ok'] as bool, used: r['used'] as int, wallet: Wallet.fromRow(r));
    } on PostgrestException catch (e) {
      // 서버가 답은 했지만 처리하지 못했다 (함수를 아직 올리지 않았거나 날짜가 범위를 벗어남)
      throw RemoteRejected(e.message);
    }
  }

  // supabase/migrations/20261115000000_room_shares.sql

  @override
  Future<bool> roomPublic() async =>
      await _c.from('room_shares').select('user_id').eq('user_id', uid).maybeSingle() != null;

  @override
  Future<void> setRoomPublic(bool on) =>
      on ? _c.rpc<void>('publish_room') : _c.from('room_shares').delete().eq('user_id', uid);

  // supabase/migrations/20261125000000_routine_shares.sql

  @override
  Future<String> saveRoutineShare({
    required String nickname,
    required SharedLook look,
    required List<SharedRoutine> routines,
  }) async {
    try {
      final code = await _c.rpc<String>(
        'save_routine_share',
        params: {
          'p_nickname': nickname,
          'p_look': look.toJson(),
          'p_routines': [for (final r in routines) r.toJson()],
        },
      );
      final parsed = InviteCode.parse(code);
      if (parsed == null) throw const RemoteRejected('bad code from server');
      return parsed;
    } on PostgrestException catch (e) {
      // 서버가 입력을 거절함 (길이·형식). 다시 보내도 같다.
      throw RemoteRejected(e.message);
    }
  }

  @override
  Future<void> stopRoutineShare() => _c.rpc<void>('stop_routine_share');

  @override
  Future<MyShare?> myRoutineShare() async {
    final r = await _c.from('routine_shares').select('code, routines').eq('user_id', uid).maybeSingle();
    final code = InviteCode.parse(r?['code'] as String?);
    if (r == null || code == null) return null;
    final list = r['routines'];
    return MyShare(
      code: code,
      routineIds: {
        if (list is List)
          for (final j in list)
            if (j is Map && j['id'] is String) j['id'] as String,
      },
    );
  }

  @override
  Future<ShareLookup> lookupShare(String code) async {
    final rows = await _c.rpc<List<dynamic>>('get_shared_routines', params: {'p_code': code});
    if (rows.isEmpty) return ShareLookup.notFound;
    return ShareLookup.fromRow((rows.first as Map).cast<String, dynamic>());
  }

  @override
  Future<FollowResult> follow(String code) async {
    final rows = await _c.rpc<List<dynamic>>('follow_share', params: {'p_code': code});
    final r = rows.isEmpty ? const <String, dynamic>{} : (rows.first as Map).cast<String, dynamic>();
    if (r['ok'] == true) return FollowResult.ok;
    return switch (r['reason']) {
      'self' => FollowResult.self,
      'limit' => FollowResult.limit,
      _ => FollowResult.notFound,
    };
  }

  @override
  Future<void> unfollow(String owner) => _c.from('friend_follows').delete().eq('follower', uid).eq('owner', owner);

  // supabase/migrations/20261127000000_invite_rewards.sql

  @override
  Future<bool> inviteEligible() async {
    final rows = await _c.rpc<List<dynamic>>('invite_status');
    return rows.isNotEmpty && (rows.first as Map)['eligible'] == true;
  }

  @override
  Future<InviteClaim> claimInvite(String code) async {
    final rows = await _c.rpc<List<dynamic>>('claim_invite', params: {'p_code': code});
    if (rows.isEmpty) return const InviteClaim(result: ClaimResult.notFound);
    final r = (rows.first as Map).cast<String, dynamic>();
    final result = r['ok'] == true
        ? ClaimResult.ok
        : switch (r['reason']) {
            'self' => ClaimResult.self,
            'claimed' => ClaimResult.claimed,
            'not_new' => ClaimResult.notNew,
            _ => ClaimResult.notFound,
          };
    return InviteClaim(result: result, gained: r['gained'] as int? ?? 0, wallet: Wallet.fromRow(r));
  }

  // supabase/migrations/20261126000000_friend_alarms.sql

  @override
  Future<AlarmResult> setFriendAlarm(String owner, String routineId, bool on) async {
    final rows = await _c.rpc<List<dynamic>>(
      'set_friend_alarm',
      params: {'p_owner': owner, 'p_routine_id': routineId, 'p_on': on},
    );
    final r = rows.isEmpty ? const <String, dynamic>{} : (rows.first as Map).cast<String, dynamic>();
    if (r['ok'] == true) return AlarmResult.ok;
    return r['reason'] == 'limit' ? AlarmResult.limit : AlarmResult.notFriend;
  }

  @override
  Future<List<FriendShare>> friendRoutines() async {
    final rows = await _c.rpc<List<dynamic>>('my_friend_routines');
    return [for (final r in rows) FriendShare.fromRow((r as Map).cast<String, dynamic>())];
  }
}
