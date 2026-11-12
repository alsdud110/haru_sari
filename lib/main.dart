import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'data/reminders.dart';
import 'data/store.dart';
import 'data/supabase_auth.dart';
import 'room/manifest.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
  final kv = PrefsKeyValue(await SharedPreferences.getInstance());
  final manifest = await PixelManifest.load();
  runApp(
    HaruSariApp(
      kv: kv,
      auth: SupabaseAuthService(kv),
      reminders: LocalReminders(),
      manifest: manifest,
    ),
  );
}
