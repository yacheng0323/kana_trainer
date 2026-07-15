import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/core/theme/app_theme.dart';
import 'exam_history_notifier.dart';
import 'package:kana_trainer/domain/models/exam_models.dart';

/// 成績歷史：最近成績長條趨勢 + 紀錄列表。
class ExamHistoryPage extends ConsumerWidget {
  const ExamHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(examHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('成績歷史')),
      body: records.isEmpty
          ? const Center(child: Text('還沒有測驗紀錄，先來一場模擬測驗吧！'))
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _TrendChart(records: records.take(10).toList().reversed.toList()),
                const SizedBox(height: 20),
                for (final r in records) _RecordTile(record: r),
              ],
            ),
    );
  }
}

/// 最近 10 次成績長條圖（無外部套件，純 Container）。
class _TrendChart extends StatelessWidget {
  final List<ExamRecord> records; // 舊 → 新

  const _TrendChart({required this.records});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.indigo, width: 3),
        boxShadow: AppShadows.hardSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '最近成績趨勢',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.indigo,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final r in records)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${(r.percent * 100).round()}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.indigoFaded,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            height: 90 * r.percent + 4,
                            decoration: BoxDecoration(
                              color: r.percent >= 0.7
                                  ? AppColors.green
                                  : AppColors.gold,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3)),
                            ),
                          ),
                        ],
                      ),
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

class _RecordTile extends StatelessWidget {
  final ExamRecord record;

  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(record.dateIso);
    final dateText = date == null
        ? record.dateIso
        : '${date.year}/${date.month}/${date.day} '
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final percent = (record.percent * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: BorderSide(
            color: percent >= 70 ? AppColors.green : AppColors.indigo,
            width: 2,
          ),
        ),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: percent >= 70 ? AppColors.green : AppColors.gold,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$percent',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: percent >= 70 ? Colors.white : AppColors.indigo,
            ),
          ),
        ),
        title: Text(
          'N${record.level}・${record.score}/${record.total} 分',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.indigo,
          ),
        ),
        subtitle: Text(
            '$dateText・用時 ${record.durationSec ~/ 60} 分 ${record.durationSec % 60} 秒'),
      ),
    );
  }
}
