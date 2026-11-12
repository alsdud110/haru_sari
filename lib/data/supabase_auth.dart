import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../config.dart';
import 'auth.dart';
import 'store.dart';

/// Supabase 로그인.
///
/// - 카카오·구글: Supabase 웹 로그인 (브라우저로 열고 [SupabaseConfig.redirectUrl] 로 돌아온다).
///   앱에 카카오·구글 SDK 를 넣지 않아도 된다.
/// - Apple: iOS 기본 로그인 창 → ID 토큰을 Supabase 에 넘긴다. iOS 에서만 버튼을 보인다.
class SupabaseAuthService extends AuthService {
  SupabaseAuthService(this._kv) {
    _sub = _auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  final KeyValue _kv;
  late final StreamSubscription<AuthState> _sub;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  AuthUser? get current {
    final u = _auth.currentUser;
    if (u == null) return null;
    final meta = u.userMetadata ?? const {};
    final nick = ['nickname', 'name', 'full_name', 'user_name', 'preferred_username']
        .map((k) => meta[k])
        .whereType<String>()
        .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');
    final provider = SocialProvider.values.where((p) => p.name == u.appMetadata['provider']).firstOrNull;
    return AuthUser(uid: u.id, nickname: nick, provider: provider, email: u.email);
  }

  @override
  List<SocialProvider> get providers => [
    SocialProvider.kakao,
    SocialProvider.google,
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) SocialProvider.apple,
  ];

  @override
  Future<String?> signIn(SocialProvider provider) async {
    try {
      switch (provider) {
        case SocialProvider.kakao || SocialProvider.google:
          final opened = await _auth.signInWithOAuth(
            provider == SocialProvider.kakao ? OAuthProvider.kakao : OAuthProvider.google,
            redirectTo: SupabaseConfig.redirectUrl,
            authScreenLaunchMode: LaunchMode.externalApplication,
          );
          // 로그인 결과는 앱으로 돌아올 때 onAuthStateChange 로 들어온다.
          return opened ? null : '로그인 화면을 열지 못했어요';
        case SocialProvider.apple:
          return await _apple();
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return '';
      return 'Apple 로그인에 실패했어요. 잠시 뒤 다시 시도해 주세요';
    } on AuthException catch (e) {
      debugPrint('sign-in failed: ${e.message}');
      return '로그인에 실패했어요. 잠시 뒤 다시 시도해 주세요';
    } catch (e) {
      debugPrint('sign-in failed: $e');
      return '인터넷 연결을 확인하고 다시 시도해 주세요';
    }
  }

  Future<String?> _apple() async {
    final raw = _nonce();
    final cred = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.fullName],
      nonce: sha256.convert(utf8.encode(raw)).toString(),
    );
    final token = cred.identityToken;
    if (token == null) return 'Apple 로그인에 실패했어요';
    await _auth.signInWithIdToken(provider: OAuthProvider.apple, idToken: token, nonce: raw);
    // Apple 은 이름을 첫 로그인 때 한 번만 준다 → 메타데이터에 남겨둔다.
    final name = [cred.familyName, cred.givenName].whereType<String>().join();
    if (name.isNotEmpty && (current?.nickname.isEmpty ?? false)) {
      await _auth.updateUser(UserAttributes(data: {'nickname': name}));
    }
    return null;
  }

  static String _nonce() {
    final r = Random.secure();
    return base64UrlEncode(List.generate(32, (_) => r.nextInt(256)));
  }

  @override
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('sign-out failed: $e');
    }
    notifyListeners();
  }

  @override
  Future<String?> deleteAccount() async {
    final u = current;
    if (u == null) return '로그인이 필요해요';
    try {
      await Supabase.instance.client.rpc<void>('delete_account');
    } catch (e) {
      debugPrint('delete failed: $e');
      return '지우지 못했어요. 계정은 그대로 있어요. 인터넷 연결을 확인하고 다시 시도해 주세요';
    }
    await _kv.removePrefix(userPrefix(u.uid));
    // 서버에서 계정이 지워졌으니 이 기기의 세션만 정리한다.
    try {
      await _auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    notifyListeners();
    return null;
  }

  @override
  Future<void> debugReset() async {
    await _kv.removePrefix('');
    await logout();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
