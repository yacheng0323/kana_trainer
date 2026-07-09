import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
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
        ],
      ),
    );
  }
}
