import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/ai/ai_quiz_service.dart';
import 'package:kana_trainer/data/services/notification_service.dart';
import 'package:kana_trainer/data/storage/backup_service.dart';
import 'package:kana_trainer/data/storage/prefs_provider.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/domain/logic/expansion_policy.dart';
import 'package:kana_trainer/features/exam/exam_history_notifier.dart';
import 'package:kana_trainer/features/expansion/expansion_notifier.dart';
import 'package:kana_trainer/features/grammar/grammar_progress_notifier.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/srs_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
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
      appBar: AppBar(title: Text('設定')),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
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
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<AnswerMode>(
              segments: [
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
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
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
            padding: EdgeInsets.symmetric(horizontal: 16),
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
          SizedBox(height: 12),
          ListTile(
            title: Text('每日目標題數'),
            subtitle: Text('目前：${settings.dailyGoal} 題／天'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove_circle_outline),
                  onPressed: settings.dailyGoal > 10
                      ? () => notifier.update(
                          (s) => s.copyWith(dailyGoal: s.dailyGoal - 10))
                      : null,
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline),
                  onPressed: settings.dailyGoal < 200
                      ? () => notifier.update(
                          (s) => s.copyWith(dailyGoal: s.dailyGoal + 10))
                      : null,
                ),
              ],
            ),
          ),
          Divider(),
          SwitchListTile(
            title: Text('答對自動下一題'),
            subtitle: Text('答對後 0.9 秒自動出下一題'),
            value: settings.autoNext,
            onChanged: (v) => notifier.update((s) => s.copyWith(autoNext: v)),
          ),
          SwitchListTile(
            title: Text('音效與震動'),
            value: settings.sound,
            onChanged: (v) => notifier.update((s) => s.copyWith(sound: v)),
          ),
          SwitchListTile(
            title: Text('每日提醒'),
            subtitle: Text(
              settings.reminderEnabled
                  ? '每天 ${settings.reminderHour.toString().padLeft(2, '0')}:'
                      '${settings.reminderMinute.toString().padLeft(2, '0')} 提醒學習'
                  : '固定時間推播提醒，別讓連續達標斷掉',
            ),
            value: settings.reminderEnabled,
            onChanged: (v) => _toggleReminder(context, ref, v),
          ),
          if (settings.reminderEnabled)
            ListTile(
              leading: Icon(Icons.schedule, color: AppColors.indigo),
              title: Text('提醒時間'),
              trailing: Text(
                '${settings.reminderHour.toString().padLeft(2, '0')}:'
                '${settings.reminderMinute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.indigo,
                ),
              ),
              onTap: () => _pickReminderTime(context, ref),
            ),
          Divider(),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
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
            title: Text('區分大小寫'),
            subtitle: Text('關閉時 Ka / KA / ka 都算正確（預設）'),
            value: settings.caseSensitive,
            onChanged: isInput
                ? (v) => notifier.update((s) => s.copyWith(caseSensitive: v))
                : null,
          ),
          SwitchListTile(
            title: Text('顯示提示按鈕'),
            subtitle: Text('練習時可點燈泡看第一個字母'),
            value: settings.showHint,
            onChanged: isInput
                ? (v) => notifier.update((s) => s.copyWith(showHint: v))
                : null,
          ),
          SwitchListTile(
            title: Text('羅馬拼音提示'),
            subtitle: Text('題目下方直接顯示答案（初學模式）'),
            value: settings.romajiHint,
            onChanged: isInput
                ? (v) => notifier.update((s) => s.copyWith(romajiHint: v))
                : null,
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.key, color: AppColors.indigo),
            title: Text('Claude API Key（AI 出題用）'),
            subtitle: Text(
              ref.watch(apiKeyProvider).isEmpty
                  ? '未設定 — AI 出題功能需要'
                  : '已設定（僅存本機，不會被備份匯出）',
            ),
            onTap: () => _showApiKeyDialog(context, ref),
          ),
          SwitchListTile(
            title: Text('AI 自動擴充題庫'),
            subtitle: Text(
              '單字/句子/文法題快輪完時自動生成新題'
              '（今日已生成 ${ref.watch(expansionProvider).todayCount}/'
              '${ExpansionPolicy.dailyLimit} 批）',
            ),
            value: settings.autoExpand,
            onChanged: (v) =>
                notifier.update((s) => s.copyWith(autoExpand: v)),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.upload, color: AppColors.indigo),
            title: Text('匯出學習資料'),
            subtitle: Text('複製備份 JSON 到剪貼簿'),
            onTap: () async {
              final json = BackupService.export(ref.read(prefsProvider));
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已複製到剪貼簿，貼到記事本保存即可')),
                );
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.download, color: AppColors.indigo),
            title: Text('匯入學習資料'),
            subtitle: Text('貼上先前匯出的備份 JSON（覆蓋現有進度）'),
            onTap: () => _showImportDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleReminder(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final notifier = ref.read(settingsProvider.notifier);
    final service = ref.read(notificationServiceProvider);
    if (!enable) {
      notifier.update((s) => s.copyWith(reminderEnabled: false));
      await service.cancel();
      return;
    }
    final granted = await service.requestPermission();
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未取得通知權限，請到系統設定開啟')),
        );
      }
      return;
    }
    notifier.update((s) => s.copyWith(reminderEnabled: true));
    final s = ref.read(settingsProvider);
    await service.scheduleDaily(hour: s.reminderHour, minute: s.reminderMinute);
  }

  Future<void> _pickReminderTime(BuildContext context, WidgetRef ref) async {
    final s = ref.read(settingsProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute),
    );
    if (picked == null) return;
    ref.read(settingsProvider.notifier).update(
          (x) => x.copyWith(
            reminderHour: picked.hour,
            reminderMinute: picked.minute,
          ),
        );
    await ref
        .read(notificationServiceProvider)
        .scheduleDaily(hour: picked.hour, minute: picked.minute);
  }

  Future<void> _showApiKeyDialog(BuildContext context, WidgetRef ref) async {
    final controller =
        TextEditingController(text: ref.read(apiKeyProvider));
    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Claude API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '到 platform.claude.com 建立 API Key 後貼上。\n'
              '僅儲存在本機，清空後儲存即可移除。',
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'sk-ant-…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text('儲存'),
          ),
        ],
      ),
    );
    if (key == null) return;
    ref.read(apiKeyProvider.notifier).set(key);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(key.trim().isEmpty ? '已移除 API Key' : '已儲存 API Key')),
      );
    }
  }

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('匯入學習資料'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: '貼上備份 JSON…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text('匯入'),
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
