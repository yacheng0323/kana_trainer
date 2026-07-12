import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/static/grammar_data.dart';
import 'package:kana_trainer/data/storage/prefs_provider.dart';
import 'package:kana_trainer/features/grammar/grammar_lesson_page.dart';
import 'package:kana_trainer/features/grammar/grammar_list_page.dart';
import 'package:kana_trainer/features/grammar/grammar_progress_notifier.dart';
import 'package:kana_trainer/features/practice/widgets/quiz_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('grammar_data', () {
    test('12 課、id 唯一、每課 3 題 4 選項、correctIndex 合法', () {
      expect(allGrammar.length, 12);
      expect(allGrammar.map((g) => g.id).toSet().length, 12);
      for (final g in allGrammar) {
        expect(g.quiz.length, 3, reason: '${g.id} 應有 3 題');
        expect(g.examples, isNotEmpty);
        for (final q in g.quiz) {
          expect(q.options.length, 4);
          expect(q.options.toSet().length, 4, reason: '${g.id} 選項重複');
          expect(q.correctIndex, inInclusiveRange(0, 3));
          expect(q.question, contains('＿＿'));
        }
      }
    });
  });

  group('GrammarProgressNotifier', () {
    test('線性解鎖 + 持久化', () async {
      final prefs = await SharedPreferences.getInstance();
      final c1 = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      final p = c1.read(grammarProgressProvider.notifier);
      expect(p.isUnlocked(0), isTrue);
      expect(p.isUnlocked(1), isFalse);
      p.markDone(allGrammar[0].id);
      expect(p.isUnlocked(1), isTrue);
      expect(p.isUnlocked(2), isFalse);
      c1.dispose();

      final c2 = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(c2.dispose);
      expect(c2.read(grammarProgressProvider), {allGrammar[0].id});
    });
  });

  group('GrammarLessonPage', () {
    testWidgets('教學 → 3 題全對 → 標記完成', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final point = allGrammar.first;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: MaterialApp(home: GrammarLessonPage(point: point)),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GrammarLessonPage)),
      );

      // 教學頁
      expect(find.textContaining(point.examples.first.jp), findsOneWidget);
      await tester.ensureVisible(find.text('開始練習（3 題）'));
      await tester.tap(find.text('開始練習（3 題）'));
      await tester.pump();

      // 依序答對 3 題（選項已打亂，從資料找正解文字）
      for (var i = 0; i < 3; i++) {
        final q = point.quiz[i];
        final correctText = q.options[q.correctIndex];
        final f = find.descendant(
          of: find.byType(OptionButton),
          matching: find.text(correctText),
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pump();
        final buttonLabel = i == 2 ? '看結果' : '下一題';
        await tester.ensureVisible(find.text(buttonLabel));
        await tester.tap(find.text(buttonLabel));
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('全對，本課完成'), findsOneWidget);
      expect(container.read(grammarProgressProvider), contains(point.id));
    });

    testWidgets('有答錯 → 不標記完成、可重新測驗', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final point = allGrammar.first;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: MaterialApp(home: GrammarLessonPage(point: point)),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GrammarLessonPage)),
      );

      await tester.ensureVisible(find.text('開始練習（3 題）'));
      await tester.tap(find.text('開始練習（3 題）'));
      await tester.pump();

      for (var i = 0; i < 3; i++) {
        final q = point.quiz[i];
        // 故意選錯（挑非正解選項）
        final wrongText =
            q.options[(q.correctIndex + 1) % q.options.length];
        final f = find.descendant(
          of: find.byType(OptionButton),
          matching: find.text(wrongText),
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pump();
        final buttonLabel = i == 2 ? '看結果' : '下一題';
        await tester.ensureVisible(find.text(buttonLabel));
        await tester.tap(find.text(buttonLabel));
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('答對 0/3'), findsOneWidget);
      expect(find.text('重新測驗'), findsOneWidget);
      expect(container.read(grammarProgressProvider), isEmpty);
    });
  });

  group('GrammarListPage', () {
    testWidgets('未完成時只有第一課可點', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: GrammarListPage()),
        ),
      );
      expect(find.text(allGrammar[0].title), findsOneWidget);
      expect(find.text('可開始'), findsOneWidget); // 只有第一課
      expect(find.text('完成上一課解鎖'), findsWidgets);
    });
  });
}
