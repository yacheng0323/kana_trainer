import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/core/notifications/notification_service.dart';
import 'package:kana_trainer/core/storage/backup_service.dart';
import 'package:kana_trainer/core/storage/prefs_provider.dart';
import 'package:kana_trainer/features/progress/daily_history_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'package:kana_trainer/features/settings/settings_page.dart';
import 'package:kana_trainer/features/today/daily_menu_builder.dart';
import 'package:kana_trainer/features/today/daily_menu_page.dart';
import 'package:kana_trainer/features/today/menu_done_notifier.dart';
import 'package:kana_trainer/features/today/widgets/heatmap.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeNotificationService implements NotificationService {
  bool permissionGranted = true;
  final List<String> calls = [];

  @override
  Future<bool> requestPermission() async {
    calls.add('request');
    return permissionGranted;
  }

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    calls.add('schedule $hour:$minute');
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
  }
}

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
  });

  group('DailyMenuBuilder', () {
    test('組成：到期優先、錯題上限、新內容補滿到 15、key 不重複', () {
      final questions = DailyMenuBuilder.build(
        mastery: {'v_駅': 2},
        dueVocabKeys: {'v_駅', 'v_水', 'v_旅行'},
        kanaWrong: {'か': 2, 'シ': 1, 'つ': 1, 'ん': 3}, // 4 筆 → 取 3
        vocabWrong: {'v_電車': 1},
        sentenceWrong: {'s_メニューをください': 2},
        rng: Random(1),
      );
      expect(questions.length, DailyMenuBuilder.targetSize);
      // key 不重複
      expect(questions.map((q) => q.sourceKey).toSet().length, questions.length);
      // 到期 3 筆全進（<= maxDue）
      expect(questions.where((q) => q.note.startsWith('複習')).length, 3);
      // 假名錯題取上限 3
      expect(
        questions.where((q) => q.kind == 'kana' && q.note.startsWith('錯題')).length,
        3,
      );
      // 句子錯題 1 筆
      expect(questions.where((q) => q.kind == 'sentence').length, 1);
      // 每題 4 個不重複選項且正解合法
      for (final q in questions) {
        expect(q.options.length, 4);
        expect(q.options.toSet().length, 4);
        expect(q.correctIndex, inInclusiveRange(0, 3));
      }
    });

    test('全空狀態也能出滿 15 題新內容', () {
      final questions = DailyMenuBuilder.build(
        mastery: {},
        dueVocabKeys: {},
        kanaWrong: {},
        vocabWrong: {},
        sentenceWrong: {},
        rng: Random(2),
      );
      expect(questions.length, DailyMenuBuilder.targetSize);
      expect(questions.every((q) => q.note.startsWith('新內容')), isTrue);
    });

    test('preview 數量與 build 邏輯一致', () {
      final p = DailyMenuBuilder.preview(
        dueVocabKeys: {'v_駅'},
        kanaWrong: {'か': 1},
        vocabWrong: {},
        sentenceWrong: {},
      );
      expect(p.due, 1);
      expect(p.wrong, 1);
      expect(p.total, DailyMenuBuilder.targetSize);
    });
  });

  group('DailyHistory + 熱力圖', () {
    test('stats.record 同步累計 daily_history、含備份', () async {
      final c = await makeContainer();
      c.read(statsProvider.notifier).record(correct: true);
      c.read(statsProvider.notifier).record(correct: false);
      expect(c.read(dailyHistoryProvider)['2026-07-10'], 2);
      expect(BackupService.backupKeys, contains('daily_history'));
      expect(BackupService.backupKeys, contains('menu_done'));
    });

    test('顏色分級', () {
      expect(StudyHeatmap.colorFor(0), const Color(0x1422254A));
      expect(StudyHeatmap.colorFor(5), isNot(StudyHeatmap.colorFor(0)));
      expect(StudyHeatmap.colorFor(25), isNot(StudyHeatmap.colorFor(5)));
      expect(StudyHeatmap.colorFor(50), isNot(StudyHeatmap.colorFor(25)));
    });
  });

  group('MenuDone', () {
    test('打卡當日 doneToday、跨日重置', () async {
      final c = await makeContainer();
      final n = c.read(menuDoneProvider.notifier);
      expect(n.doneToday, isFalse);
      n.markDone(score: 12, total: 15);
      expect(n.doneToday, isTrue);
      expect(c.read(menuDoneProvider).score, 12);

      StatsNotifier.today = () => '2026-07-11';
      expect(n.doneToday, isFalse);
    });
  });

  group('DailyMenuPage', () {
    testWidgets('答完全部 → 打卡 + 錯題答對消化', (tester) async {
      // 種一筆假名錯題，讓菜單包含它
      final prefs = await SharedPreferences.getInstance();
      final seed = ProviderContainer(
        overrides: [prefsProvider.overrideWithValue(prefs)],
      );
      seed.read(wrongProvider.notifier).add('か');
      seed.dispose();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: DailyMenuPage()),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DailyMenuPage)),
      );
      final state = tester.state<ConsumerState>(find.byType(DailyMenuPage));
      // 直接操作 15 題全答對（UI 驗證關鍵節點）
      // ignore: avoid_dynamic_calls
      final dynamic s = state;
      final questions = s.debugQuestions as List<MenuQuestion>;
      expect(questions.length, DailyMenuBuilder.targetSize);
      expect(questions.any((q) => q.sourceKey == 'か'), isTrue);

      for (var i = 0; i < questions.length; i++) {
        s.debugChoose(questions[i].correctIndex);
        await tester.pump();
        if (i < questions.length - 1) {
          await tester.ensureVisible(find.text('下一題'));
          await tester.tap(find.text('下一題'));
        } else {
          await tester.ensureVisible(find.text('完成任務'));
          await tester.tap(find.text('完成任務'));
        }
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('今日任務完成'), findsOneWidget);
      expect(container.read(menuDoneProvider.notifier).doneToday, isTrue);
      // 錯題「か」答對 → resolve 消化
      expect(container.read(wrongProvider).containsKey('か'), isFalse);
      // stats 有累計
      expect(container.read(statsProvider).todayTotal,
          DailyMenuBuilder.targetSize);
    });
  });

  group('每日提醒設定', () {
    testWidgets('開啟 → 要權限 + 排程；關閉 → 取消', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final fake = FakeNotificationService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            notificationServiceProvider.overrideWithValue(fake),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsPage)),
      );

      await tester.ensureVisible(find.text('每日提醒'));
      await tester.tap(find.text('每日提醒'));
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).reminderEnabled, isTrue);
      expect(fake.calls, ['request', 'schedule 20:0']);

      await tester.tap(find.text('每日提醒'));
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).reminderEnabled, isFalse);
      expect(fake.calls.last, 'cancel');
    });

    testWidgets('權限被拒 → 不開啟', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final fake = FakeNotificationService()..permissionGranted = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            notificationServiceProvider.overrideWithValue(fake),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsPage)),
      );
      await tester.ensureVisible(find.text('每日提醒'));
      await tester.tap(find.text('每日提醒'));
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).reminderEnabled, isFalse);
      expect(find.text('未取得通知權限，請到系統設定開啟'), findsOneWidget);
    });
  });
}
