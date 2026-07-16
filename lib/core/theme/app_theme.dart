import 'package:flutter/material.dart';

/// 2c「深藍夜 x 金黃」design tokens（v2.11.0 起支援深色模式）。
/// 方正 8px 圓角 + 無模糊硬陰影（貼紙感），非柔和圓潤風。
///
/// [AppColors.dark] 為全域開關（app root 依 settings/系統亮度設定後
/// 整棵樹重掛）。token 語意：
/// - cream          畫面底色
/// - surface        卡片/列表底（亮=白、暗=亮靛）
/// - indigo         主文字/邊框（深色下翻成淺薰衣草）
/// - indigoSurface  深靛「填色」（頂欄/號碼牌等，兩模式都保持深色）
/// - indigoFaded    次要文字
abstract class AppColors {
  /// 深色模式開關。只在 app root 設定（KanaTrainerApp），widget 不要碰。
  static bool dark = false;

  static Color get cream =>
      dark ? Color(0xFF14162B) : Color(0xFFF4E9DA);

  static Color get surface => dark ? Color(0xFF262A52) : Colors.white;

  static Color get indigo =>
      dark ? Color(0xFFD9D4EE) : Color(0xFF22254A);

  /// 深靛填色（亮色下 = indigo；深色下維持深靛，避免翻淺的文字色被拿去當底）
  static Color get indigoSurface =>
      dark ? Color(0xFF2E3266) : Color(0xFF22254A);

  static Color get gold =>
      dark ? Color(0xFFF0BD5E) : Color(0xFFE8B04B);

  static Color get green =>
      dark ? Color(0xFF3FBF98) : Color(0xFF2E9E7C);

  static Color get red =>
      dark ? Color(0xFFE57676) : Color(0xFFD65B5B);

  static Color get indigoFaded =>
      dark ? Color(0x99D9D4EE) : Color(0x8022254A);
}

abstract class AppShadows {
  static Color get _shadow =>
      AppColors.dark ? Color(0xB3000000) : Color(0xE622254A);

  /// 硬陰影 6px 6px 0（假名卡片、反饋橫幅）
  static List<BoxShadow> get hard =>
      [BoxShadow(color: _shadow, offset: Offset(6, 6))];

  /// 較輕的硬陰影 4px 4px 0（小卡片、按鈕）
  static List<BoxShadow> get hardSmall =>
      [BoxShadow(color: _shadow, offset: Offset(4, 4))];
}

abstract class AppTheme {
  static const fontFamily = 'ZenKakuGothicNew';
  static const radius = 8.0;

  /// 依 [AppColors.dark] 產生當前主題（palette getter 已跟著翻）。
  static ThemeData get current {
    final scheme = ColorScheme.fromSeed(
      seedColor: Color(0xFF22254A),
      brightness: AppColors.dark ? Brightness.dark : Brightness.light,
      primary: AppColors.dark ? AppColors.gold : AppColors.indigo,
      secondary: AppColors.gold,
      surface: AppColors.surface,
      error: AppColors.red,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.cream,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.indigoSurface,
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
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: AppColors.indigo, width: 2),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.indigoSurface,
          foregroundColor: AppColors.gold,
          textStyle: TextStyle(
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
          side: BorderSide(color: AppColors.indigo, width: 3),
          textStyle: TextStyle(
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
          (s) => s.contains(WidgetState.selected)
              ? AppColors.indigoSurface
              : null,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.indigoSurface,
        indicatorColor: AppColors.gold,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: states.contains(WidgetState.selected)
                ? AppColors.gold
                : Colors.white70,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? Color(0xFF22254A)
                : Colors.white70,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.indigoSurface,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// 舊名相容（tests / 既有呼叫走亮色預設）。
  static ThemeData get light => current;
}
