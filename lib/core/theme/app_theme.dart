import 'package:flutter/material.dart';

/// 2c「深藍夜 x 金黃」design tokens。
/// 方正 8px 圓角 + 無模糊硬陰影（貼紙感），非柔和圓潤風。
abstract class AppColors {
  static const cream = Color(0xFFF4E9DA); // 畫面底色（暖米白）
  static const indigo = Color(0xFF22254A); // 深靛藍：標題底、邊框、主文字
  static const gold = Color(0xFFE8B04B); // 金黃：強調（進度、連對、火焰）
  static const green = Color(0xFF2E9E7C); // 答對
  static const red = Color(0xFFD65B5B); // 答錯
  static const indigoFaded = Color(0x8022254A); // rgba(34,37,74,.5) 次要文字
}

abstract class AppShadows {
  /// 硬陰影 6px 6px 0（假名卡片、反饋橫幅）
  static const hard = [
    BoxShadow(color: Color(0xE622254A), offset: Offset(6, 6)),
  ];

  /// 較輕的硬陰影 4px 4px 0（小卡片、按鈕）
  static const hardSmall = [
    BoxShadow(color: Color(0xE622254A), offset: Offset(4, 4)),
  ];
}

abstract class AppTheme {
  static const fontFamily = 'ZenKakuGothicNew';
  static const radius = 8.0;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.indigo,
      primary: AppColors.indigo,
      secondary: AppColors.gold,
      surface: Colors.white,
      error: AppColors.red,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.indigo, width: 2),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.indigo,
          foregroundColor: AppColors.gold,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.indigo,
          side: const BorderSide(color: AppColors.indigo, width: 3),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.gold : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.indigo : null,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.indigo,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
