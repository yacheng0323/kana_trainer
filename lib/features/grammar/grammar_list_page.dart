import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/static/grammar_data.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/expansion/expansion_notifier.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'grammar_lesson_page.dart';
import 'grammar_progress_notifier.dart';

/// 文法課列表（等級跟 settings.jlptLevel）：
/// N5 = 人審 12 課、線性解鎖；N4~N1 = AI 生成課（badge、自由選）+ 生成按鈕。
class GrammarListPage extends ConsumerStatefulWidget {
  const GrammarListPage({super.key});

  @override
  ConsumerState<GrammarListPage> createState() => _GrammarListPageState();
}

class _GrammarListPageState extends ConsumerState<GrammarListPage> {
  bool _generating = false;

  Future<void> _generateLesson(int level) async {
    setState(() => _generating = true);
    final id =
        await ref.read(expansionProvider.notifier).expandGrammarLesson(level);
    if (!mounted) return;
    setState(() => _generating = false);
    if (id == null) {
      final err = ref.read(expansionProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? '無法生成（請確認 API Key／今日批數上限）')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(settingsProvider).jlptLevel;
    final done = ref.watch(grammarProgressProvider);

    if (level == 5) {
      return _staticN5(done);
    }
    // 觸發 rebuild 用（生成完成後 store 內容變了）
    final lessons = ref
        .read(dynamicContentStoreProvider)
        .grammarLessons()
        .where((l) => l.level == level)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: Text('N$level 文法（${lessons.length} 課・AI 生成）')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          if (lessons.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text(
                'N 級文法課由 AI 生成（未人審，教學卡有 AI 標示）。\n'
                '點下方按鈕生成第一課！',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.indigoFaded,
                ),
              ),
            ),
          for (final l in lessons) ...[
            _LessonTile(
              title: l.title,
              isDone: done.contains(l.id),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GrammarLessonPage(point: l.toGrammarPoint()),
                ),
              ),
              onDelete: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('刪除「${l.title}」？'),
                    content: Text('會加入黑名單，AI 不會再生成同名課程。'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('取消')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('刪除')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(dynamicContentStoreProvider).remove(l.id);
                  if (mounted) setState(() {});
                }
              },
            ),
            SizedBox(height: 10),
          ],
          SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _generating ? null : () => _generateLesson(level),
            icon: _generating
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.gold),
                  )
                : Icon(Icons.auto_awesome, size: 18),
            label: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(_generating ? '生成中…（約 10-20 秒）' : 'AI 生成下一課'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _staticN5(Set<String> done) {
    final progress = ref.read(grammarProgressProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
          title: Text('N5 文法（${done.length}/${allGrammar.length}）')),
      body: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: allGrammar.length,
        separatorBuilder: (_, _) => SizedBox(height: 10),
        itemBuilder: (context, i) {
          final g = allGrammar[i];
          final unlocked = progress.isUnlocked(i);
          final isDone = done.contains(g.id);
          return Opacity(
            opacity: unlocked ? 1 : 0.4,
            child: ListTile(
              tileColor: AppColors.surface,
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
                          ? AppColors.indigoSurface
                          : AppColors.indigoFaded,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: isDone
                    ? Icon(Icons.check, color: Colors.white, size: 18)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              title: Text(
                g.title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.indigoSurface,
                ),
              ),
              subtitle:
                  Text(isDone ? '已完成 ✓ 可重新複習' : unlocked ? '可開始' : '完成上一課解鎖'),
              trailing: unlocked
                  ? Icon(Icons.arrow_forward_ios,
                      size: 14, color: AppColors.indigo)
                  : Icon(Icons.lock_outline,
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

class _LessonTile extends StatelessWidget {
  final String title;
  final bool isDone;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _LessonTile({
    required this.title,
    required this.isDone,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(
          color: isDone ? AppColors.green : AppColors.indigo,
          width: 2,
        ),
      ),
      leading: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'AI',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.indigoSurface,
          ),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.indigo,
        ),
      ),
      subtitle: Text(isDone ? '已完成 ✓' : '未人審，內容有誤可刪除重生成'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '刪除此課',
            icon: Icon(Icons.delete_outline, color: AppColors.red),
            onPressed: onDelete,
          ),
          Icon(Icons.arrow_forward_ios,
              size: 14, color: AppColors.indigo),
        ],
      ),
      onTap: onTap,
    );
  }
}
