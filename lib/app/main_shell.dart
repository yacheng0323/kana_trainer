import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/services/notification_service.dart';
import 'package:kana_trainer/features/home/tabs/exam_tab.dart';
import 'package:kana_trainer/features/home/tabs/kana_tab.dart';
import 'package:kana_trainer/features/home/tabs/profile_tab.dart';
import 'package:kana_trainer/features/home/tabs/today_tab.dart';
import 'package:kana_trainer/features/home/tabs/topics_tab.dart';
import 'package:kana_trainer/features/progress/vocab_history_notifier.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';

/// Bottom navigation 殼：今日 / 50音基礎 / 主題學習 / 檢定 / 我的。
/// IndexedStack 保留各 tab 捲動與狀態。
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // App 啟動時重排每日提醒（idempotent，排程可能被系統清掉）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(settingsProvider);
      if (s.reminderEnabled) {
        ref
            .read(notificationServiceProvider)
            .scheduleDaily(hour: s.reminderHour, minute: s.reminderMinute);
      }
      // 詞彙量每日快照（成長曲線資料點，同日覆寫）
      ref.read(vocabHistoryProvider.notifier).snapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          TodayTab(),
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
            icon: Icon(Icons.today),
            label: '今日',
          ),
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
