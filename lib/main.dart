import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'data/admob_ads.dart';
import 'data/app_update.dart';
import 'data/kakao_share.dart';
import 'ui/friends/dev_kakao_preview.dart';
import 'data/reminders.dart';
import 'data/store.dart';
import 'data/supabase_auth.dart';
import 'data/supabase_remote.dart';
import 'room/manifest.dart';
import 'ui/licenses.dart';
import 'ui/routine_icon.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  registerFontLicenses();
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
  final kv = PrefsKeyValue(await SharedPreferences.getInstance());
  final manifest = await PixelManifest.load();
  final kakao = await KakaoInvites.init();
  // 개발 빌드: 카카오톡이 없는 기기에서도 카톡 공유 흐름을 그려서 볼 수 있게 (출시 빌드에는 없음)
  final FriendInvites? invites = kDebugMode ? DevKakaoInvites(kakao) : kakao;
  runApp(
    HaruSariApp(
      kv: kv,
      auth: SupabaseAuthService(kv),
      reminders: LocalReminders(iconAssetFor: routineIconAsset),
      ads: AdMobRewardAds(),
      manifest: manifest,
      remoteFor: SupabaseRemote.new,
      checkUpdate: () => fetchAppUpdate(kv),
      invites: invites,
    ),
  );
}
