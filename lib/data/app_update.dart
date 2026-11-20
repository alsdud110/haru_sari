import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'store.dart';

/// 서버의 app_updates (supabase/migrations/20261120000000_app_updates.sql) 가 알려 주는 업데이트 안내.
class AppUpdate {
  const AppUpdate({required this.latest, required this.force, required this.message, required this.storeUrl});

  /// 안내하는 빌드 번호. '나중에'를 누르면 이 번호를 기억해 다시 띄우지 않는다.
  final int latest;

  /// 닫을 수 없는 안내인지.
  final bool force;
  final String message;
  final String storeUrl;

  static const dismissedKey = 'update_dismissed_build';

  /// 서버 줄과 지금 빌드로 띄울 안내를 고른다. 띄울 게 없으면 null.
  static AppUpdate? decide(Map<String, dynamic> row, {required int build, int? dismissed}) {
    final latest = row['latest_build'] as int? ?? 0;
    final min = row['min_build'] as int? ?? 0;
    final url = row['store_url'] as String? ?? '';
    if (url.isEmpty) return null;
    final force = build < min;
    if (!force && (build >= latest || dismissed == latest)) return null;
    return AppUpdate(latest: latest, force: force, message: row['message'] as String? ?? '', storeUrl: url);
  }
}

/// 서버에 물어본다. 연결이 안 되거나 늦으면 조용히 넘어간다 (안내 때문에 앱을 막지 않는다).
Future<AppUpdate?> fetchAppUpdate(KeyValue kv) async {
  final platform = switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    _ => null,
  };
  if (kIsWeb || platform == null) return null;
  try {
    final row = await Supabase.instance.client
        .from('app_updates')
        .select()
        .eq('platform', platform)
        .maybeSingle()
        .timeout(const Duration(seconds: 5));
    if (row == null) return null;
    return AppUpdate.decide(row, build: AppVersion.build, dismissed: int.tryParse(kv.read(AppUpdate.dismissedKey) ?? ''));
  } catch (_) {
    return null;
  }
}
