import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/core/data/sentence_data.dart';
import 'package:kana_trainer/core/models/sentence.dart';
import 'package:kana_trainer/core/storage/prefs_provider.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:kana_trainer/features/sentence/sentence_practice_controller.dart';
import 'package:kana_trainer/features/sentence/sentence_practice_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('sentence_data', () {
    test('40 句、每情境 8 句、jp 唯一', () {
      expect(allSentences.length, 40);
      for (final scene in Scene.values) {
        expect(allSentences.where((s) => s.scene == scene).length, 8,
            reason: '${scene.label} 應有 8 句');
      }
      expect(allSentences.map((s) => s.key).toSet().length, 40);
    });

    test('blankIndex 合法、clozeText 有挖空', () {
      for (final s in allSentences) {
        expect(s.blankIndex, inInclusiveRange(0, s.chunks.length - 1));
        expect(s.clozeText, contains('＿＿'));
        expect(s.chunks.length, greaterThanOrEqualTo(3)); // 重組至少 3 塊
      }
    });
  });

  group('SentencePracticeController', () {
    Future<(ProviderContainer, SentencePracticeController)> pump(
      WidgetTester tester,
      ScenePool pool,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: MaterialApp(home: SentencePracticePage(pool: pool)),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SentencePracticePage)),
      );
      return (container, container.read(sentencePracticeProvider(pool).notifier));
    }

    testWidgets('克漏字：選項含正解，答對計分', (tester) async {
      final (container, notifier) = await pump(tester, ScenePool.train);
      // 出到克漏字為止（題型隨機）
      var state = container.read(sentencePracticeProvider(ScenePool.train));
      var guard = 0;
      while (state.type != SentenceQuizType.cloze && guard < 20) {
        notifier.nextQuestion();
        await tester.pump();
        state = container.read(sentencePracticeProvider(ScenePool.train));
        guard++;
      }
      expect(state.type, SentenceQuizType.cloze);
      expect(state.options.length, 4);
      expect(state.options[state.correctIndex], state.current.blank);

      notifier.choose(state.correctIndex);
      await tester.pump();
      final after = container.read(sentencePracticeProvider(ScenePool.train));
      expect(after.feedback!.correct, isTrue);
      expect(after.streak, 1);
      await tester.pump(const Duration(seconds: 2)); // flush autoNext
    });

    testWidgets('重組：依正確順序點完 → 答對；亂序 → 答錯進錯題本', (tester) async {
      final (container, notifier) = await pump(tester, ScenePool.hotel);
      var state = container.read(sentencePracticeProvider(ScenePool.hotel));
      var guard = 0;
      while (state.type != SentenceQuizType.reorder && guard < 20) {
        notifier.nextQuestion();
        await tester.pump();
        state = container.read(sentencePracticeProvider(ScenePool.hotel));
        guard++;
      }
      expect(state.type, SentenceQuizType.reorder);

      // 依正確語塊順序找到 shuffled 索引點入
      for (final chunk in state.current.chunks) {
        final s = container.read(sentencePracticeProvider(ScenePool.hotel));
        final idx = List.generate(s.shuffled.length, (i) => i).firstWhere(
          (i) => s.shuffled[i] == chunk && !s.picked.contains(i),
        );
        notifier.pickChunk(idx);
      }
      await tester.pump();
      var after = container.read(sentencePracticeProvider(ScenePool.hotel));
      expect(after.feedback!.correct, isTrue);
      await tester.pump(const Duration(seconds: 2));

      // 下一題再出重組 → 故意亂點 → 答錯
      guard = 0;
      state = container.read(sentencePracticeProvider(ScenePool.hotel));
      while (state.type != SentenceQuizType.reorder && guard < 20) {
        notifier.nextQuestion();
        await tester.pump();
        state = container.read(sentencePracticeProvider(ScenePool.hotel));
        guard++;
      }
      // 逆序點（打亂後逆序必不等於正解：控制器保證 shuffled != 正解，
      // 但逆序可能剛好正確 — 用「非正解順序」：若逆序組出正解就先點 1 再 0）
      final n = state.shuffled.length;
      final reversed = List.generate(n, (i) => n - 1 - i);
      final joined = reversed.map((i) => state.shuffled[i]).join();
      final order = joined == state.current.jp
          ? [1, 0, ...List.generate(n - 2, (i) => i + 2)]
          : reversed;
      for (final i in order) {
        notifier.pickChunk(i);
      }
      await tester.pump();
      after = container.read(sentencePracticeProvider(ScenePool.hotel));
      expect(after.feedback!.correct, isFalse);
      expect(
        container.read(sentenceWrongProvider)[after.current.key],
        1,
      );

      // 再試一次 → 清空已選
      notifier.retryReorder();
      await tester.pump();
      after = container.read(sentencePracticeProvider(ScenePool.hotel));
      expect(after.feedback, isNull);
      expect(after.picked, isEmpty);
    });

    testWidgets('錯題複習答對 → 移出句子錯題本', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final seed = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      final target = allSentences.first;
      seed.read(sentenceWrongProvider.notifier).add(target.key);
      seed.dispose();

      final (container, notifier) =
          await pump(tester, ScenePool.wrongReview);
      var state =
          container.read(sentencePracticeProvider(ScenePool.wrongReview));
      expect(state.current.key, target.key);

      if (state.type == SentenceQuizType.cloze) {
        notifier.choose(state.correctIndex);
      } else {
        for (final chunk in state.current.chunks) {
          final s = container
              .read(sentencePracticeProvider(ScenePool.wrongReview));
          final idx = List.generate(s.shuffled.length, (i) => i).firstWhere(
            (i) => s.shuffled[i] == chunk && !s.picked.contains(i),
          );
          notifier.pickChunk(idx);
        }
      }
      await tester.pump();
      expect(container.read(sentenceWrongProvider), isEmpty);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
