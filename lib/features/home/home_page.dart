import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/kana_data.dart';
import '../../core/models/practice_mode.dart';
import '../practice/practice_page.dart';
import '../progress/mastery_notifier.dart';
import '../progress/stats_notifier.dart';
import '../progress/wrong_list_page.dart';
import '../progress/wrong_notifier.dart';
import '../settings/settings_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wrongCount = ref.watch(wrongProvider).length;
    final stats = ref.watch(statsProvider);
    ref.watch(masteryProvider);
    final progress = ref
        .read(masteryProvider.notifier)
        .progressOf(allKana.map((k) => k.kana));

    return Scaffold(
      appBar: AppBar(
        title: const Text('50音練習'),
        actions: [
          IconButton(
            tooltip: '錯題本',
            icon: Badge(
              isLabelVisible: wrongCount > 0,
              label: Text('$wrongCount'),
              child: const Icon(Icons.menu_book_outlined),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WrongListPage()),
            ),
          ),
          IconButton(
            tooltip: '設定',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatsCard(stats: stats, progress: progress),
          const SizedBox(height: 20),
          Text('選擇練習模式', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              for (final mode in PracticeMode.values)
                _ModeCard(
                  mode: mode,
                  enabled: mode != PracticeMode.wrongReview || wrongCount > 0,
                  badge: mode == PracticeMode.wrongReview && wrongCount > 0
                      ? '$wrongCount'
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 今日答題數、正確率、總體熟練進度。
class _StatsCard extends StatelessWidget {
  final Stats stats;
  final double progress;

  const _StatsCard({required this.stats, required this.progress});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('學習進度', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              '熟練度 ${(progress * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: '今日答題', value: '${stats.todayTotal}'),
                _StatItem(
                  label: '今日正確率',
                  value: stats.todayTotal == 0
                      ? '—'
                      : '${(stats.todayAccuracy * 100).toStringAsFixed(0)}%',
                ),
                _StatItem(label: '總答題', value: '${stats.total}'),
                _StatItem(
                  label: '最佳連對',
                  value: '${stats.bestStreak}',
                  color: scheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final PracticeMode mode;
  final bool enabled;
  final String? badge;

  const _ModeCard({required this.mode, this.enabled = true, this.badge});

  static const _icons = {
    PracticeMode.hiragana: Icons.translate,
    PracticeMode.katakana: Icons.text_fields,
    PracticeMode.dakuon: Icons.blur_on,
    PracticeMode.youon: Icons.join_full,
    PracticeMode.mixed: Icons.shuffle,
    PracticeMode.wrongReview: Icons.replay,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PracticePage(mode: mode),
                  ),
                )
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_icons[mode], color: scheme.primary),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Badge(label: Text(badge!)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(mode.label, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
