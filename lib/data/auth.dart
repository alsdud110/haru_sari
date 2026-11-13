import 'package:flutter/foundation.dart';

import 'store.dart';

/// 로그인 수단. 이메일·비밀번호 가입은 두지 않는다.
enum SocialProvider {
  kakao('카카오'),
  google('구글'),
  apple('Apple');

  const SocialProvider(this.label);
  final String label;
}

class AuthUser {
  const AuthUser({required this.uid, required this.nickname, this.provider, this.email});
  final String uid;
  final String nickname;
  final SocialProvider? provider;
  final String? email;
}

/// 계정 관리.
///
/// 실제 앱은 [SupabaseAuthService](supabase_auth.dart)를 쓴다.
/// 테스트는 서버 없이 도는 [DeviceAuthService]를 쓴다.
abstract class AuthService extends ChangeNotifier {
  AuthService(this.kv);

  @protected
  final KeyValue kv;

  /// 로그인한 계정 (없으면 null)
  @protected
  AuthUser? get account;

  AuthUser? get current => account;
  bool get signedIn => current != null;

  /// 이 기기에서 보여줄 로그인 버튼 (Apple 은 iOS 에서만).
  List<SocialProvider> get providers;

  /// 성공하면 null, 실패하면 안내 문구. 취소는 '' (안내 없이 조용히 끝낸다).
  Future<String?> signIn(SocialProvider provider);

  Future<void> logout() => signOutAccount();

  /// 계정 삭제. 서버의 계정·기록과 이 기기의 기록을 함께 지운다.
  /// 성공하면 null, 실패하면 안내 문구 (계정은 그대로 둔다).
  Future<String?> deleteAccount() => deleteSignedInAccount();

  /// 개발용: 이 기기의 기록을 지우고 로그아웃한다.
  Future<void> debugReset() async {
    await kv.removePrefix('');
    await signOutAccount();
  }

  @protected
  Future<void> signOutAccount();

  @protected
  Future<String?> deleteSignedInAccount();
}

/// 서버 없이 기기 안에서만 도는 로그인. 테스트용.
class DeviceAuthService extends AuthService {
  DeviceAuthService(super.kv, {List<SocialProvider>? providers}) : providers = providers ?? SocialProvider.values {
    final uid = kv.read(_kSession);
    if (uid != null && uid.isNotEmpty) _account = _user(uid);
  }

  static const _kSession = 'session';

  @override
  final List<SocialProvider> providers;

  AuthUser? _account;
  @override
  AuthUser? get account => _account;

  /// 다음 signIn 이 돌려줄 결과 (테스트에서 실패·취소를 흉내 낸다).
  String? nextError;

  static AuthUser _user(String uid) {
    final p = SocialProvider.values.where((p) => uid == 'dev-${p.name}').firstOrNull;
    return AuthUser(uid: uid, nickname: '', provider: p);
  }

  @override
  Future<String?> signIn(SocialProvider provider) async {
    final err = nextError;
    nextError = null;
    if (err != null) return err;
    _account = _user('dev-${provider.name}');
    await kv.write(_kSession, _account!.uid);
    notifyListeners();
    return null;
  }

  @override
  Future<void> signOutAccount() async {
    _account = null;
    await kv.write(_kSession, '');
    notifyListeners();
  }

  @override
  Future<String?> deleteSignedInAccount() async {
    final u = _account;
    if (u == null) return '로그인이 필요해요';
    await kv.removePrefix(userPrefix(u.uid));
    await signOutAccount();
    return null;
  }
}
