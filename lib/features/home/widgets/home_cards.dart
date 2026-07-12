import 'package:flutter/material.dart';

import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';

/// 每日目標進度 + 連續達標天數（今日 tab 與我的 tab 共用）。
class GoalCard extends StatelessWidget {
  final Stats stats;
  final int goal;

  const GoalCard({super.key, required this.stats, required this.goal});

  @override
  Widget build(BuildContext context) {
    final progress =
        goal == 0 ? 1.0 : (stats.todayTotal / goal).clamp(0.0, 1.0);
    final done = stats.todayTotal >= goal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: done ? AppColors.green : AppColors.indigo,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Text(done ? '🎉' : '🎯', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done
                      ? '今日目標達成！連續 ${stats.goalStreakDays} 天'
                      : '今日目標 ${stats.todayTotal}/$goal 題',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: done ? AppColors.green : AppColors.indigo,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0x1422254A),
                    color: done ? AppColors.green : AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 各 tab 頂部深靛藍 header（2c 設計）。
class TabHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const TabHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.indigo,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 20),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// 區塊標題。
class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: AppColors.indigo,
      ),
    );
  }
}

/// 通用入口卡：色塊 icon + 標籤 + 可選 badge。
class EntryCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String? badge;
  final bool enabled;
  final VoidCallback onTap;

  const EntryCard({
    super.key,
    required this.icon,
    required this.iconBg,
    this.iconColor = Colors.white,
    required this.label,
    this.badge,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppColors.indigo, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.indigo,
                    ),
                  ),
                ),
                if (badge != null)
                  Badge(
                    label: Text(badge!),
                    backgroundColor: AppColors.gold,
                    textColor: AppColors.indigo,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 入口卡 2 欄格。
class EntryGrid extends StatelessWidget {
  final List<Widget> children;

  const EntryGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.9,
      children: children,
    );
  }
}
