import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/practice_mode.dart';
import '../practice/practice_page.dart';
import '../progress/wrong_notifier.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wrongCount = ref.watch(wrongProvider).length;

    return Scaffold(
      appBar: AppBar(title: const Text('50音練習')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
