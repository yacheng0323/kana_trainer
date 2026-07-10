import 'package:flutter/material.dart';

import '../features/home/tabs/exam_tab.dart';
import '../features/home/tabs/kana_tab.dart';
import '../features/home/tabs/profile_tab.dart';
import '../features/home/tabs/topics_tab.dart';

/// Bottom navigation 殼：50音基礎 / 主題學習 / 檢定 / 我的。
/// IndexedStack 保留各 tab 捲動與狀態。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          KanaTab(),
          TopicsTab(),
          ExamTab(),
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.translate),
            label: '50音基礎',
          ),
          NavigationDestination(
            icon: Icon(Icons.style),
            label: '主題學習',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment),
            label: '檢定',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
