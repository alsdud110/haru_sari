import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'store.dart';

class Account {
  Account({required this.uid, required this.email, required this.nickname, required this.salt, required this.hash});
  final String uid;
  String email;
  String nickname;
  String salt;
  String hash;

  Map<String, dynamic> toJson() => {'uid': uid, 'email': email, 'nickname': nickname, 'salt': salt, 'hash': hash};
  factory Account.fromJson(Map<String, dynamic> j) => Account(
    uid: j['uid'] as String,
    email: j['email'] as String,
    nickname: j['nickname'] as String,
    salt: j['salt'] as String,
    hash: j['hash'] as String,
  );
}

/// 계정 관리.
///
/// 지금은 **기기 안에만** 계정을 저장한다 (비밀번호는 솔트+SHA-256 해시).
/// 서버 계정(Firebase 등)으로 바꿀 때는 이 클래스와 같은 메서드를 가진
/// 구현으로 갈아 끼우면 된다.
class AuthService extends ChangeNotifier {
  AuthService(this._kv) {
    final raw = _kv.read(_kAccounts);
    if (raw != null) {
      for (final e in (jsonDecode(raw) as List)) {
        final a = Account.fromJson((e as Map).cast<String, dynamic>());
        _accounts[a.email] = a;
      }
    }
    final uid = _kv.read(_kSession);
    if (uid != null && uid.isNotEmpty) {
      current = _accounts.values.where((a) => a.uid == uid).firstOrNull;
    }
  }

  final KeyValue _kv;
  static const _kAccounts = 'accounts';
  static const _kSession = 'session';
  final Map<String, Account> _accounts = {};
  Account? current;

  bool get signedIn => current != null;

  static String _norm(String email) => email.trim().toLowerCase();

  static String? validateEmail(String email) {
    final e = email.trim();
    if (e.isEmpty) return '이메일을 입력해 주세요';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return '이메일 형식이 맞지 않아요';
    return null;
  }

  static String? validatePassword(String pw) {
    if (pw.length < 8) return '비밀번호는 8자 이상이에요';
    return null;
  }

  String _hash(String salt, String pw) => sha256.convert(utf8.encode('$salt:$pw')).toString();

  String _salt() {
    final r = Random.secure();
    return base64UrlEncode(List.generate(16, (_) => r.nextInt(256)));
  }

  Future<void> _save() async {
    await _kv.write(_kAccounts, jsonEncode(_accounts.values.map((a) => a.toJson()).toList()));
    await _kv.write(_kSession, current?.uid ?? '');
  }

  /// 성공하면 null, 실패하면 안내 문구.
  String? signUp({required String email, required String password, required String nickname}) {
    final ee = validateEmail(email);
    if (ee != null) return ee;
    final pe = validatePassword(password);
    if (pe != null) return pe;
    if (nickname.trim().isEmpty) return '닉네임을 입력해 주세요';
    final key = _norm(email);
    if (_accounts.containsKey(key)) return '이미 가입된 이메일이에요. 로그인해 주세요';
    final salt = _salt();
    final a = Account(
      uid: 'u${DateTime.now().microsecondsSinceEpoch}',
      email: key,
      nickname: nickname.trim(),
      salt: salt,
      hash: _hash(salt, password),
    );
    _accounts[key] = a;
    current = a;
    _save();
    notifyListeners();
    return null;
  }

  String? login({required String email, required String password}) {
    final a = _accounts[_norm(email)];
    if (a == null || a.hash != _hash(a.salt, password)) return '이메일 또는 비밀번호가 맞지 않아요';
    current = a;
    _save();
    notifyListeners();
    return null;
  }

  void logout() {
    current = null;
    _save();
    notifyListeners();
  }

  String? updateAccount({String? nickname, String? email}) {
    final a = current;
    if (a == null) return '로그인이 필요해요';
    if (email != null && _norm(email) != a.email) {
      final ee = validateEmail(email);
      if (ee != null) return ee;
      if (_accounts.containsKey(_norm(email))) return '이미 쓰고 있는 이메일이에요';
      _accounts.remove(a.email);
      a.email = _norm(email);
      _accounts[a.email] = a;
    }
    if (nickname != null && nickname.trim().isNotEmpty) a.nickname = nickname.trim();
    _save();
    notifyListeners();
    return null;
  }

  /// 계정 삭제. 비밀번호를 다시 확인하고, 이 계정의 루틴과 기록도 함께 지운다.
  /// (기능명세서 F-ZZZULL의 추천안: 함께 삭제 · 확인 화면과 재인증 · 실패 시 계정 유지)
  Future<String?> deleteAccount({required String password}) async {
    final a = current;
    if (a == null) return '로그인이 필요해요';
    if (a.hash != _hash(a.salt, password)) return '비밀번호가 맞지 않아요';
    try {
      await _kv.removePrefix(userPrefix(a.uid));
    } catch (_) {
      return '지우지 못했어요. 계정은 그대로 있어요. 잠시 뒤 다시 시도해 주세요';
    }
    _accounts.remove(a.email);
    current = null;
    await _save();
    notifyListeners();
    return null;
  }

  String? changePassword({required String oldPassword, required String newPassword}) {
    final a = current;
    if (a == null) return '로그인이 필요해요';
    if (a.hash != _hash(a.salt, oldPassword)) return '지금 비밀번호가 맞지 않아요';
    final pe = validatePassword(newPassword);
    if (pe != null) return pe;
    a.salt = _salt();
    a.hash = _hash(a.salt, newPassword);
    _save();
    return null;
  }
}
