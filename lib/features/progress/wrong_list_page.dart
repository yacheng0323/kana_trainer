import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/data/static/kana_data.dart';
import 'package:kana_trainer/domain/entities/practice_mode.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/practice/practice_page.dart';
import 'package:kana_trainer/features/sentence/sentence_practice_page.dart';
import 'package:kana_trainer/features/vocab/vocab_practice_page.dart';
import 'wrong_notifier.dart';

/// 錯題本：假名 / 單字 / 句子 三 tab，各自可重練、單筆移除、全部清除。
class WrongListPage extends ConsumerWidget {
  const WrongListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kanaWrong = ref.watch(wrongProvider);
    final vocabWrong = ref.watch(vocabWrongProvider);
    final sentenceWrong = ref.watch(sentenceWrongProvider);
    final repo = ref.watch(contentRepositoryProvider); // 動態題錯題也查得到字面

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: const Text('錯題本'),
          bottom: TabBar(
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w800,
            ),
            tabs: [
              Tab(text: '假名（${kanaWrong.length}）'),
              Tab(text: '單字（${vocabWrong.length}）'),
              Tab(text: '句子（${sentenceWrong.length}）'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _WrongList(
              entries: kanaWrong,
              provider: wrongProvider,
              titleOf: (key) => findKana(key)?.romaji ?? '',
              subtitleOf: (key) {
                final k = findKana(key);
                return k != null && k.aliases.isNotEmpty
                    ? '也可以：${k.aliases.join(' / ')}'
                    : null;
              },
              leadingOf: (key) => key,
              onRetrain: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const PracticePage(mode: PracticeMode.wrongReview),
                ),
              ),
            ),
            _WrongList(
              entries: vocabWrong,
              provider: vocabWrongProvider,
              titleOf: (key) {
                final w = repo.findVocab(key);
                return w == null ? '' : '${w.reading}・${w.zh}';
              },
              subtitleOf: (key) => repo.findVocab(key)?.topic.label,
              leadingOf: (key) => repo.findVocab(key)?.jp ?? key,
              onRetrain: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const VocabPracticePage(pool: VocabPool.wrongReview),
                ),
              ),
            ),
            _WrongList(
              entries: sentenceWrong,
              provider: sentenceWrongProvider,
              titleOf: (key) => repo.findSentence(key)?.jp ?? key,
              subtitleOf: (key) => repo.findSentence(key)?.zh,
              leadingOf: (key) => repo.findSentence(key)?.scene.label ?? '句',
              onRetrain: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const SentencePracticePage(pool: ScenePool.wrongReview),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WrongList extends ConsumerWidget {
  final Map<String, int> entries;
  final NotifierProvider<WrongNotifier, Map<String, int>> provider;
  final String Function(String key) titleOf;
  final String? Function(String key) subtitleOf;
  final String Function(String key) leadingOf;
  final VoidCallback onRetrain;

  const _WrongList({
    required this.entries,
    required this.provider,
    required this.titleOf,
    required this.subtitleOf,
    required this.leadingOf,
    required this.onRetrain,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = entries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // 錯最多在前

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: entries.isEmpty
          ? const Center(child: Text('目前沒有錯題，太棒了！'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final entry = sorted[i];
                final subtitle = subtitleOf(entry.key);
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    side: const BorderSide(color: AppColors.indigo, width: 2),
                  ),
                  leading: Text(
                    leadingOf(entry.key),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.indigo,
                    ),
                  ),
                  title: Text(
                    titleOf(entry.key),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.indigo,
                    ),
                  ),
                  subtitle: subtitle != null ? Text(subtitle) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '錯 ${entry.value} 次',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.indigo,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '移除此錯題',
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            ref.read(provider.notifier).remove(entry.key),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: entries.isEmpty
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: null,
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  tooltip: '清除全部',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('清除所有錯題？'),
                        content: const Text('此動作無法復原。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('清除'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) ref.read(provider.notifier).clear();
                  },
                ),
                const SizedBox(width: 10),
                FloatingActionButton.extended(
                  heroTag: null,
                  backgroundColor: AppColors.indigo,
                  foregroundColor: AppColors.gold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  icon: const Icon(Icons.replay),
                  label: const Text('重新練習'),
                  onPressed: onRetrain,
                ),
              ],
            ),
    );
  }
}
