import 'package:flutter/material.dart';

import '../features/home/home_page.dart';

class KanaTrainerApp extends StatelessWidget {
  const KanaTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5C6BC0); // indigo
    return MaterialApp(
      title: '50音練習',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}
