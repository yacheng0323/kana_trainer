import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/backup_service.dart';
import '../../core/storage/prefs_provider.dart';
import '../../core/theme/app_theme.dart';
import '../exam/exam_history_notifier.dart';
import '../grammar/grammar_progress_notifier.dart';
import '../progress/mastery_notifier.dart';
import '../progress/srs_notifier.dart';
import '../progress/stats_notifier.dart';
import '../progress/wrong_notifier.dart';
import 'settings_notifier.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isInput = settings.answerMode == AnswerMode.input;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              '作答方式',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.indigo.withValues(alpha: 0.7),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<AnswerMode>(
              segments: const [
                ButtonSegment(
                  value: AnswerMode.choice,
                  label: Text('4 選 1'),
                  icon: Icon(Icons.grid_view),
                ),
                ButtonSegment(
                  value: AnswerMode.input,
                  label: Text('鍵盤輸入'),
                  icon: Icon(Icons.keyboard),
                ),
              ],
              selected: {settings.answerMode},
              onSelectionChanged: (sel) =>
                  notifier.update((s) => s.copyWith(answerMode: sel.first)),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              '單字題型',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.indigo.withValues(alpha: 0.7),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<VocabMode>(
              segments: [
                for (final m in VocabMode.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {settings.vocabMode},
              onSelectionChanged: (sel) =>
                  notifier.update((s) => s.copyWith(vocabMode: sel.first)),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('每日目標題數'),
            subtitle: Text('目前：${settings.dailyGoal} 題／天'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: settings.dailyGoal > 10
                      ? () => notifier.update(
                          (s) => s.copyWith(dailyGoal: s.dailyGoal - 10))
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: settings.dailyGoal < 200
                      ? () => notifier.update(
                          (s) => s.copyWith(dailyGoal: s.dailyGoal + 10))
                      : null,
                ),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('答對自動下一題'),
            subtitle: const Text('答對後 0.9 秒自動出下一題'),
            value: settings.autoNext,
            onChanged: (v) => notifier.update((s) => s.copyWith(autoNext: v)),
          ),
          SwitchListTile(
            title: const Text('音效與震動'),
            value: settings.sound,
            onChanged: (v) => notifier.update((s) => s.copyWith(sound: v)),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '以下僅鍵盤輸入模式適用',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.indigo.withValues(alpha: 0.5),
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('區分大小寫'),
            subtitle: const Text('關閉時 Ka / KA / ka 都算正確（預設）'),
            value: settings.caseSensitive,
            onChanged: isInput
                ? (v) => notifier.update((s) => s.copyWith(caseSensitive: v))
                : null,
          ),
          SwitchListTile(
            title: const Text('顯示提示按鈕'),
            subtitle: const Text('練習時可點燈泡看第一個字母'),
            value: settings.showHint,
            onChanged: isInput
                ? (v) => notifier.update((s) => s.copyWith(showHint: v))
                : null,
          ),
          SwitchListTile(
            title: const Text('羅馬拼音提示'),
            subtitle: const Text('題目下方直接顯示答案（初學模式）'),
            value: settings.romajiHint,
            onChanged: isInput
                ? (v) => notifier.update((s) => s.copyWith(romajiHint: v))
                : null,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.upload, color: AppColors.indigo),
            title: const Text('匯出學習資料'),
            subtitle: const Text('複製備份 JSON 到剪貼簿'),
            onTap: () async {
              final json = BackupService.export(ref.read(prefsProvider));
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已複製到剪貼簿，貼到記事本保存即可')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.download, color: AppColors.indigo),
            title: const Text('匯入學習資料'),
            subtitle: const Text('貼上先前匯出的備份 JSON（覆蓋現有進度）'),
            onTap: () => _showImportDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('匯入學習資料'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '貼上備份 JSON…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('匯入'),
          ),
        ],
      ),
    );
    if (json == null || json.trim().isEmpty) return;

    try {
      final count =
          await BackupService.import(ref.read(prefsProvider), json.trim());
      // 重建所有讀 prefs 的 provider，讓匯入立即生效
      ref
        ..invalidate(settingsProvider)
        ..invalidate(masteryProvider)
        ..invalidate(wrongProvider)
        ..invalidate(vocabWrongProvider)
        ..invalidate(sentenceWrongProvider)
        ..invalidate(srsProvider)
        ..invalidate(statsProvider)
        ..invalidate(grammarProgressProvider)
        ..invalidate(examHistoryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匯入完成（$count 項資料）')),
        );
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匯入失敗：${e.message}')),
        );
      }
    }
  }
}
