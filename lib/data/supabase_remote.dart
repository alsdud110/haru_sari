import 'package:supabase_flutter/supabase_flutter.dart';

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
}
