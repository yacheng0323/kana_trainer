import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/home/home_page.dart';

class KanaTrainerApp extends StatelessWidget {
  const KanaTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '50音練習',
      debugShowCheckedModeBanner: false,
      // 2c「深藍夜 x 金黃」為單一亮色設計，不做深色變體
      theme: AppTheme.light,
      home: const HomePage(),
    );
  }
}
