import 'package:flutter/material.dart';

import 'package:kana_trainer/core/theme/app_theme.dart';
import 'main_shell.dart';

class KanaTrainerApp extends StatelessWidget {
  const KanaTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '50音練習',
      debugShowCheckedModeBanner: false,
      // 2c「深藍夜 x 金黃」為單一亮色設計，不做深色變體
      theme: AppTheme.light,
      home: const MainShell(),
    );
  }
}
