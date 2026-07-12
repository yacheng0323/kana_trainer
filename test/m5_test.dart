import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/services/tts_service.dart';
import 'package:kana_trainer/domain/entities/practice_mode.dart';
import 'package:kana_trainer/data/storage/prefs_provider.dart';
import 'package:kana_trainer/features/listening/listening_view_model.dart';
import 'package:kana_trainer/features/listening/listening_page.dart';
import 'package:kana_trainer/features/practice/practice_page.dart';
import 'package:kana_trainer/features/practice/widgets/quiz_widgets.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 測試用 TTS：記錄播了什麼。
class FakeTts implements TtsService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(ProviderContainer, FakeTts)> pumpApp(
    WidgetTester tester,
    Widget home,
    Type pageType,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final tts = FakeTts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          ttsProvider.overrideWithValue(tts),
        ],
        child: MaterialApp(home: home),
      ),
    );
    final container =
        ProviderScope.containerOf(tester.element(find.byType(pageType)));
    return (container, tts);
  }

  group('聽力測驗', () {
    testWidgets('進頁自動播音、重聽按鈕再播', (tester) async {
      final (container, tts) = await pumpApp(
        tester,
        const ListeningPage(),
        ListeningPage,
      );
      await tester.pump(); // postFrame speak
      final state = container.read(listeningProvider);
      expect(tts.spoken, [state.current.jp]);

      // 點大喇叭重聽
      await tester.tap(find.byIcon(Icons.volume_up).first);
      await tester.pump();
      expect(tts.spoken.length, 2);
    });

    testWidgets('答對計分、答錯進單字錯題本', (tester) async {
      final (container, _) = await pumpApp(
        tester,
        const ListeningPage(),
        ListeningPage,
      );
      await tester.pump();
      var state = container.read(listeningProvider);
      final notifier = container.read(listeningProvider.notifier);

      notifier.choose(state.correctIndex);
      await tester.pump();
      state = container.read(listeningProvider);
      expect(state.feedback!.correct, isTrue);
      expect(state.streak, 1);
      // 答對後顯示單字
      expect(find.textContaining(state.current.jp), findsWidgets);
      await tester.pump(const Duration(seconds: 2)); // flush autoNext

      // 下一題答錯
      state = container.read(listeningProvider);
      final wrongIndex = state.correctIndex == 0 ? 1 : 0;
      notifier.choose(wrongIndex);
      await tester.pump();
      expect(
        container.read(vocabWrongProvider)[state.current.key],
        1,
      );
    });
  });

  group('SpeakButton', () {
    testWidgets('假名練習卡有發音按鈕、點了會唸', (tester) async {
      final (container, tts) = await pumpApp(
        tester,
        const PracticePage(mode: PracticeMode.hiragana),
        PracticePage,
      );
      final speakButtons = find.byType(SpeakButton);
      expect(speakButtons, findsOneWidget);
      await tester.tap(speakButtons);
      await tester.pump();
      expect(tts.spoken.length, 1);
      expect(container, isNotNull);
    });
  });
}
