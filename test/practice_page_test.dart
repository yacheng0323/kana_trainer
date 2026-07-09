import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/core/models/practice_mode.dart';
import 'package:kana_trainer/core/storage/prefs_provider.dart';
import 'package:kana_trainer/features/practice/practice_controller.dart';
import 'package:kana_trainer/features/practice/practice_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> pumpPractice(
  WidgetTester tester,
  PracticeMode mode,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(home: PracticePage(mode: mode)),
    ),
  );
  final ctx = tester.element(find.byType(PracticePage));
  return ProviderScope.containerOf(ctx);
}

void main() {
  testWidgets('答對顯示「答對了」並累計連對', (tester) async {
    final container = await pumpPractice(tester, PracticeMode.hiragana);
    final state = container.read(practiceProvider(PracticeMode.hiragana));

    await tester.enterText(find.byType(TextField), state.current.romaji);
    await tester.tap(find.text('確認'));
    await tester.pump();

    expect(find.text('答對了！'), findsOneWidget);
    expect(find.textContaining('讀音：${state.current.romaji}'), findsOneWidget);

    // autoNext 預設開啟 → 900ms 後自動下一題
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('答對了！'), findsNothing);
    final next = container.read(practiceProvider(PracticeMode.hiragana));
    expect(next.streak, 1);
    expect(next.sessionCorrect, 1);
  });

  testWidgets('答錯顯示正確答案 + 再試一次/下一題', (tester) async {
    final container = await pumpPractice(tester, PracticeMode.katakana);
    final state = container.read(practiceProvider(PracticeMode.katakana));

    await tester.enterText(find.byType(TextField), 'xxxxx');
    await tester.tap(find.text('確認'));
    await tester.pump();

    expect(find.text('答錯了'), findsOneWidget);
    expect(
      find.textContaining('正確答案：${state.current.romaji}'),
      findsOneWidget,
    );
    expect(find.text('再試一次'), findsOneWidget);
    expect(find.text('下一題'), findsOneWidget);

    // 再試一次 → 回到作答狀態，同一題
    await tester.tap(find.text('再試一次'));
    await tester.pump();
    expect(find.text('確認'), findsOneWidget);
    final after = container.read(practiceProvider(PracticeMode.katakana));
    expect(after.current.kana, state.current.kana);
    expect(after.streak, 0);
  });

  testWidgets('大小寫不區分：大寫也算對', (tester) async {
    final container = await pumpPractice(tester, PracticeMode.hiragana);
    final state = container.read(practiceProvider(PracticeMode.hiragana));

    await tester.enterText(
      find.byType(TextField),
      state.current.romaji.toUpperCase(),
    );
    await tester.tap(find.text('確認'));
    await tester.pump();

    expect(find.text('答對了！'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1)); // flush autoNext timer
  });
}
