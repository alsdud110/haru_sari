import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

/// 하루살이 디자인 토큰. 위젯에서 색·간격을 직접 쓰지 말고 여기서 가져온다.
class AppColors {
  static const background = Color(0xFFF7F0E6); // 크림색 종이. 테두리 없는 흰 면이 떠 보이게 한 단계 짙다
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF3EBE0);
  static const line = Color(0xFFE8DDCF);
  static const selected = Color(0xFFEBE1D3); // 탭·칸 선택 표시. 노을빛은 달성률에만 쓴다

  static const text = Color(0xFF3B3129);
  static const textMuted = Color(0xFF7B7266); // 흰 바탕에서 4.7:1

  static const primary = Color(0xFFE08A5B); // 노을빛 테라코타
  static const primaryInk = Color(0xFFA8552B); // 글자로 쓸 때 (흰 바탕 5.2:1)
  static const primarySoft = Color(0xFFF8DCCB);
  static const sage = Color(0xFF8FAE8B); // 완료·성장
  static const sageInk = Color(0xFF4F7A4B); // 글자로 쓸 때 (흰 바탕 5.0:1)
  static const sageSoft = Color(0xFFDCE8D8);
  static const coin = Color(0xFFE5B547);
  static const coinSoft = Color(0xFFFBEFCB);
  static const sky = Color(0xFF9DBBD8);

  // 방 그림용
  static const wall = Color(0xFFF2E6D8);
  static const wallShade = Color(0xFFE9D9C6);
  static const floor = Color(0xFFD9B993);
  static const floorShade = Color(0xFFCBA87F);
  static const wood = Color(0xFFB98559);
  static const woodDark = Color(0xFF8E6240);
}

class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const gutter = 20.0;
}

class Radii {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
}

class Motion {
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 520);
  static const curve = Curves.easeOutCubic;
}

/// 애플 기기면 iOS(HIG) 모양, 그 밖에는 머티리얼 3 모양을 쓴다.
/// 글꼴. 본문은 LINE Seed Sans KR, 영문·숫자는 Bricolage Grotesque, 격려 문구는 마루 부리 (pubspec.yaml fonts).
class AppFonts {
  static const body = 'LINESeedKR';

  /// 영문 A-Z a-z, 숫자, % / : + 만 들어 있는 글꼴. 맨 앞에 두면 영문·숫자만 이 글꼴로, 한글과 문장 부호는 [fallback]으로 그려진다.
  static const latin = 'BricolageLatin';
  static const fallback = [body];
  static const cheer = 'MaruBuri';
}

/// 격려 문구용: 같은 크기·색에 글꼴만 마루 부리로 바꾼다. 부리 글꼴이라 자간을 풀고 줄 간격을 조금 넓힌다.
extension CheerText on TextStyle {
  TextStyle get cheer => copyWith(fontFamily: AppFonts.cheer, letterSpacing: 0, height: (height ?? 1.3) + 0.1);
}

bool get isApple => defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

ThemeData buildTheme() {
  final ios = isApple;
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: AppFonts.latin,
    fontFamilyFallback: AppFonts.fallback,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.background,
    // iOS: 물결 없이 눌림만 살짝, 옆으로 밀며 넘기고 뒤로 쓸어 닫는다. 안드로이드: 머티리얼 기본(물결·시스템 뒤로 가기)
    splashFactory: ios ? NoSplash.splashFactory : null,
    highlightColor: ios ? AppColors.text.withValues(alpha: 0.06) : null,
    pageTransitionsTheme: ios
        ? PageTransitionsTheme(
            builders: {for (final p in TargetPlatform.values) p: const CupertinoPageTransitionsBuilder()},
          )
        : null,
    dividerTheme: DividerThemeData(color: AppColors.line, thickness: ios ? 0.5 : 1, space: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: ios ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)) : null,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (st) => ios && st.contains(WidgetState.selected) ? AppColors.sage : null,
      ),
    ),
  );
  // iOS 글자 단계: Title1 28 · Title2 22 · Headline/Body 17 · Subheadline 15 · Footnote 13
  // 머티리얼 3 글자 단계: 28 · 22 · 16 · 16 · 14 · 12
  final up = ios ? 1.0 : 0.0;
  final t = TextStyle(fontFamily: AppFonts.latin, fontFamilyFallback: AppFonts.fallback, color: AppColors.text, letterSpacing: ios ? -0.3 : -0.2);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: t.copyWith(fontFamily: AppFonts.cheer, fontSize: 30, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: 0),
      titleLarge: t.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: t.copyWith(fontSize: 16 + up, fontWeight: FontWeight.w600),
      bodyLarge: t.copyWith(fontSize: 16 + up, height: 1.45),
      bodyMedium: t.copyWith(fontSize: 14 + up, height: 1.45, letterSpacing: 0),
      bodySmall: t.copyWith(fontSize: 12 + up, color: AppColors.textMuted, letterSpacing: 0),
      labelLarge: t.copyWith(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: ios,
      titleTextStyle: ios
          ? const TextStyle(fontFamily: AppFonts.cheer, color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w600)
          : const TextStyle(fontFamily: AppFonts.cheer, color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.text, // 버튼은 먹색. 노을빛은 달성률 링에만 남긴다
        foregroundColor: AppColors.background,
        minimumSize: Size.fromHeight(ios ? 50 : 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        textStyle: TextStyle(fontFamily: AppFonts.latin, fontFamilyFallback: AppFonts.fallback, fontSize: 16 + up, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.primaryInk)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: const BorderSide(color: AppColors.text, width: 1.5),
      ),
    ),
    navigationBarTheme: ios
        ? NavigationBarThemeData(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            // iOS 탭바: 알약 표시 없이 색으로만 선택을 알린다
            indicatorColor: Colors.transparent,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            height: 56,
            iconTheme: WidgetStateProperty.resolveWith(
              (st) => IconThemeData(
                size: 26,
                color: st.contains(WidgetState.selected) ? AppColors.text : AppColors.textMuted,
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (st) => TextStyle(fontFamily: AppFonts.latin, fontFamilyFallback: AppFonts.fallback, 
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: st.contains(WidgetState.selected) ? AppColors.text : AppColors.textMuted,
              ),
            ),
          )
        // 머티리얼 3 내비게이션 바: 알약 표시, 높이 80(기본값)
        : NavigationBarThemeData(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: AppColors.selected,
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontFamily: AppFonts.latin, fontFamilyFallback: AppFonts.fallback, fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
          ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// 한글이 낱말 중간에서 줄바꿈되지 않게, 붙어 있는 글자 사이에 폭 없는 이음자(U+200D)를 넣는다.
String keepWords(String s) => s.replaceAll('\u200D', '').replaceAllMapped(RegExp(r'\S(?=\S)'), (m) => '${m[0]}\u200D');

/// 앱 화면에서 쓰는 Text. 줄이 넘어갈 때 낱말 중간이 아니라 띄어쓰기에서만 바뀐다
/// (플러터에는 CSS의 word-break: keep-all이 없다). 화면 파일은 머티리얼의 Text를 숨기고 이것을 쓴다.
class Text extends m.Text {
  const Text(super.data, {super.key, super.style, super.textAlign, super.maxLines, super.overflow, super.softWrap});

  @override
  Widget build(BuildContext context) => m.Text(
    keepWords(data!),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    semanticsLabel: data, // 화면 낭독기에는 이음자 없는 원래 글을 읽힌다
  );
}
