import 'package:flutter/material.dart';

import 'package:kana_trainer/core/theme/app_theme.dart';

/// GitHub-style 學習熱力圖：最近 15 週，每格一天，顏色深淺 = 當日答題數。
class StudyHeatmap extends StatelessWidget {
  final Map<String, int> history; // 'yyyy-MM-dd' -> 答題數
  final DateTime today;

  const StudyHeatmap({super.key, required this.history, required this.today});

  static const _weeks = 15;

  static Color colorFor(int count) {
    if (count <= 0) return const Color(0x1422254A);
    if (count < 10) return const Color(0x66E8B04B); // 淡金
    if (count < 20) return AppColors.gold;
    if (count < 40) return AppColors.green;
    return AppColors.indigo;
  }

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // 欄 = 週（左舊右新），列 = 週一..週日
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final start = thisMonday.subtract(const Duration(days: 7 * (_weeks - 1)));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.indigo, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '學習足跡（最近 15 週）',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.indigo,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final cell = ((constraints.maxWidth - (_weeks - 1) * 3) / _weeks)
                  .clamp(6.0, 14.0);
              return Column(
                children: [
                  for (var row = 0; row < 7; row++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          for (var col = 0; col < _weeks; col++) ...[
                            _cell(
                              start.add(Duration(days: col * 7 + row)),
                              cell,
                            ),
                            if (col < _weeks - 1) const SizedBox(width: 3),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                '少 ',
                style: TextStyle(fontSize: 10, color: AppColors.indigoFaded),
              ),
              for (final c in [0, 5, 15, 30, 50]) ...[
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: colorFor(c),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
              const Text(
                ' 多',
                style: TextStyle(fontSize: 10, color: AppColors.indigoFaded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(DateTime day, double size) {
    final future = day.isAfter(today);
    final count = future ? -1 : (history[dateKey(day)] ?? 0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: future ? Colors.transparent : colorFor(count),
        borderRadius: BorderRadius.circular(2),
        border: dateKey(day) == dateKey(today)
            ? Border.all(color: AppColors.red, width: 1.5)
            : null,
      ),
    );
  }
}
