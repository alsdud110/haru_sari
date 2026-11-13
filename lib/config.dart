import 'package:flutter/foundation.dart';

/// AdMob 광고 정보. 공개돼도 되는 값이다.
///
/// 넣을 곳이 두 군데다.
/// - **광고 단위 ID** (가운데가 `/`): 아래 [rewardedAndroid]·[rewardedIos]
/// - **앱 ID** (가운데가 `~`): android/app/src/main/AndroidManifest.xml 의 APPLICATION_ID,
///   ios/Runner/Info.plist 의 GADApplicationIdentifier
class AdConfig {
  /// AdMob 에서 만든 '보상형' 광고 단위 ID. 비워 두면 출시 빌드에서는 광고 버튼이 보이지 않는다.
  static const rewardedAndroid = 'ca-app-pub-7446781962805745/7887628564';
  static const rewardedIos = 'ca-app-pub-7446781962805745/2798953415';

  // Google 이 공개한 테스트용 보상형 광고 단위. 디버그 빌드는 늘 이것을 쓴다
  // (개발 중에 진짜 광고를 누르면 계정이 정지될 수 있다).
  static const _testAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testIos = 'ca-app-pub-3940256099942544/1712485313';

  /// 지금 빌드·기기에서 쓸 광고 단위. 광고를 쓸 수 없으면 null.
  static String? get rewardedUnitId {
    if (kIsWeb) return null;
    final (real, test) = switch (defaultTargetPlatform) {
      TargetPlatform.android => (rewardedAndroid, _testAndroid),
      TargetPlatform.iOS => (rewardedIos, _testIos),
      _ => ('', ''),
    };
    final id = kDebugMode ? test : real;
    return id.isEmpty ? null : id;
  }
}

/// 서버 연결 정보.
///
/// 둘 다 앱에 들어가는 **공개용** 값이다 (데이터는 서버의 RLS 규칙이 지킨다).
/// secret / service_role 키는 절대 여기에 넣지 않는다.
class SupabaseConfig {
  static const url = 'https://eaufexujonthswdruurr.supabase.co';
  static const publishableKey = 'sb_publishable_UpqfoHFkPEW88v_IN8IPfQ_2-CSM9tw';

  /// 소셜 로그인 후 앱으로 돌아오는 주소 (Supabase Redirect URLs 에 등록).
  static const redirectUrl = 'com.harusari.app://login-callback';
}
