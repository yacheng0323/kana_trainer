import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/data/static/grammar_data.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';

/// 我的題庫：瀏覽全部單字/句子/文法題（靜態+AI 動態）。
/// 動態項可刪除（進黑名單，AI 不會重生成同題）；靜態項唯讀。
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  String _query = '';

  Future<void> _delete(String key, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('刪除「$label」？'),
        content: const Text('會從題庫移除並加入黑名單，AI 不會再生成同一題。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(dynamicContentStoreProvider).remove(key);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(contentRepositoryProvider);
    final store = ref.read(dynamicContentStoreProvider);
    final dynVocabKeys = store.vocab().map((w) => w.key).toSet();
    final dynSentenceKeys = store.sentences().map((s) => s.key).toSet();
    final dynGrammarKeys = store.grammarQuiz().map((q) => q.key).toSet();

    final vocab = repo.vocab().where((w) {
      if (_query.isEmpty) return true;
      return w.jp.contains(_query) ||
          w.reading.contains(_query) ||
          w.zh.contains(_query);
    }).toList();
    final sentences = repo.sentences();
    final grammar = [
      for (final g in allGrammar)
        for (final q in repo.grammarQuiz(g.id)) (point: g, quiz: q),
    ];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: const Text('我的題庫'),
          bottom: TabBar(
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w800,
            ),
            tabs: [
              Tab(text: '單字（${vocab.length}）'),
              Tab(text: '句子（${sentences.length}）'),
              Tab(text: '文法題（${grammar.length}）'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '搜尋單字／讀音／中文',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                Expanded(
                  child: _ItemList(
                    itemCount: vocab.length,
                    builder: (i) {
                      final w = vocab[i];
                      return _entry(
                        leading: w.jp,
                        title: '${w.reading}・${w.zh}',
                        subtitle: w.topic.label,
                        isDynamic: dynVocabKeys.contains(w.key),
                        onDelete: () => _delete(w.key, w.jp),
                      );
                    },
                  ),
                ),
              ],
            ),
            _ItemList(
              itemCount: sentences.length,
              builder: (i) {
                final s = sentences[i];
                return _entry(
                  leading: s.scene.label,
                  title: s.jp,
                  subtitle: s.zh,
                  isDynamic: dynSentenceKeys.contains(s.key),
                  onDelete: () => _delete(s.key, s.jp),
                );
              },
            ),
            _ItemList(
              itemCount: grammar.length,
              builder: (i) {
                final e = grammar[i];
                final key = '${e.point.id}|${e.quiz.question}';
                return _entry(
                  leading: e.point.id,
                  title: e.quiz.question,
                  subtitle: e.point.title,
                  isDynamic: dynGrammarKeys.contains(key),
                  onDelete: () => _delete(key, e.quiz.question),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _entry({
    required String leading,
    required String title,
    required String? subtitle,
    required bool isDynamic,
    required VoidCallback onDelete,
  }) {
    return ListTile(
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: const BorderSide(color: AppColors.indigo, width: 2),
      ),
      leading: Text(
        leading,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: AppColors.indigo,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.indigo,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: isDynamic
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.indigo,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '刪除此題（加黑名單）',
                  icon: const Icon(Icons.delete_outline, color: AppColors.red),
                  onPressed: onDelete,
                ),
              ],
            )
          : null,
    );
  }
}

class _ItemList extends StatelessWidget {
  final int itemCount;
  final Widget Function(int) builder;

  const _ItemList({required this.itemCount, required this.builder});

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return const Center(child: Text('沒有符合的內容'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => builder(i),
    );
  }
}
