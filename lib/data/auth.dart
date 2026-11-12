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
  AuthUser? get current;
  bool get signedIn => current != null;

  /// 이 기기에서 보여줄 로그인 버튼 (Apple 은 iOS 에서만).
  List<SocialProvider> get providers;

  /// 성공하면 null, 실패하면 안내 문구. 취소는 '' (안내 없이 조용히 끝낸다).
  Future<String?> signIn(SocialProvider provider);

  Future<void> logout();

  /// 계정 삭제. 서버의 계정·기록과 이 기기의 기록을 함께 지운다.
  /// 성공하면 null, 실패하면 안내 문구 (계정은 그대로 둔다).
  Future<String?> deleteAccount();

  /// 개발용: 이 기기의 기록을 지우고 로그아웃한다.
  Future<void> debugReset();
}

/// 서버 없이 기기 안에서만 도는 로그인. 테스트용.
class DeviceAuthService extends AuthService {
  DeviceAuthService(this._kv, {List<SocialProvider>? providers})
    : providers = providers ?? SocialProvider.values {
    final uid = _kv.read(_kSession);
    if (uid != null && uid.isNotEmpty) _current = _user(uid);
  }

  final KeyValue _kv;
  static const _kSession = 'session';

  @override
  final List<SocialProvider> providers;

  AuthUser? _current;
  @override
  AuthUser? get current => _current;

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
    _current = _user('dev-${provider.name}');
    await _kv.write(_kSession, _current!.uid);
    notifyListeners();
    return null;
  }

  @override
  Future<void> logout() async {
    _current = null;
    await _kv.write(_kSession, '');
    notifyListeners();
  }

  @override
  Future<String?> deleteAccount() async {
    final u = _current;
    if (u == null) return '로그인이 필요해요';
    await _kv.removePrefix(userPrefix(u.uid));
    await logout();
    return null;
  }

  @override
  Future<void> debugReset() async {
    await _kv.removePrefix('');
    _current = null;
    notifyListeners();
  }
}
