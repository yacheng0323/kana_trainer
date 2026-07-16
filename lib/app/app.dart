import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'main_shell.dart';

/// 主題三態解析：'dark'/'light' 強制，其餘（'system'）跟系統亮度。
bool resolveDark(String themeMode, Brightness platform) =>
    switch (themeMode) {
      'dark' => true,
      'light' => false,
      _ => platform == Brightness.dark,
    };

/// App root：解析主題（settings.themeMode + 系統亮度）→ 設定 AppColors.dark
/// → 以 ValueKey 重掛整棵樹（色票是靜態 getter，重掛才能全面換色；
/// 行為等同 Android 系統切深色時重建 activity）。
class KanaTrainerApp extends ConsumerStatefulWidget {
  const KanaTrainerApp({super.key});

  @override
  ConsumerState<KanaTrainerApp> createState() => _KanaTrainerAppState();
}

class _KanaTrainerAppState extends ConsumerState<KanaTrainerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {}); // 跟隨系統時，系統切換亮暗要重解析
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final dark = resolveDark(
      mode,
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    AppColors.dark = dark;

    return MaterialApp(
      key: ValueKey(dark), // 切換時整棵重掛（回到首頁），色票全面生效
      title: '50音練習',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      home: const MainShell(),
    );
  }
}
