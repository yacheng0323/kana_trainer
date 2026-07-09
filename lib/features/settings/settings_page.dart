import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_notifier.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('答對自動下一題'),
            subtitle: const Text('答對後 0.9 秒自動出下一題'),
            value: settings.autoNext,
            onChanged: (v) => notifier.update((s) => s.copyWith(autoNext: v)),
          ),
          SwitchListTile(
            title: const Text('區分大小寫'),
            subtitle: const Text('關閉時 Ka / KA / ka 都算正確（預設）'),
            value: settings.caseSensitive,
            onChanged: (v) =>
                notifier.update((s) => s.copyWith(caseSensitive: v)),
          ),
          SwitchListTile(
            title: const Text('顯示提示按鈕'),
            subtitle: const Text('練習時可點燈泡看第一個字母'),
            value: settings.showHint,
            onChanged: (v) => notifier.update((s) => s.copyWith(showHint: v)),
          ),
          SwitchListTile(
            title: const Text('音效與震動'),
            value: settings.sound,
            onChanged: (v) => notifier.update((s) => s.copyWith(sound: v)),
          ),
          SwitchListTile(
            title: const Text('羅馬拼音提示'),
            subtitle: const Text('題目下方直接顯示答案（初學模式）'),
            value: settings.romajiHint,
            onChanged: (v) => notifier.update((s) => s.copyWith(romajiHint: v)),
          ),
        ],
      ),
    );
  }
}
