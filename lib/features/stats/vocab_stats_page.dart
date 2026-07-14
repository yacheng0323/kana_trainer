import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/vocab_history_notifier.dart';
import 'package:kana_trainer/features/stats/widgets/growth_chart.dart';

/// 詞彙量成長儀表板：大數字、30 天成長曲線、本週新學、主題進度。
class VocabStatsPage extends ConsumerStatefulWidget {
  const VocabStatsPage({super.key});

  @override
  ConsumerState<VocabStatsPage> createState() => _VocabStatsPageState();
}

class _VocabStatsPageState extends ConsumerState<VocabStatsPage> {
  @override
  void initState() {
    super.initState();
    // 開頁即記今日快照（曲線至少有今天這點）
    Future.microtask(() => ref.read(vocabHistoryProvider.notifier).snapshot());
  }

  @override
  Widget build(BuildContext context) {
    final vocab = ref.watch(contentRepositoryProvider).vocab();
    final mastery = ref.watch(masteryProvider);
    final history = ref.watch(vocabHistoryProvider);

    int levelOf(String key) => (mastery[key] ?? 0).clamp(0, 5);
    final learned = vocab.where((w) => levelOf(w.key) >= 4).length;
    final learning = vocab
        .where((w) => levelOf(w.key) >= 1 && levelOf(w.key) <= 3)
        .length;
    final unseen = vocab.length - learned - learning;
    final weekly = ref.read(vocabHistoryProvider.notifier).weeklyGained();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('詞彙量')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              _Stat(value: vocab.length, label: '池內總數', color: AppColors.gold),
              const SizedBox(width: 8),
              _Stat(value: learned, label: '已學會', color: AppColors.green),
              const SizedBox(width: 8),
              _Stat(value: learning, label: '學習中', color: AppColors.indigo),
              const SizedBox(width: 8),
              _Stat(value: unseen, label: '未見過', color: AppColors.red),
            ],
          ),
          const SizedBox(height: 14),
          _Card(
            title: '成長曲線（30 天）',
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LegendDot(color: AppColors.gold, label: '池內'),
                SizedBox(width: 8),
                _LegendDot(color: AppColors.green, label: '已學會'),
              ],
            ),
            child: GrowthChart(history: history),
          ),
          const SizedBox(height: 14),
          _Card(
            title: '本週新學',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '+$weekly 字',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: AppColors.green,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            title: '主題進度（已學會 / 池內）',
            child: Column(
              children: [
                for (final topic in VocabTopic.values)
                  _TopicRow(
                    topic: topic,
                    learned: vocab
                        .where((w) =>
                            w.topic == topic && levelOf(w.key) >= 4)
                        .length,
                    total: vocab.where((w) => w.topic == topic).length,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.indigo, width: 2),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
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
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _Card({required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.indigo, width: 3),
        boxShadow: AppShadows.hardSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.indigo,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.indigoFaded,
          ),
        ),
      ],
    );
  }
}

class _TopicRow extends StatelessWidget {
  final VocabTopic topic;
  final int learned;
  final int total;

  const _TopicRow(
      {required this.topic, required this.learned, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : learned / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              topic.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.indigo,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: const Color(0x1422254A),
                valueColor: const AlwaysStoppedAnimation(AppColors.green),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$learned/$total',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.indigoFaded,
            ),
          ),
        ],
      ),
    );
  }
}
