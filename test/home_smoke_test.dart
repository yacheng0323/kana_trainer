import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/app/app.dart';
import 'package:kana_trainer/core/storage/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Bottom bar 四 tab 切換，各 tab 關鍵內容都在', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const KanaTrainerApp(),
      ),
    );

    // Bottom bar 四個目的地
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('50音基礎'), findsWidgets); // bar + header
    expect(find.text('主題學習'), findsOneWidget);
    expect(find.text('檢定'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    // Tab 1：50音基礎（預設）
    expect(find.text('分類進度'), findsOneWidget);
    expect(find.text('平假名練習'), findsOneWidget);
    expect(find.text('混合練習'), findsOneWidget);

    // Tab 2：主題學習
    await tester.tap(find.text('主題學習'));
    await tester.pumpAndSettle();
    expect(find.text('單字（N5・105 詞）'), findsOneWidget);
    expect(find.text('聽力測驗'), findsOneWidget);
    expect(find.text('情境句子（40 句）'), findsOneWidget);
    expect(find.text('N5 文法課程'), findsOneWidget);

    // Tab 3：檢定
    await tester.tap(find.text('檢定'));
    await tester.pumpAndSettle();
    expect(find.text('N5 模擬測驗'), findsOneWidget);
    expect(find.text('成績歷史'), findsOneWidget);

    // Tab 4：我的
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('おかえり！'), findsOneWidget);
    expect(find.text('正確率'), findsOneWidget);
    expect(find.text('錯題本'), findsOneWidget);
    expect(find.text('設定與備份'), findsOneWidget);
  });
}
