import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/core/storage/backup_service.dart';
import 'package:kana_trainer/core/storage/prefs_provider.dart';
import 'package:kana_trainer/features/exam/exam_controller.dart';
import 'package:kana_trainer/features/exam/exam_history_notifier.dart';
import 'package:kana_trainer/features/exam/exam_page.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ExamController.buildQuestions', () {
    test('20 題：單字10+假名5+文法5、選項4、correctIndex 合法', () {
      for (var seed = 0; seed < 5; seed++) {
        final qs = ExamController.buildQuestions(Random(seed));
        expect(qs.length, 20);
        expect(qs.where((q) => q.sub!.startsWith('單字')).length, 10);
        expect(qs.where((q) => q.sub!.startsWith('假名')).length, 5);
        expect(qs.where((q) => q.sub!.startsWith('文法')).length, 5);
        for (final q in qs) {
          expect(q.options.length, 4);
          expect(q.options.toSet().length, 4);
          expect(q.correctIndex, inInclusiveRange(0, 3));
          expect(q.answerNote, isNotEmpty);
        }
      }
    });
  });

  group('ExamPage 流程', () {
    testWidgets('開始 → 全部作答 → 交卷 → 分數與紀錄', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: ExamPage()),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ExamPage)),
      );

      expect(find.text('開始測驗'), findsOneWidget);
      await tester.tap(find.text('開始測驗'));
      await tester.pump();

      // 全答正解（直接操作 controller，UI 驗證關鍵畫面）
      final notifier = container.read(examProvider.notifier);
      var state = container.read(examProvider);
      for (var i = 0; i < state.questions.length; i++) {
        notifier.goTo(i);
        notifier.select(state.questions[i].correctIndex);
      }
      await tester.pump();
      state = container.read(examProvider);
      expect(state.answeredCount, 20);

      notifier.submit();
      await tester.pump();
      state = container.read(examProvider);
      expect(state.submitted, isTrue);
      expect(state.score, 20);
      expect(find.text('20/20'), findsOneWidget);
      expect(find.textContaining('合格'), findsOneWidget);

      // 成績已入歷史
      final history = container.read(examHistoryProvider);
      expect(history.length, 1);
      expect(history.first.score, 20);
    });

    testWidgets('未答交卷 → 分數 0、錯題檢討列出', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: ExamPage()),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ExamPage)),
      );
      await tester.tap(find.text('開始測驗'));
      await tester.pump();

      container.read(examProvider.notifier).submit();
      await tester.pump();
      expect(find.text('0/20'), findsOneWidget);
      expect(find.text('錯題檢討'), findsOneWidget);
      expect(find.textContaining('未作答'), findsWidgets);
    });
  });

  group('BackupService', () {
    test('匯出 → 清空 → 匯入還原', () async {
      final prefs = await SharedPreferences.getInstance();
      final c1 = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      c1.read(masteryProvider.notifier).record('か', correct: true);
      c1.dispose();

      final backup = BackupService.export(prefs);
      final decoded = jsonDecode(backup) as Map<String, dynamic>;
      expect(decoded['app'], 'kana_trainer');
      expect((decoded['data'] as Map).containsKey('mastery'), isTrue);

      await prefs.clear();
      expect(prefs.getString('mastery'), isNull);

      final count = await BackupService.import(prefs, backup);
      expect(count, greaterThanOrEqualTo(1));

      final c2 = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(c2.dispose);
      expect(c2.read(masteryProvider)['か'], 1);
    });

    test('格式錯誤丟 FormatException', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(
        () => BackupService.import(prefs, 'not json'),
        throwsFormatException,
      );
      expect(
        () => BackupService.import(prefs, '{"app":"other","data":{}}'),
        throwsFormatException,
      );
    });
  });
}
