import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'data/auth.dart';
import 'data/reminders.dart';
import 'data/store.dart';
import 'data/supabase_auth.dart';
import 'data/supabase_remote.dart';
import 'room/manifest.dart';
import 'ui/licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  registerFontLicenses();
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
  final kv = PrefsKeyValue(await SharedPreferences.getInstance());
  final manifest = await PixelManifest.load();
  runApp(
    HaruSariApp(
      kv: kv,
      auth: SupabaseAuthService(kv),
      reminders: LocalReminders(),
      manifest: manifest,
      // 개발자 모드 계정은 서버와 맞추지 않는다 (이 기기에만 저장).
      remoteFor: (uid) => uid == AuthService.devUid ? null : SupabaseRemote(uid),
    ),
  );
}
