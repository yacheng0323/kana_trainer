import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/app/app.dart';
import 'package:kana_trainer/core/storage/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App smoke：首頁渲染統計、分類進度與六個模式', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const KanaTrainerApp(),
      ),
    );

    expect(find.text('おかえり！'), findsOneWidget);
    expect(find.text('正確率'), findsOneWidget);
    expect(find.text('已學會'), findsOneWidget);
    expect(find.text('今日答題'), findsOneWidget);
    expect(find.text('分類進度'), findsOneWidget);
    expect(find.text('選擇練習模式'), findsOneWidget);
    expect(find.text('平假名練習'), findsOneWidget);
    expect(find.text('片假名練習'), findsOneWidget);
    expect(find.text('濁音・半濁音練習'), findsOneWidget);
    expect(find.text('拗音練習'), findsOneWidget);
    expect(find.text('混合練習'), findsOneWidget);
    expect(find.text('錯題複習'), findsOneWidget);
  });
}
