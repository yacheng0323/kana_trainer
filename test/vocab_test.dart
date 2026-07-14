import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/data/storage/prefs_provider.dart';
import 'package:kana_trainer/features/practice/widgets/quiz_widgets.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:kana_trainer/features/vocab/vocab_view_model.dart';
import 'package:kana_trainer/features/vocab/vocab_practice_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('vocab_data', () {
    test('105 詞、每主題 15 詞', () {
      expect(allVocab.length, 105);
      for (final topic in VocabTopic.values) {
        expect(
          allVocab.where((w) => w.topic == topic).length,
          15,
          reason: '主題 ${topic.label} 應有 15 詞',
        );
      }
    });

    test('jp 全庫唯一（key 可當熟練度/錯題 key）', () {
      final keys = allVocab.map((w) => w.key).toSet();
      expect(keys.length, allVocab.length);
    });

    test('欄位齊全、全為 N5', () {
      for (final w in allVocab) {
        expect(w.jp, isNotEmpty);
        expect(w.reading, isNotEmpty);
        expect(w.zh, isNotEmpty);
        expect(w.jlpt, 5);
      }
    });

    test('findVocab 以 key 查詢', () {
      expect(findVocab('v_駅')!.zh, '車站');
      expect(findVocab('v_不存在'), isNull);
    });
  });

  group('VocabPool.buildPool', () {
    test('主題池 15 詞、全部 105、錯題池只含錯題', () {
      expect(VocabPool.travel.buildPool(allVocab).length, 15);
      expect(VocabPool.all.buildPool(allVocab).length, 105);
      final wrong = VocabPool.wrongReview
          .buildPool(allVocab, wrongKeys: {'v_駅', 'v_水'});
      expect(wrong.map((w) => w.jp).toSet(), {'駅', '水'});
    });
  });

  group('VocabPracticePage', () {
    Future<ProviderContainer> pump(WidgetTester tester, VocabPool pool) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: MaterialApp(home: VocabPracticePage(pool: pool)),
        ),
      );
      return ProviderScope.containerOf(
        tester.element(find.byType(VocabPracticePage)),
      );
    }

    // jp 與 zh 可能同字（如「出口」），鎖定選項按鈕內的文字避免撞雙
    Finder option(String text) => find.descendant(
          of: find.byType(OptionButton),
          matching: find.text(text),
        );

    // 頁面比測試視窗長，選項可能在畫面外，先捲到再點
    Future<void> tapOption(WidgetTester tester, String text) async {
      final f = option(text);
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
      await tester.pump();
    }

    testWidgets('點正解 → 答對橫幅 + 連對', (tester) async {
      final container = await pump(tester, VocabPool.transport);
      final state = container.read(vocabPracticeProvider(VocabPool.transport));

      expect(state.options.length, 4);
      // 日→中答題前題目卡顯示假名（漢字會洩題）
      expect(find.text(state.current.reading), findsWidgets);

      await tapOption(tester, state.options[state.correctIndex]);

      expect(find.text('答對了！'), findsOneWidget);
      final after =
          container.read(vocabPracticeProvider(VocabPool.transport));
      expect(after.streak, 1);
      await tester.pump(const Duration(seconds: 1)); // flush autoNext
    });

    testWidgets('日→中：答題前藏漢字（選項外找不到 jp）、作答後揭曉', (tester) async {
      final container = await pump(tester, VocabPool.transport);
      final state = container.read(vocabPracticeProvider(VocabPool.transport));
      final word = state.current;

      if (word.jp != word.reading) {
        // 答題前：漢字不得出現在選項按鈕以外的地方（題目卡藏漢字）
        final jpOutsideOptions = find.text(word.jp).evaluate().where(
            (e) => e.findAncestorWidgetOfExactType<OptionButton>() == null);
        expect(jpOutsideOptions, isEmpty);
      }
      expect(find.text(word.reading), findsWidgets);

      await tapOption(tester, state.options[state.correctIndex]);

      // 作答後：漢字揭曉
      expect(find.text(word.jp), findsWidgets);
      await tester.pump(const Duration(seconds: 1)); // flush autoNext
    });

    testWidgets('點錯 → 進單字錯題本、假名錯題本不受影響', (tester) async {
      final container = await pump(tester, VocabPool.food);
      final state = container.read(vocabPracticeProvider(VocabPool.food));
      final wrongIndex = state.correctIndex == 0 ? 1 : 0;

      await tapOption(tester, state.options[wrongIndex]);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('再試一次，你可以的！'), findsOneWidget);
      expect(container.read(vocabWrongProvider)[state.current.key], 1);
      expect(container.read(wrongProvider), isEmpty); // 假名錯題本獨立
    });

    testWidgets('錯題複習答對 → 移出單字錯題本', (tester) async {
      // 先種一筆錯題
      final prefs = await SharedPreferences.getInstance();
      final seed = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      seed.read(vocabWrongProvider.notifier).add('v_駅');
      seed.dispose();

      final container = await pump(tester, VocabPool.wrongReview);
      final state =
          container.read(vocabPracticeProvider(VocabPool.wrongReview));
      expect(state.current.jp, '駅'); // 錯題池只有一筆

      await tapOption(tester, state.options[state.correctIndex]);

      expect(container.read(vocabWrongProvider), isEmpty);
      await tester.pump(const Duration(seconds: 1)); // flush autoNext
    });
  });
}
