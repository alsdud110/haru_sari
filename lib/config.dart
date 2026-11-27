import 'package:flutter/foundation.dart';

import 'data/friends.dart';

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

/// 지금 빌드 번호. pubspec.yaml version 의 + 뒤 숫자와 같아야 한다 (test/app_update_test.dart 가 확인).
/// 업데이트 안내 팝업이 서버의 app_updates 와 비교한다.
class AppVersion {
  static const build = 9;
}

/// 카카오 (카카오톡 공유).
///
/// 네이티브 앱 키는 비밀값이 아니다: 앱 안의 URL scheme(kakao{키}, Info.plist·AndroidManifest)에
/// 그대로 들어가야 하는 공개 식별자다. 다른 앱이 이 키를 쓰지 못하게 하는 건 카카오 콘솔의
/// 번들 ID·패키지·키 해시 등록이다. REST API 키·Client Secret 은 절대 여기에 넣지 않는다.
class KakaoConfig {
  static const nativeAppKey = '5ca008b29b4d7516d31e55049ad7b6d9';
}

/// 나의 루틴 공유 문구 (PLAN_FRIEND_SHARE_STEP1.md). 문구는 여기서만 바꾼다.
class ShareCopy {
  static const appStore = 'https://apps.apple.com/app/id6834387060';
  static const playStore = 'https://play.google.com/store/apps/details?id=com.harusari.app';

  /// 초대 링크 하나: 받는 사람의 폰에 맞는 스토어로 보낸다 (docs/i/ 를 GitHub Pages 로 공개).
  /// Android 는 그 페이지가 Play 링크에 코드를 실어(`referrer`) 설치 뒤 앱이 읽게 한다 (Install Referrer).
  static String inviteLink(String code) => 'https://alsdud110.github.io/haru_sari/i/?code=$code';

  /// [name] 은 보내는 사람 닉네임 (없으면 '친구'), [code] 는 8자 코드.
  static String otherApps(String name, String code) =>
      '$name님이 하루살이에서 루틴을 공유했어요 🌱\n'
      '새로 가입하면 코드를 넣고 나도 친구도 ${InviteRules.newFriendCoins}코인을 받아요.\n'
      '앱에서 나 → 친구 → 코드로 추가에 넣어 주세요.\n'
      '코드: ${InviteCode.display(code)}\n'
      '\n'
      '앱 받기: ${inviteLink(code)}';

  /// 공유하는 사람에게 보여 주는 한 줄 (루틴 공유 화면).
  static String inviterReward() =>
      '친구가 내 코드로 새로 가입하면 나도 ${InviteRules.inviterCoins}코인을 받아요 (${InviteRules.inviterMax}명까지)';

  /// 카톡 카드 이미지 (docs/share/card.png 를 GitHub Pages 로 공개한 주소, 800×400).
  static const cardImage = 'https://alsdud110.github.io/haru_sari/share/card.png';

  static String kakaoTitle(String name) => '$name님의 루틴을 구경해 보세요';
  static String kakaoDescription(String code) => '하루살이에서 같이 해요 · 코드 $code';
  static const kakaoButton = '구경하러 가기';
}

/// 앱 밖의 안내 페이지.
class AppLinks {
  /// 개인정보 처리방침 (docs/privacy/index.html 을 GitHub Pages 로 공개한 주소).
  /// 스토어 등록 정보에도 같은 주소를 넣는다. 계정 삭제 안내는 이 주소 뒤에 #delete.
  static const privacy = 'https://alsdud110.github.io/haru_sari/privacy/';
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
