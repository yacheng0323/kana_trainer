import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/kana_data.dart';
import '../../core/models/practice_mode.dart';
import '../../core/theme/app_theme.dart';
import '../practice/practice_page.dart';
import 'wrong_notifier.dart';

class WrongListPage extends ConsumerWidget {
  const WrongListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wrong = ref.watch(wrongProvider);
    final entries = wrong.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // 錯最多在前

    return Scaffold(
      appBar: AppBar(
        title: const Text('錯題本'),
        actions: [
          if (wrong.isNotEmpty)
            IconButton(
              tooltip: '清除錯題',
              icon: const Icon(Icons.delete_outline),
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
                if (ok == true) ref.read(wrongProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: wrong.isEmpty
          ? const Center(child: Text('目前沒有錯題，太棒了！'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final entry = entries[i];
                final kana = findKana(entry.key);
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    side: const BorderSide(color: AppColors.indigo, width: 2),
                  ),
                  leading: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.indigo,
                    ),
                  ),
                  title: Text(
                    kana?.romaji ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.indigo,
                    ),
                  ),
                  subtitle: kana != null && kana.aliases.isNotEmpty
                      ? Text('也可以：${kana.aliases.join(' / ')}')
                      : null,
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
                            ref.read(wrongProvider.notifier).remove(entry.key),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: wrong.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.indigo,
              foregroundColor: AppColors.gold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              icon: const Icon(Icons.replay),
              label: const Text('重新練習錯題'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const PracticePage(mode: PracticeMode.wrongReview),
                ),
              ),
            ),
    );
  }
}
