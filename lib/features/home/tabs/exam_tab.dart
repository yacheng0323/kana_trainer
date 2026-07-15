import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/exam/exam_history_notifier.dart';
import 'package:kana_trainer/features/exam/exam_history_page.dart';
import 'package:kana_trainer/features/exam/exam_page.dart';
import 'package:kana_trainer/features/home/widgets/home_cards.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';

/// Tab 3：檢定 — 模擬測驗入口 + 最佳/最近成績摘要 + 歷史。
class ExamTab extends ConsumerWidget {
  const ExamTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(settingsProvider).jlptLevel;
    final records = ref.watch(examHistoryProvider);
    final best = records.isEmpty
        ? null
        : records.reduce((a, b) => a.percent >= b.percent ? a : b);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        TabHeader(
          title: '檢定',
          subtitle: best == null
              ? 'N$level 模擬測驗・20 題 10 分鐘'
              : '最佳成績 ${(best.percent * 100).round()}%・共 ${records.length} 次',
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 主 CTA：開始模擬測驗
              Material(
                color: AppColors.indigo,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ExamPage()),
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      boxShadow: AppShadows.hard,
                    ),
                    child: Row(
                      children: [
                        const Text('📝', style: TextStyle(fontSize: 36)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'N$level 模擬測驗',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                '單字 10＋假名 5＋文法 5・限時 10 分鐘',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.play_circle_fill,
                            color: AppColors.gold, size: 36),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const SectionTitle('成績'),
              const SizedBox(height: 10),
              EntryGrid(
                children: [
                  EntryCard(
                    icon: Icons.insights,
                    iconBg: AppColors.green,
                    label: '成績歷史',
                    badge: records.isEmpty ? null : '${records.length}',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ExamHistoryPage()),
                    ),
                  ),
                ],
              ),
              if (records.isNotEmpty) ...[
                const SizedBox(height: 16),
                const SectionTitle('最近三次'),
                const SizedBox(height: 10),
                for (final r in records.take(3))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: AppColors.indigo, width: 2),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${(r.percent * 100).round()}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: r.percent >= 0.7
                                ? AppColors.green
                                : AppColors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'N${r.level}・${r.score}/${r.total} 分・${_dateText(r.dateIso)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.indigoFaded,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _dateText(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.month}/${d.day} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
