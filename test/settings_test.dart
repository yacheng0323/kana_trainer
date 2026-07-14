import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/storage/prefs_provider.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'package:kana_trainer/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('預設值：選擇題模式、不區分大小寫、自動下一題開', () async {
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    final s = c.read(settingsProvider);
    expect(s.answerMode, AnswerMode.choice);
    expect(s.caseSensitive, isFalse);
    expect(s.autoNext, isTrue);
    expect(s.showHint, isTrue);
    expect(s.sound, isTrue);
    expect(s.romajiHint, isFalse);
  });

  test('update 持久化：重建後保留（含 answerMode）', () async {
    final prefs = await SharedPreferences.getInstance();
    final c1 = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    c1.read(settingsProvider.notifier).update(
          (s) => s.copyWith(
            answerMode: AnswerMode.input,
            caseSensitive: true,
            autoNext: false,
          ),
        );
    c1.dispose();

    final c2 = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c2.dispose);
    final s = c2.read(settingsProvider);
    expect(s.answerMode, AnswerMode.input);
    expect(s.caseSensitive, isTrue);
    expect(s.autoNext, isFalse);
  });

  testWidgets('SettingsPage：切輸入模式後才能開區分大小寫', (tester) async {
    // 設定頁很長，放大視窗讓所有開關都在畫面內
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );

    // 選擇題模式下輸入相關開關停用
    expect(container.read(settingsProvider).answerMode, AnswerMode.choice);
    await tester.ensureVisible(find.text('區分大小寫'));
    await tester.tap(find.text('區分大小寫'));
    await tester.pump();
    expect(container.read(settingsProvider).caseSensitive, isFalse);

    // 切到鍵盤輸入 → 開關可用
    await tester.ensureVisible(find.text('鍵盤輸入'));
    await tester.tap(find.text('鍵盤輸入'));
    await tester.pump();
    expect(container.read(settingsProvider).answerMode, AnswerMode.input);

    await tester.ensureVisible(find.text('區分大小寫'));
    await tester.tap(find.text('區分大小寫'));
    await tester.pump();
    expect(container.read(settingsProvider).caseSensitive, isTrue);
  });

  testWidgets('AI 自動擴充開關切換持久化', (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    expect(container.read(settingsProvider).autoExpand, isTrue);
    await tester.ensureVisible(find.text('AI 自動擴充題庫'));
    await tester.tap(find.text('AI 自動擴充題庫'));
    await tester.pump();
    expect(container.read(settingsProvider).autoExpand, isFalse);
  });
}
