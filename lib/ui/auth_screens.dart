import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app.dart';
import '../data/auth.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import 'motion.dart';
import 'room/room_painter.dart';
import 'today.dart' show keepWords;

/// 소개 (온보딩 캐러셀) → 소셜 로그인
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _page = PageController();
  int _i = 0;

  static const _slides = [
    (
      (Icons.wb_sunny_rounded, AppColors.coin, AppColors.coinSoft),
      '평범한 하루도\n충분히 소중해요',
      '기상, 식사, 산책 — 작은 루틴을 기록하며\n오늘 하루를 살아낸 나를 응원해 보세요',
    ),
    ((Icons.check_rounded, AppColors.sage, AppColors.sageSoft), '부담 없이,\n나만의 속도로', '완벽하지 않아도 괜찮아요.\n체크 하나로 오늘을 완성하세요'),
    (
      (Icons.home_rounded, AppColors.primary, AppColors.primarySoft),
      '작은 성취가 쌓여\n나만의 공간이 돼요',
      '루틴을 이어갈수록 미니미 방이 따뜻하게 채워져요.\n오늘도 한 걸음이면 충분해요',
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (context, i) {
                  final ((icon, color, soft), title, body) = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Reveal(
                          index: 0,
                          child: i == 2
                              ? Breathing(child: MinimiView(profile: Profile(), happy: true, width: 120))
                              : CircleAvatar(
                                  radius: 60,
                                  backgroundColor: soft,
                                  child: Icon(icon, size: 64, color: color),
                                ),
                        ),
                        const SizedBox(height: Space.xl),
                        Reveal(
                          index: 1,
                          child: Text(title, style: t.headlineMedium, textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: Space.md),
                        Reveal(
                          index: 2,
                          child: Text(
                            keepWords(body),
                            style: t.bodyLarge?.copyWith(color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: Motion.normal,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _i ? AppColors.primary : AppColors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            // 소개를 다 본 마지막 장에서만 로그인을 권한다. 앞 장에서는 '다음'과 '건너뛰기'.
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.lg),
              // 장마다 높이가 같아야 넘길 때 위쪽 그림과 글이 움직이지 않는다.
              child: SizedBox(
                height: AuthScope.of(context).providers.length * 60 + 32,
                child: AnimatedSwitcher(
                  duration: Motion.normal,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.bottomCenter,
                    children: [...previous, ?current],
                  ),
                  child: _i == _slides.length - 1
                      ? const SocialButtons(key: ValueKey('login'))
                      : Column(
                          key: const ValueKey('next'),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton(onPressed: () => _to(_i + 1), child: const Text('다음')),
                            const SizedBox(height: Space.xs),
                            TextButton(onPressed: () => _to(_slides.length - 1), child: const Text('건너뛰기')),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _to(int i) => _page.animateToPage(i, duration: Motion.normal, curve: Motion.curve);
}

/// 공식 로고 (각 회사 로그인 버튼 가이드의 심볼).
const _kakaoSymbol =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18"><path fill="#000000" d="M9 .6C4.03.6 0 3.713 0 7.552c0 2.388 1.558 4.493 3.932 5.745l-.999 3.648c-.088.322.28.579.563.392l4.377-2.889c.37.036.745.057 1.127.057 4.97 0 9-3.113 9-6.953C18 3.713 13.97.6 9 .6"/></svg>';
const _googleG =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>'
    '<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>'
    '<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>'
    '<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>'
    '</svg>';

/// 카카오 · 구글 · Apple 로그인 버튼.
///
/// 색과 문구는 각 회사의 로그인 버튼 가이드를 따른다 (앱 색 토큰 대신 브랜드 색).
class SocialButtons extends StatefulWidget {
  const SocialButtons({super.key});
  @override
  State<SocialButtons> createState() => _SocialButtonsState();
}

class _SocialButtonsState extends State<SocialButtons> {
  SocialProvider? _busy;
  String? _error;

  static const _kakaoYellow = Color(0xFFFEE500);
  static const _kakaoText = Color(0xD9000000);
  static const _googleText = Color(0xFF1F1F1F);
  static const _googleBorder = Color(0xFF747775);

  Future<void> _go(SocialProvider p) async {
    setState(() {
      _busy = p;
      _error = null;
    });
    final err = await AuthScope.read(context).signIn(p);
    if (!mounted) return;
    setState(() {
      _busy = null;
      _error = (err == null || err.isEmpty) ? null : err;
    });
    // 성공하면 앱이 첫 설정 화면(또는 홈)으로 바뀐다.
  }

  /// 로고는 왼쪽, 문구는 가운데 (세 회사 가이드 공통 배치).
  Widget _button(SocialProvider p) {
    final (bg, fg, border, logo, label) = switch (p) {
      SocialProvider.kakao => (
        _kakaoYellow,
        _kakaoText,
        null,
        SvgPicture.string(_kakaoSymbol, width: 20, height: 20),
        '카카오로 시작하기',
      ),
      SocialProvider.google => (
        Colors.white,
        _googleText,
        _googleBorder,
        SvgPicture.string(_googleG, width: 20, height: 20),
        'Google로 시작하기',
      ),
      SocialProvider.apple => (
        Colors.black,
        Colors.white,
        null,
        const Icon(Icons.apple, size: 24, color: Colors.white),
        'Apple로 계속하기',
      ),
    };
    final busy = _busy == p;
    final enabled = _busy == null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: enabled || busy ? 1 : 0.5,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            side: border == null ? BorderSide.none : BorderSide(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? () => _go(p) : null,
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 20,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(child: busy ? AppSpinner(size: 18, color: fg) : logo),
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final providers = AuthScope.of(context).providers;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in providers) ...[_button(p), const SizedBox(height: Space.sm)],
        const SizedBox(height: Space.xs),
        // 실패 안내는 아래 한 줄 자리에 대신 보여준다 (버튼 자리가 밀리지 않게).
        Text(
          _error ?? '가입 절차 없이 쓰던 계정으로 바로 시작해요.',
          style: _error == null ? t.bodySmall : t.bodySmall?.copyWith(color: AppColors.primary),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// 계정 정보 (닉네임 · 로그인 수단 · 계정 삭제)
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final _nick = TextEditingController(text: AppScope.read(context).profile.name);
  String? _msg;
  bool _ok = false;

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nick.text.trim();
    if (name.isEmpty) {
      setState(() {
        _ok = false;
        _msg = '닉네임을 입력해 주세요';
      });
      return;
    }
    AppScope.read(context).updateProfileName(name);
    setState(() {
      _ok = true;
      _msg = '저장했어요';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final user = AuthScope.of(context).current;
    return Scaffold(
      appBar: AppBar(title: const Text('계정 정보')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
        children: [
          TextField(
            controller: _nick,
            maxLength: 10,
            decoration: const InputDecoration(labelText: '닉네임', counterText: ''),
          ),
          const SizedBox(height: Space.md),
          Text('로그인 수단', style: t.titleMedium),
          const SizedBox(height: Space.xs),
          Text(accountLabel(user), style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: Space.lg),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: Text(_msg!, style: t.bodyMedium?.copyWith(color: _ok ? AppColors.sage : AppColors.primary)),
            ),
          FilledButton(onPressed: _save, child: const Text('저장')),
          const SizedBox(height: Space.xxl),
          const Divider(color: AppColors.line),
          const SizedBox(height: Space.sm),
          Center(
            child: TextButton(
              onPressed: () => _confirmDelete(context),
              child: const Text('계정 삭제', style: TextStyle(color: AppColors.textMuted)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    String? error;
    var busy = false;
    final auth = AuthScope.read(context);
    await showAppDialog<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('계정을 삭제할까요?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('이 계정의 루틴, 기록, 레벨과 코인, 방, 배지가 모두 함께 지워지고 되돌릴 수 없어요.'),
              if (error != null) ...[
                const SizedBox(height: Space.md),
                Text(error!, style: const TextStyle(color: AppColors.primary)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('그대로 둘게요')),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      setLocal(() => busy = true);
                      final err = await auth.deleteAccount();
                      if (err != null) {
                        if (ctx.mounted) {
                          setLocal(() {
                            busy = false;
                            error = err;
                          });
                        }
                      } else if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                    },
              child: busy
                  ? const AppSpinner(size: 18, color: AppColors.primary)
                  : const Text('삭제', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

/// '카카오 계정 · a@b.com' 같은 로그인 수단 표시.
String accountLabel(AuthUser? user) => [
  if (user?.provider case final p?) '${p.label} 계정',
  if (user?.email case final e? when e.isNotEmpty) e,
].join(' · ');

/// 로그아웃 확인
Future<void> confirmLogout(BuildContext context) async {
  final ok = await showAppDialog<bool>(
    context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('로그아웃할까요?'),
      content: const Text('기록은 이 기기에 그대로 남아요.\n다시 로그인하면 이어서 쓸 수 있어요.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('로그아웃')),
      ],
    ),
  );
  if (ok == true && context.mounted) await AuthScope.read(context).logout();
}

