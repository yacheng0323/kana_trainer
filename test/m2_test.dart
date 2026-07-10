import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/core/logic/romaji_converter.dart';
import 'package:kana_trainer/core/models/vocab.dart';
import 'package:kana_trainer/core/storage/prefs_provider.dart';
import 'package:kana_trainer/features/progress/srs_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'package:kana_trainer/features/vocab/vocab_practice_controller.dart';
import 'package:kana_trainer/features/vocab/vocab_practice_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> makeContainer() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [prefsProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StatsNotifier.today = () => '2026-07-10';
    SrsNotifier.now = DateTime.now;
  });

  group('RomajiConverter', () {
    test('基本 + 拗音 + 促音 + 長音', () {
      expect(RomajiConverter.toRomaji('でんしゃ'), 'densha');
      expect(RomajiConverter.toRomaji('りょこう'), 'ryokou');
      expect(RomajiConverter.toRomaji('きっぷ'), 'kippu');
      expect(RomajiConverter.toRomaji('めーる'), 'meeru');
      expect(RomajiConverter.toRomaji('ぱすぽーと'), 'pasupooto');
      expect(RomajiConverter.toRomaji('しゅっちょう'), 'shucchou');
      expect(RomajiConverter.toRomaji('ぎゅうにゅう'), 'gyuunyuu');
    });

    test('matchesReading：假名 / 片假名 / 羅馬拼音 / 大小寫', () {
      expect(RomajiConverter.matchesReading('えき', 'えき'), isTrue);
      expect(RomajiConverter.matchesReading('えき', 'エキ'), isTrue);
      expect(RomajiConverter.matchesReading('えき', 'eki'), isTrue);
      expect(RomajiConverter.matchesReading('えき', 'EKI'), isTrue);
      expect(RomajiConverter.matchesReading('えき', ' eki '), isTrue);
      expect(RomajiConverter.matchesReading('えき', 'iki'), isFalse);
      expect(RomajiConverter.matchesReading('えき', ''), isFalse);
    });
  });

  group('SrsNotifier', () {
    test('答對依熟練度排程、答錯立即到期', () async {
      final c = await makeContainer();
      final base = DateTime(2026, 7, 10, 12);
      SrsNotifier.now = () => base;
      final srs = c.read(srsProvider.notifier);

      srs.schedule('v_駅', 3, correct: true); // 7 天後
      srs.schedule('v_水', 0, correct: false); // 立即到期

      expect(srs.dueKeys(['v_駅', 'v_水']), {'v_水'});

      // 8 天後兩者都到期
      SrsNotifier.now = () => base.add(const Duration(days: 8));
      expect(srs.dueKeys(['v_駅', 'v_水']), {'v_駅', 'v_水'});
    });

    test('持久化', () async {
      final base = DateTime(2026, 7, 10, 12);
      SrsNotifier.now = () => base;
      final c1 = await makeContainer();
      c1.read(srsProvider.notifier).schedule('v_駅', 0, correct: false);
      final c2 = await makeContainer();
      expect(c2.read(srsProvider.notifier).dueKeys(['v_駅']), {'v_駅'});
    });
  });

  group('每日目標', () {
    test('達標記 1 天，隔天再達標 +1，斷日重來', () async {
      final c = await makeContainer();
      c.read(settingsProvider.notifier).update((s) => s.copyWith(dailyGoal: 2));
      final n = c.read(statsProvider.notifier);

      n.record(correct: true);
      expect(c.read(statsProvider).goalStreakDays, 0);
      n.record(correct: true); // 達標
      expect(c.read(statsProvider).goalStreakDays, 1);
      n.record(correct: true); // 同日不重複計
      expect(c.read(statsProvider).goalStreakDays, 1);

      // 隔天達標 → 2
      StatsNotifier.today = () => '2026-07-11';
      n.record(correct: true);
      n.record(correct: true);
      expect(c.read(statsProvider).goalStreakDays, 2);

      // 跳一天 → 重新從 1
      StatsNotifier.today = () => '2026-07-13';
      n.record(correct: true);
      n.record(correct: true);
      expect(c.read(statsProvider).goalStreakDays, 1);
    });
  });

  group('單字題型（M2）', () {
    Future<(ProviderContainer, WidgetTester)> pump(
      WidgetTester tester,
      VocabMode mode,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            home: VocabPracticePage(pool: VocabPool.transport),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VocabPracticePage)),
      );
      if (mode != VocabMode.jpZh) {
        container
            .read(settingsProvider.notifier)
            .update((s) => s.copyWith(vocabMode: mode));
        container.read(vocabPracticeProvider(VocabPool.transport).notifier)
            .nextQuestion();
        await tester.pump();
      }
      return (container, tester);
    }

    testWidgets('中→日：題目中文、選項日文', (tester) async {
      final (container, _) = await pump(tester, VocabMode.zhJp);
      final state =
          container.read(vocabPracticeProvider(VocabPool.transport));
      expect(state.mode, VocabMode.zhJp);
      expect(find.text(state.current.zh), findsWidgets); // 題目卡
      expect(state.options[state.correctIndex], state.current.jp);
    });

    testWidgets('讀音輸入：羅馬拼音答對', (tester) async {
      final (container, _) = await pump(tester, VocabMode.reading);
      final state =
          container.read(vocabPracticeProvider(VocabPool.transport));
      expect(state.mode, VocabMode.reading);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        RomajiConverter.toRomaji(state.current.reading),
      );
      await tester.tap(find.text('確認'), warnIfMissed: false);
      await tester.pump();

      expect(find.text('答對了！'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1)); // flush autoNext
    });

    testWidgets('讀音輸入：假名答對、錯誤可再試', (tester) async {
      final (container, _) = await pump(tester, VocabMode.reading);
      var state = container.read(vocabPracticeProvider(VocabPool.transport));

      await tester.enterText(find.byType(TextField), 'xxxx');
      await tester.tap(find.text('確認'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('再試一次'), findsOneWidget);

      await tester.tap(find.text('再試一次'));
      await tester.pump();
      state = container.read(vocabPracticeProvider(VocabPool.transport));
      expect(state.feedback, isNull);

      await tester.enterText(find.byType(TextField), state.current.reading);
      await tester.tap(find.text('確認'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('答對了！'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('作答後 SRS 有排程', (tester) async {
      final (container, _) = await pump(tester, VocabMode.zhJp);
      final state =
          container.read(vocabPracticeProvider(VocabPool.transport));
      container
          .read(vocabPracticeProvider(VocabPool.transport).notifier)
          .choose(state.correctIndex);
      await tester.pump();
      expect(container.read(srsProvider).containsKey(state.current.key),
          isTrue);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
