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

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );
  const t = TextStyle(color: AppColors.text, letterSpacing: -0.2);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: t.copyWith(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25),
      titleLarge: t.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: t.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: t.copyWith(fontSize: 16, height: 1.45),
      bodyMedium: t.copyWith(fontSize: 14, height: 1.45),
      bodySmall: t.copyWith(fontSize: 12, color: AppColors.textMuted),
      labelLarge: t.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      height: 68,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
