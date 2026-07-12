import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/static/kana_data.dart';
import 'package:kana_trainer/domain/logic/answer_checker.dart';
import 'package:kana_trainer/domain/logic/quiz_generator.dart';
import 'package:kana_trainer/domain/entities/kana.dart';
import 'package:kana_trainer/domain/entities/practice_mode.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'package:kana_trainer/domain/models/practice_models.dart';
export 'package:kana_trainer/domain/models/practice_models.dart';

/// 練習 session 控制器（family per 模式，離開頁面自動釋放）。
class PracticeViewModel
    extends AutoDisposeFamilyNotifier<PracticeState, PracticeMode> {
  final QuizGenerator<Kana> _generator = QuizGenerator(keyOf: (k) => k.kana);
  late List<Kana> _pool;

  @override
  PracticeState build(PracticeMode arg) {
    final wrongKeys = ref.read(wrongProvider).keys.toSet();
    _pool = arg.buildPool(allKana, wrongKanaKeys: wrongKeys);
    if (_pool.isEmpty) {
      // 錯題模式且無錯題時由 UI 擋掉；此為保險
      _pool = PracticeMode.mixed.buildPool(allKana);
    }
    return _question(null);
  }

  PracticeState _question(PracticeState? prev) {
    final kana =
        _generator.next(_pool, ref.read(masteryProvider), previous: prev?.current);
    final (options, correctIndex) = _generator.buildOptions(
      kana,
      _pool,
      valueOf: (k) => k.romaji,
      fallback: allKana,
    );
    return PracticeState(
      current: kana,
      options: options,
      correctIndex: correctIndex,
      streak: prev?.streak ?? 0,
      sessionTotal: prev?.sessionTotal ?? 0,
      sessionCorrect: prev?.sessionCorrect ?? 0,
    );
  }

  /// 鍵盤輸入作答。已有 feedback 時忽略（避免重複計分）。
  void submit(String input) {
    if (state.feedback != null) return;
    if (input.trim().isEmpty) return;
    final settings = ref.read(settingsProvider);
    final correct = AnswerChecker.check(
      state.current,
      input,
      caseSensitive: settings.caseSensitive,
    );
    _applyAnswer(correct: correct, input: input.trim());
  }

  /// 選擇題作答（點第 [index] 個選項）。
  void choose(int index) {
    if (state.feedback != null) return;
    if (index < 0 || index >= state.options.length) return;
    _applyAnswer(
      correct: index == state.correctIndex,
      input: state.options[index],
      chosenIndex: index,
    );
  }

  void _applyAnswer({
    required bool correct,
    required String input,
    int? chosenIndex,
  }) {
    final kana = state.current;
    ref.read(masteryProvider.notifier).record(kana.kana, correct: correct);
    ref.read(statsProvider.notifier).record(correct: correct);
    if (correct) {
      // 錯題複習中答對 → 錯誤次數 -1，歸零自動移出錯題本
      if (arg == PracticeMode.wrongReview) {
        ref.read(wrongProvider.notifier).resolve(kana.kana);
      }
    } else {
      ref.read(wrongProvider.notifier).add(kana.kana);
    }

    state = state.copyWith(
      feedback: AnswerFeedback(
        correct: correct,
        canonical: kana.romaji,
        accepted: kana.acceptedAnswers,
        input: input,
        chosenIndex: chosenIndex,
      ),
      streak: correct ? state.streak + 1 : 0,
      sessionTotal: state.sessionTotal + 1,
      sessionCorrect: state.sessionCorrect + (correct ? 1 : 0),
    );
  }

  /// 下一題。
  void nextQuestion() {
    state = _question(state);
  }

  /// 同一題再試一次（輸入模式答錯後）。
  void retry() {
    state = state.copyWith(clearFeedback: true);
  }
}

final practiceProvider = NotifierProvider.autoDispose
    .family<PracticeViewModel, PracticeState, PracticeMode>(
  PracticeViewModel.new,
);
