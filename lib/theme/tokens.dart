import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

/// 하루살이 디자인 토큰. 위젯에서 색·간격을 직접 쓰지 말고 여기서 가져온다.
class AppColors {
  static const background = Color(0xFFFBF6EF); // 따뜻한 크림
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF3EBE0);
  static const line = Color(0xFFE8DDCF);

  static const text = Color(0xFF3B3129);
  static const textMuted = Color(0xFF8C7F72);

  static const primary = Color(0xFFE08A5B); // 노을빛 테라코타
  static const primarySoft = Color(0xFFF8DCCB);
  static const sage = Color(0xFF8FAE8B); // 완료·성장
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
bool get isApple => defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

ThemeData buildTheme() {
  final ios = isApple;
  final base = ThemeData(
    useMaterial3: true,
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
  final t = TextStyle(color: AppColors.text, letterSpacing: ios ? -0.3 : -0.2);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: t.copyWith(fontSize: 28, fontWeight: FontWeight.w700, height: 1.25),
      titleLarge: t.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
      titleMedium: t.copyWith(fontSize: 16 + up, fontWeight: FontWeight.w600),
      bodyLarge: t.copyWith(fontSize: 16 + up, height: 1.45),
      bodyMedium: t.copyWith(fontSize: 14 + up, height: 1.45),
      bodySmall: t.copyWith(fontSize: 12 + up, color: AppColors.textMuted),
      labelLarge: t.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: ios,
      titleTextStyle: ios
          ? const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4)
          : const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: Size.fromHeight(ios ? 50 : 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        textStyle: TextStyle(fontSize: 16 + up, fontWeight: ios ? FontWeight.w600 : FontWeight.w700),
      ),
    ),
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
                color: st.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (st) => TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: st.contains(WidgetState.selected) ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          )
        // 머티리얼 3 내비게이션 바: 알약 표시, 높이 80(기본값)
        : NavigationBarThemeData(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: AppColors.primarySoft,
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
          ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
