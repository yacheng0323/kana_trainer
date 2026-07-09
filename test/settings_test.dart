import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/core/storage/prefs_provider.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'package:kana_trainer/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('預設值：不區分大小寫、自動下一題開', () async {
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    final s = c.read(settingsProvider);
    expect(s.caseSensitive, isFalse);
    expect(s.autoNext, isTrue);
    expect(s.showHint, isTrue);
    expect(s.sound, isTrue);
    expect(s.romajiHint, isFalse);
  });

  test('update 持久化：重建後保留', () async {
    final prefs = await SharedPreferences.getInstance();
    final c1 = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    c1.read(settingsProvider.notifier).update(
          (s) => s.copyWith(caseSensitive: true, autoNext: false),
        );
    c1.dispose();

    final c2 = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c2.dispose);
    final s = c2.read(settingsProvider);
    expect(s.caseSensitive, isTrue);
    expect(s.autoNext, isFalse);
  });

  testWidgets('SettingsPage 切換開關即更新狀態', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );

    expect(container.read(settingsProvider).caseSensitive, isFalse);
    await tester.tap(find.text('區分大小寫'));
    await tester.pump();
    expect(container.read(settingsProvider).caseSensitive, isTrue);
  });
}
