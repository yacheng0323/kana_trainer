import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/static/grammar_data.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'grammar_lesson_page.dart';
import 'grammar_progress_notifier.dart';

/// 文法課列表：線性解鎖，完成打勾。
class GrammarListPage extends ConsumerWidget {
  const GrammarListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(grammarProgressProvider);
    final progress = ref.read(grammarProgressProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: Text('N5 文法（${done.length}/${allGrammar.length}）')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: allGrammar.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final g = allGrammar[i];
          final unlocked = progress.isUnlocked(i);
          final isDone = done.contains(g.id);
          return Opacity(
            opacity: unlocked ? 1 : 0.4,
            child: ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                side: BorderSide(
                  color: isDone ? AppColors.green : AppColors.indigo,
                  width: 2,
                ),
              ),
              leading: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.green
                      : unlocked
                          ? AppColors.indigo
                          : AppColors.indigoFaded,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              title: Text(
                g.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.indigo,
                ),
              ),
              subtitle: Text(isDone ? '已完成 ✓ 可重新複習' : unlocked ? '可開始' : '完成上一課解鎖'),
              trailing: unlocked
                  ? const Icon(Icons.arrow_forward_ios,
                      size: 14, color: AppColors.indigo)
                  : const Icon(Icons.lock_outline,
                      size: 18, color: AppColors.indigoFaded),
              onTap: unlocked
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GrammarLessonPage(point: g),
                        ),
                      )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
