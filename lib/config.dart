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
