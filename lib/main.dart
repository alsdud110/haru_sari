import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/auth.dart';
import 'data/reminders.dart';
import 'data/store.dart';
import 'room/manifest.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  final kv = PrefsKeyValue(await SharedPreferences.getInstance());
  final manifest = await PixelManifest.load();
  runApp(OneulSariApp(kv: kv, auth: AuthService(kv), reminders: LocalReminders(), manifest: manifest));
}
