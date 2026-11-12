import 'package:flutter/material.dart';

import '../app.dart';
import '../data/auth.dart';
import '../data/models.dart';
import '../theme/tokens.dart';
import 'motion.dart';
import 'room/room_painter.dart';
import 'today.dart' show keepWords;

/// 소개 (온보딩 캐러셀) → 회원가입 / 로그인
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
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.lg),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                    child: const Text('시작하기'),
                  ),
                  const SizedBox(height: Space.sm),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('이미 계정이 있어요'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nick = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final c in [_nick, _email, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_pw.text != _pw2.text) {
      setState(() => _error = '비밀번호가 서로 달라요');
      return;
    }
    final err = AuthScope.read(context).signUp(email: _email.text, password: _pw.text, nickname: _nick.text);
    setState(() => _error = err);
    // 성공하면 앱이 첫 설정 화면으로 바뀐다.
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: '반가워요',
      subtitle: '기록은 이 계정에 담겨요.',
      error: _error,
      fields: [
        TextField(
          controller: _nick,
          maxLength: 10,
          decoration: const InputDecoration(labelText: '닉네임', counterText: ''),
        ),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: '이메일'),
        ),
        TextField(
          controller: _pw,
          obscureText: true,
          decoration: const InputDecoration(labelText: '비밀번호', helperText: '8자 이상'),
        ),
        TextField(
          controller: _pw2,
          obscureText: true,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(labelText: '비밀번호 확인'),
        ),
      ],
      action: FilledButton(onPressed: _submit, child: const Text('가입하고 시작하기')),
      footer: TextButton(
        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
        child: const Text('이미 계정이 있어요'),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  void _submit() {
    final err = AuthScope.read(context).login(email: _email.text, password: _pw.text);
    setState(() => _error = err);
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: '다시 만나서 반가워요',
      subtitle: '오늘도 천천히 시작해요.',
      error: _error,
      fields: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: '이메일'),
        ),
        TextField(
          controller: _pw,
          obscureText: true,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(labelText: '비밀번호'),
        ),
      ],
      action: FilledButton(onPressed: _submit, child: const Text('로그인')),
      footer: TextButton(
        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
        child: const Text('처음이에요, 가입할게요'),
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.action,
    required this.footer,
    this.error,
  });
  final String title;
  final String subtitle;
  final List<Widget> fields;
  final Widget action;
  final Widget footer;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
          children: [
            Reveal(index: 0, child: Text(title, style: t.headlineMedium)),
            const SizedBox(height: Space.xs),
            Reveal(
              index: 1,
              child: Text(subtitle, style: t.bodyLarge?.copyWith(color: AppColors.textMuted)),
            ),
            const SizedBox(height: Space.xl),
            for (final f in fields) ...[f, const SizedBox(height: Space.md)],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: Text(error!, style: t.bodyMedium?.copyWith(color: AppColors.primary)),
              ),
            const SizedBox(height: Space.sm),
            action,
            const SizedBox(height: Space.sm),
            Center(child: footer),
            const SizedBox(height: Space.lg),
            Text('계정과 기록은 이 기기에 저장돼요.', style: t.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// 계정 정보 수정 (닉네임·이메일·비밀번호)
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final AuthService auth = AuthScope.read(context);
  late final _nick = TextEditingController(text: AppScope.read(context).profile.name);
  late final _email = TextEditingController(text: auth.current?.email ?? '');
  final _old = TextEditingController();
  final _new = TextEditingController();
  String? _msg;
  bool _ok = false;

  @override
  void dispose() {
    for (final c in [_nick, _email, _old, _new]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final s = AppScope.read(context);
    var err = auth.updateAccount(nickname: _nick.text, email: _email.text);
    if (err == null && (_old.text.isNotEmpty || _new.text.isNotEmpty)) {
      err = auth.changePassword(oldPassword: _old.text, newPassword: _new.text);
    }
    if (err == null) {
      s.updateProfileName(_nick.text);
      _old.clear();
      _new.clear();
    }
    setState(() {
      _ok = err == null;
      _msg = err ?? '저장했어요';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: '이메일'),
          ),
          const SizedBox(height: Space.xl),
          Text('비밀번호 변경', style: t.titleMedium),
          const SizedBox(height: Space.sm),
          TextField(
            controller: _old,
            obscureText: true,
            decoration: const InputDecoration(labelText: '지금 비밀번호'),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _new,
            obscureText: true,
            decoration: const InputDecoration(labelText: '새 비밀번호', helperText: '8자 이상'),
          ),
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
    final pw = TextEditingController();
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
              const Text('이 계정의 루틴, 기록, 방, 배지가 모두 함께 지워지고 되돌릴 수 없어요.\n계속하려면 비밀번호를 입력해 주세요.'),
              const SizedBox(height: Space.md),
              TextField(
                controller: pw,
                obscureText: true,
                decoration: InputDecoration(labelText: '비밀번호', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('그대로 둘게요')),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      setLocal(() => busy = true);
                      final err = await auth.deleteAccount(password: pw.text);
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
    pw.dispose();
  }
}

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
  if (ok == true && context.mounted) AuthScope.read(context).logout();
}
