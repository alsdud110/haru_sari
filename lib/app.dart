import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/ads.dart';
import 'data/app_update.dart';
import 'data/auth.dart';
import 'data/friend_alarm_sync.dart';
import 'data/kakao_share.dart';
import 'data/reminders.dart';
import 'data/store.dart';
import 'data/routine_sharing.dart';
import 'data/sync.dart';
import 'room/manifest.dart';
import 'room/registry.dart';
import 'theme/tokens.dart';
import 'ui/auth_screens.dart';
import 'ui/friends/invite_scope.dart';
import 'ui/motion.dart';
import 'ui/onboarding.dart';
import 'ui/shell.dart';
import 'ui/update_prompt.dart';

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

/// 끝까지 스크롤했을 때 고무줄처럼 늘어나거나 튕기지 않고 그 자리에서 멈춘다.
class _NoBounceScrollBehavior extends MaterialScrollBehavior {
  const _NoBounceScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

class HaruSariApp extends StatefulWidget {
  const HaruSariApp({
    super.key,
    required this.kv,
    required this.auth,
    this.reminders,
    this.ads,
    this.clock,
    this.manifest,
    this.remoteFor,
    this.checkUpdate,
    this.invites,
  });
  final KeyValue kv;

  /// 카카오톡 공유·초대 링크 받기. 없으면 카카오톡 버튼을 숨긴다 (테스트).
  final FriendInvites? invites;
  final AuthService auth;
  final Reminders? reminders;

  /// 보상형 광고. 없으면 광고 버튼이 보이지 않는다 (테스트).
  final RewardAds? ads;
  final DateTime Function()? clock;
  final PixelManifest? manifest;

  /// 로그인한 사용자의 서버 저장소. 없으면 기기에만 저장한다 (테스트).
  final Remote? Function(String uid)? remoteFor;

  /// 서버에 업데이트 안내를 묻는다. 없으면 묻지 않는다 (테스트).
  final Future<AppUpdate?> Function()? checkUpdate;

  @override
  State<HaruSariApp> createState() => _HaruSariAppState();
}

class _HaruSariAppState extends State<HaruSariApp> with WidgetsBindingObserver {
  AppState? _state;

  /// 픽셀 에셋 이미지 캐시 (계정과 무관하므로 앱 전체에서 하나)
  late final AssetRegistry? _registry = widget.manifest == null ? null : AssetRegistry(widget.manifest!);
  String? _uid;

  /// 업데이트 안내는 앱을 켤 때 한 번만 묻고 한 번만 띄운다.
  late Future<AppUpdate?>? _update = widget.checkUpdate?.call();

  Future<AppUpdate?>? _takeUpdate() {
    final f = _update;
    _update = null;
    return f;
  }

  AppState _stateFor(String uid) {
    if (_uid != uid || _state == null) {
      _disposeState();
      _uid = uid;
      final kv = PrefixedKeyValue(widget.kv, userPrefix(uid));
      _state = AppState(
        kv,
        clock: widget.clock,
        reminders: widget.reminders,
        ads: widget.ads,
        initialName: widget.auth.current?.nickname ?? '',
        manifest: widget.manifest,
      );
      if (_state!.onboarded) _state!.syncReminders();
      final remote = widget.remoteFor?.call(uid);
      if (remote != null) {
        final engine = SyncEngine(_state!, remote, kv, clock: widget.clock);
        _state!.sync = engine;
        engine.start();
        _state!.sharing = RoutineSharing(_state!, remote, kv)..flush();
        refreshFriendAlarms(_state!, remote);
      }
    }
    return _state!;
  }

  /// 카톡 카드로 받은 초대 코드 (로그인·첫 설정 뒤 홈에서 연다)
  late final PendingInvite _pending = PendingInvite(widget.kv);

  @override
  void initState() {
    super.initState();
    widget.invites?.listen(_pending.receive);
    widget.auth.addListener(_onAuth);
    WidgetsBinding.instance.addObserver(this);
  }

  /// 앱으로 돌아오면 못 보낸 것을 다시 보낸다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _state?.sync?.flush();
      _state?.sharing?.flush();
      final s = _state, remote = s?.sync?.remote;
      if (s != null && remote != null) refreshFriendAlarms(s, remote);
    }
  }

  void _disposeState() {
    _state?.sync?.dispose();
    _state?.sharing?.dispose();
    _state?.dispose();
    _state = null;
  }

  void _onAuth() {
    if (!widget.auth.signedIn) {
      widget.reminders?.clear();
      _disposeState();
      _uid = null;
    }
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuth);
    WidgetsBinding.instance.removeObserver(this);
    _disposeState();
    super.dispose();
  }

  MaterialApp _app({Key? key, required Widget home}) => MaterialApp(
    key: key,
    title: '하루살이',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    scrollBehavior: const _NoBounceScrollBehavior(),
    // 시간 휠의 오전·오후, 기본 창의 버튼 글 등을 한국어로
    locale: const Locale('ko', 'KR'),
    supportedLocales: const [Locale('ko', 'KR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: UpdatePrompt(take: _takeUpdate, kv: widget.kv, child: home),
  );

  @override
  Widget build(BuildContext context) {
    final app = AuthScope(
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
    final reg = _registry;
    final scoped = InviteScope(pending: _pending, invites: widget.invites, child: app);
    return reg == null ? scoped : RegistryScope(registry: reg, child: scoped);
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pulling = s.sync?.pulling;
    Widget pick() => !s.onboarded
        ? const SetupFlow()
        : s.sync == null
        ? const HomeShell()
        : const InviteOpener(child: HomeShell());
    if (pulling == null) return AnimatedSwitcher(duration: Motion.slow, child: pick());
    // 새 기기: 서버에서 받아오는 동안 첫 설정 화면 대신 잠깐 기다린다.
    return ValueListenableBuilder<bool>(
      valueListenable: pulling,
      builder: (context, busy, _) => AnimatedSwitcher(
        duration: Motion.slow,
        child: busy && !s.onboarded
            ? const Scaffold(
                key: ValueKey('pulling'),
                body: Center(child: AppSpinner()),
              )
            : pick(),
      ),
    );
  }
}
