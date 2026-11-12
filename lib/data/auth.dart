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

  /// 로그인 없이 들어온 개발자 모드 계정인지
  bool get isDeveloper => uid == AuthService.devUid;
}

/// 계정 관리.
///
/// 실제 앱은 [SupabaseAuthService](supabase_auth.dart)를 쓴다.
/// 테스트는 서버 없이 도는 [DeviceAuthService]를 쓴다.
///
/// **개발자 모드**: 디버그 빌드에서만, 로그인 없이 이 기기 전용 계정([devUid])으로 들어간다.
/// 서버와 동기화하지 않고 기록은 이 기기에만 남는다. 출시 빌드에서는 켤 수 없다.
abstract class AuthService extends ChangeNotifier {
  AuthService(this.kv) : _dev = kDebugMode && kv.read(_kDev) == 'true';

  @protected
  final KeyValue kv;

  static const devUid = 'dev-local';
  static const _kDev = 'devMode';
  bool _dev;

  /// 실제로 로그인한 계정 (개발자 모드는 빼고)
  @protected
  AuthUser? get account;

  AuthUser? get current => _dev ? const AuthUser(uid: devUid, nickname: '') : account;
  bool get signedIn => current != null;

  /// 이 기기에서 보여줄 로그인 버튼 (Apple 은 iOS 에서만).
  List<SocialProvider> get providers;

  /// 성공하면 null, 실패하면 안내 문구. 취소는 '' (안내 없이 조용히 끝낸다).
  Future<String?> signIn(SocialProvider provider);

  /// 로그인 없이 개발자 모드로 들어간다. 디버그 빌드가 아니면 아무 일도 하지 않고 false.
  Future<bool> signInAsDeveloper() async {
    if (!kDebugMode) return false;
    _dev = true;
    await kv.write(_kDev, 'true');
    notifyListeners();
    return true;
  }

  Future<void> _leaveDeveloper() async {
    _dev = false;
    await kv.write(_kDev, '');
    notifyListeners();
  }

  Future<void> logout() => _dev ? _leaveDeveloper() : signOutAccount();

  /// 계정 삭제. 서버의 계정·기록과 이 기기의 기록을 함께 지운다.
  /// 성공하면 null, 실패하면 안내 문구 (계정은 그대로 둔다).
  Future<String?> deleteAccount() async {
    if (!_dev) return deleteSignedInAccount();
    await kv.removePrefix(userPrefix(devUid));
    await _leaveDeveloper();
    return null;
  }

  /// 개발용: 이 기기의 기록을 지우고 로그아웃한다.
  Future<void> debugReset() async {
    await kv.removePrefix('');
    _dev = false;
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
