import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/progress/daily_history_notifier.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/srs_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'package:kana_trainer/features/today/daily_menu_builder.dart';
import 'package:kana_trainer/features/today/daily_menu_page.dart';
import 'package:kana_trainer/features/today/menu_done_notifier.dart';
import 'package:kana_trainer/features/today/widgets/heatmap.dart';
import 'package:kana_trainer/features/home/widgets/home_cards.dart';

/// Tab 1：今日 — 一鍵開始今日任務 + 每日目標 + 學習熱力圖。
class TodayTab extends ConsumerWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final dailyGoal = ref.watch(settingsProvider).dailyGoal;
    final history = ref.watch(dailyHistoryProvider);
    final menuDone = ref.watch(menuDoneProvider);
    final doneToday = ref.read(menuDoneProvider.notifier).doneToday;

    ref.watch(srsProvider);
    final preview = DailyMenuBuilder.preview(
      dueVocabKeys: ref
          .read(srsProvider.notifier)
          .dueKeys(ref.watch(masteryProvider).keys),
      kanaWrong: ref.watch(wrongProvider),
      vocabWrong: ref.watch(vocabWrongProvider),
      sentenceWrong: ref.watch(sentenceWrongProvider),
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        TabHeader(
          title: '今日',
          subtitle: '🔥 連續達標 ${stats.goalStreakDays} 天・今日 ${stats.todayTotal} 題',
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 今日任務 hero
              doneToday
                  ? _DoneCard(menuDone: menuDone)
                  : _MenuCard(preview: preview),
              const SizedBox(height: 12),
              GoalCard(stats: stats, goal: dailyGoal),
              const SizedBox(height: 12),
              StudyHeatmap(history: history, today: DateTime.now()),
            ],
          ),
        ),
      ],
    );
  }
}

/// 未完成：任務組成 + 開始按鈕。
class _MenuCard extends ConsumerWidget {
  final MenuPreview preview;

  const _MenuCard({required this.preview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.indigo,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppShadows.hard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '📋 今日任務',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '待複習 ${preview.due}・錯題 ${preview.wrong}・新內容 ${preview.fresh}'
            '，共 ${preview.total} 題',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.indigo,
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DailyMenuPage()),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '開始今日任務',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 已完成：打卡狀態（仍可再練一輪）。
class _DoneCard extends StatelessWidget {
  final MenuDone menuDone;

  const _DoneCard({required this.menuDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.green, width: 3),
        boxShadow: AppShadows.hardSmall,
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 6),
          Text(
            '今日任務完成！答對 ${menuDone.score}/${menuDone.total}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DailyMenuPage()),
            ),
            child: const Text('再練一輪'),
          ),
        ],
      ),
    );
  }
}
