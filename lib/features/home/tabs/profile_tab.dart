import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../progress/mastery_notifier.dart';
import '../../progress/stats_notifier.dart';
import '../../progress/wrong_list_page.dart';
import '../../progress/wrong_notifier.dart';
import '../../settings/settings_notifier.dart';
import '../../settings/settings_page.dart';
import '../widgets/home_cards.dart';

/// Tab 4：我的 — 學習統計、每日目標、錯題本、設定。
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final mastery = ref.watch(masteryProvider);
    final learned = mastery.values.where((v) => v >= 4).length;
    final dailyGoal = ref.watch(settingsProvider).dailyGoal;
    final wrongCount = ref.watch(wrongProvider).length +
        ref.watch(vocabWrongProvider).length +
        ref.watch(sentenceWrongProvider).length;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        TabHeader(
          title: 'おかえり！',
          subtitle: '🔥 最佳連對 ${stats.bestStreak}・連續達標 ${stats.goalStreakDays} 天',
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      value: stats.total == 0
                          ? '—'
                          : '${(stats.accuracy * 100).toStringAsFixed(0)}%',
                      label: '正確率',
                      color: AppColors.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      value: '$learned',
                      label: '已學會',
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      value: '${stats.todayTotal}',
                      label: '今日答題',
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GoalCard(stats: stats, goal: dailyGoal),
              const SizedBox(height: 22),
              const SectionTitle('學習管理'),
              const SizedBox(height: 10),
              EntryGrid(
                children: [
                  EntryCard(
                    icon: Icons.menu_book_outlined,
                    iconBg: AppColors.gold,
                    iconColor: AppColors.indigo,
                    label: '錯題本',
                    badge: wrongCount > 0 ? '$wrongCount' : null,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WrongListPage()),
                    ),
                  ),
                  EntryCard(
                    icon: Icons.settings_outlined,
                    iconBg: AppColors.indigo,
                    iconColor: AppColors.gold,
                    label: '設定與備份',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Center(
                child: Text(
                  'kana_trainer v2.4.0',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.indigoFaded,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.indigo, width: 3),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.indigoFaded,
            ),
          ),
        ],
      ),
    );
  }
}
