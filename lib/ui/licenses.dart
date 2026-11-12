import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'widgets.dart';

/// 앱에 넣은 글꼴의 저작권·라이선스 고지 (assets/fonts/LICENSE.txt 와 같은 내용).
const fontNoticePath = 'assets/fonts/LICENSE.txt';

const _fonts = [
  (name: 'LINE Seed Sans KR', use: '본문', copyright: '© LY Corporation'),
  (name: 'MaruBuri (마루 부리)', use: '격려 문구', copyright: '© NAVER Corp. © NAVER Cultural Foundation Corp.'),
  (
    name: 'Bricolage Grotesque',
    use: '영문·숫자 (영문·숫자만 남긴 부분 글꼴)',
    copyright: 'Copyright 2022 The Bricolage Grotesque Project Authors',
  ),
];

/// 플러터의 라이선스 목록(패키지 라이선스 화면)에도 글꼴 고지를 올린다. 앱 시작 때 한 번 부른다.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(fontNoticePath);
    yield LicenseEntryWithLineBreaks([for (final f in _fonts) f.name], text);
  });
}

/// 설정 > 오픈소스 라이선스
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('오픈소스 라이선스')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
        children: [
          Text('하루살이는 아래 글꼴을 SIL Open Font License 1.1에 따라 사용해요', style: t.bodyMedium),
          const SizedBox(height: Space.lg),
          for (final f in _fonts) ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name, style: t.titleMedium),
                  const SizedBox(height: Space.xs),
                  Text('쓰는 곳: ${f.use}', style: t.bodySmall),
                  const SizedBox(height: Space.xs),
                  Text(f.copyright, style: t.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
          ],
          const SizedBox(height: Space.md),
          OutlinedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _NoticeScreen())),
            child: const Text('글꼴 라이선스 전문 보기'),
          ),
          const SizedBox(height: Space.sm),
          OutlinedButton(
            onPressed: () => showLicensePage(context: context, applicationName: '하루살이'),
            child: const Text('앱에 쓰인 다른 오픈소스 보기'),
          ),
        ],
      ),
    );
  }
}

/// 고지 파일 전문 (저작권 문구 + SIL OFL 1.1)
class _NoticeScreen extends StatelessWidget {
  const _NoticeScreen();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('글꼴 라이선스')),
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(fontNoticePath),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('라이선스 글을 불러오지 못했어요', style: t.bodyMedium));
          }
          final text = snap.data;
          if (text == null) return const SizedBox.shrink();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
            child: SelectableText(text, style: t.bodySmall?.copyWith(color: AppColors.text, height: 1.5)),
          );
        },
      ),
    );
  }
}
