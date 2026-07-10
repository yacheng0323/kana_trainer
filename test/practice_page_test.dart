import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/core/models/practice_mode.dart';
import 'package:kana_trainer/core/storage/prefs_provider.dart';
import 'package:kana_trainer/features/practice/practice_controller.dart';
import 'package:kana_trainer/features/practice/practice_page.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> pumpPractice(
  WidgetTester tester,
  PracticeMode mode, {
  AnswerMode answerMode = AnswerMode.choice,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(home: PracticePage(mode: mode)),
    ),
  );
  final ctx = tester.element(find.byType(PracticePage));
  final container = ProviderScope.containerOf(ctx);
  if (answerMode != AnswerMode.choice) {
    container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(answerMode: answerMode));
    await tester.pump();
  }
  return container;
}

void main() {
  group('選擇題模式（預設）', () {
    testWidgets('顯示 4 個選項，點正解 → 答對橫幅 + 連對', (tester) async {
      final container = await pumpPractice(tester, PracticeMode.hiragana);
      final state = container.read(practiceProvider(PracticeMode.hiragana));

      expect(state.options.length, 4);
      for (final opt in state.options) {
        expect(find.text(opt), findsOneWidget);
      }
      expect(find.byType(TextField), findsNothing); // 選擇題模式無輸入框

      final correctOption = find.text(state.options[state.correctIndex]);
      await tester.ensureVisible(correctOption);
      await tester.pump();
      await tester.tap(correctOption);
      await tester.pump();

      expect(find.text('答對了！'), findsOneWidget);
      expect(find.text('✓'), findsOneWidget);
      final after = container.read(practiceProvider(PracticeMode.hiragana));
      expect(after.streak, 1);
      expect(after.sessionCorrect, 1);

      // autoNext 預設開啟 → 900ms 後自動下一題
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('答對了！'), findsNothing);
    });

    testWidgets('點錯 → 紅橫幅 + 正解揭示 ✓ + 錯選 ✕', (tester) async {
      final container = await pumpPractice(tester, PracticeMode.katakana);
      final state = container.read(practiceProvider(PracticeMode.katakana));
      final wrongIndex = state.correctIndex == 0 ? 1 : 0;

      final wrongOption = find.text(state.options[wrongIndex]);
      await tester.ensureVisible(wrongOption);
      await tester.pump();
      await tester.tap(wrongOption);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // shake 結束

      expect(find.text('再試一次，你可以的！'), findsOneWidget);
      expect(find.textContaining('正確答案：${state.current.romaji}'),
          findsOneWidget);
      expect(find.text('✓'), findsOneWidget); // 正解揭示
      expect(find.text('✕'), findsOneWidget); // 錯選標記
      expect(find.text('下一題'), findsOneWidget);
      expect(find.text('再試一次'), findsNothing); // 選擇題已揭示正解，無再試

      final after = container.read(practiceProvider(PracticeMode.katakana));
      expect(after.streak, 0);

      // 下一題 → 回到待答
      await tester.tap(find.text('下一題'));
      await tester.pump();
      expect(find.text('再試一次，你可以的！'), findsNothing);
    });

    testWidgets('作答後選項鎖定，不能重複計分', (tester) async {
      final container = await pumpPractice(tester, PracticeMode.hiragana);
      final state = container.read(practiceProvider(PracticeMode.hiragana));
      final wrongIndex = state.correctIndex == 0 ? 1 : 0;

      final wrongOption = find.text(state.options[wrongIndex]);
      await tester.ensureVisible(wrongOption);
      await tester.pump();
      await tester.tap(wrongOption);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(state.options[state.correctIndex]),
          warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));

      final after = container.read(practiceProvider(PracticeMode.hiragana));
      expect(after.sessionTotal, 1); // 第二次點擊被忽略
    });
  });

  group('鍵盤輸入模式', () {
    testWidgets('輸入正解 → 答對；大小寫不區分', (tester) async {
      final container = await pumpPractice(
        tester,
        PracticeMode.hiragana,
        answerMode: AnswerMode.input,
      );
      final state = container.read(practiceProvider(PracticeMode.hiragana));

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(
          find.byType(TextField), state.current.romaji.toUpperCase());
      await tester.tap(find.text('確認'));
      await tester.pump();

      expect(find.text('答對了！'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1)); // flush autoNext timer
    });

    testWidgets('輸入錯誤 → 顯示正解 + 再試一次回到同一題', (tester) async {
      final container = await pumpPractice(
        tester,
        PracticeMode.katakana,
        answerMode: AnswerMode.input,
      );
      final state = container.read(practiceProvider(PracticeMode.katakana));

      await tester.enterText(find.byType(TextField), 'xxxxx');
      await tester.tap(find.text('確認'));
      await tester.pump();

      expect(find.text('再試一次，你可以的！'), findsOneWidget);
      expect(find.textContaining('正確答案：${state.current.romaji}'),
          findsOneWidget);
      expect(find.text('再試一次'), findsOneWidget);

      await tester.tap(find.text('再試一次'));
      await tester.pump();
      expect(find.text('確認'), findsOneWidget);
      final after = container.read(practiceProvider(PracticeMode.katakana));
      expect(after.current.kana, state.current.kana);
      expect(after.streak, 0);
    });
  });
}
