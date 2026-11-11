import 'package:flutter/material.dart';

import 'data/auth.dart';
import 'data/reminders.dart';
import 'data/store.dart';
import 'room/manifest.dart';
import 'theme/tokens.dart';
import 'ui/auth_screens.dart';
import 'ui/onboarding.dart';
import 'ui/shell.dart';

/// 위젯 트리 어디서나 AppState를 꺼내 쓰고, 바뀌면 다시 그린다.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// 다시 그리지 않고 읽기만 할 때.
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class AuthScope extends InheritedNotifier<AuthService> {
  const AuthScope({super.key, required AuthService auth, required super.child}) : super(notifier: auth);

  static AuthService of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AuthScope>()!.notifier!;
  static AuthService read(BuildContext context) => context.getInheritedWidgetOfExactType<AuthScope>()!.notifier!;
}

class OneulSariApp extends StatefulWidget {
  const OneulSariApp({super.key, required this.kv, required this.auth, this.reminders, this.clock, this.manifest});
  final KeyValue kv;
  final AuthService auth;
  final Reminders? reminders;
  final DateTime Function()? clock;
  final AssetManifest? manifest;

  @override
  State<OneulSariApp> createState() => _OneulSariAppState();
}

class _OneulSariAppState extends State<OneulSariApp> {
  AppState? _state;
  String? _uid;

  AppState _stateFor(String uid) {
    if (_uid != uid || _state == null) {
      _state?.dispose();
      _uid = uid;
      _state = AppState(
        PrefixedKeyValue(widget.kv, userPrefix(uid)),
        clock: widget.clock,
        reminders: widget.reminders,
        initialName: widget.auth.current?.nickname ?? '',
        manifest: widget.manifest,
      );
      if (_state!.onboarded) _state!.syncReminders();
    }
    return _state!;
  }

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuth);
  }

  void _onAuth() {
    if (!widget.auth.signedIn) {
      widget.reminders?.clear();
      _state?.dispose();
      _state = null;
      _uid = null;
    }
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuth);
    _state?.dispose();
    super.dispose();
  }

  MaterialApp _app({Key? key, required Widget home}) =>
      MaterialApp(key: key, title: '오늘살이', debugShowCheckedModeBanner: false, theme: buildTheme(), home: home);

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      auth: widget.auth,
      child: ListenableBuilder(
        listenable: widget.auth,
        builder: (context, _) {
          final uid = widget.auth.current?.uid;
          if (uid == null) return _app(key: const ValueKey('signed-out'), home: const IntroScreen());
          return AppScope(
            key: ValueKey(uid),
            state: _stateFor(uid),
            child: _app(home: const _Gate()),
          );
        },
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return AnimatedSwitcher(duration: Motion.slow, child: s.onboarded ? const HomeShell() : const SetupFlow());
  }
}
