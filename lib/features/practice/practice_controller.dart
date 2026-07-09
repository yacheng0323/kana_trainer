import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/kana_data.dart';
import '../../core/logic/answer_checker.dart';
import '../../core/logic/quiz_generator.dart';
import '../../core/models/kana.dart';
import '../../core/models/practice_mode.dart';
import '../progress/mastery_notifier.dart';
import '../progress/stats_notifier.dart';
import '../progress/wrong_notifier.dart';
import '../settings/settings_notifier.dart';

/// 單題作答結果。
class AnswerFeedback {
  final bool correct;
  final String canonical;
  final List<String> accepted;
  final String input;

  const AnswerFeedback({
    required this.correct,
    required this.canonical,
    required this.accepted,
    required this.input,
  });
}

/// 練習 session 狀態。
class PracticeState {
  final Kana current;
  final AnswerFeedback? feedback; // null = 等待作答
  final int streak;
  final int sessionTotal;
  final int sessionCorrect;

  const PracticeState({
    required this.current,
    this.feedback,
    this.streak = 0,
    this.sessionTotal = 0,
    this.sessionCorrect = 0,
  });

  double get accuracy => sessionTotal == 0 ? 0 : sessionCorrect / sessionTotal;

  PracticeState copyWith({
    Kana? current,
    AnswerFeedback? feedback,
    bool clearFeedback = false,
    int? streak,
    int? sessionTotal,
    int? sessionCorrect,
  }) {
    return PracticeState(
      current: current ?? this.current,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      streak: streak ?? this.streak,
      sessionTotal: sessionTotal ?? this.sessionTotal,
      sessionCorrect: sessionCorrect ?? this.sessionCorrect,
    );
  }
}

/// 練習 session 控制器（family per 模式，離開頁面自動釋放）。
class PracticeController
    extends AutoDisposeFamilyNotifier<PracticeState, PracticeMode> {
  final QuizGenerator _generator = QuizGenerator();
  late List<Kana> _pool;

  @override
  PracticeState build(PracticeMode arg) {
    final wrongKeys = ref.read(wrongProvider).keys.toSet();
    _pool = arg.buildPool(allKana, wrongKanaKeys: wrongKeys);
    if (_pool.isEmpty) {
      // 錯題模式且無錯題時由 UI 擋掉；此為保險
      _pool = PracticeMode.mixed.buildPool(allKana);
    }
    return PracticeState(current: _next(null));
  }

  Kana _next(Kana? previous) =>
      _generator.next(_pool, ref.read(masteryProvider), previous: previous);

  /// 作答。已有 feedback 時忽略（避免重複計分）。
  void submit(String input) {
    if (state.feedback != null) return;
    if (input.trim().isEmpty) return;
    final settings = ref.read(settingsProvider);
    final kana = state.current;
    final correct = AnswerChecker.check(
      kana,
      input,
      caseSensitive: settings.caseSensitive,
    );

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
        input: input.trim(),
      ),
      streak: correct ? state.streak + 1 : 0,
      sessionTotal: state.sessionTotal + 1,
      sessionCorrect: state.sessionCorrect + (correct ? 1 : 0),
    );
  }

  /// 下一題。
  void nextQuestion() {
    state = state.copyWith(current: _next(state.current), clearFeedback: true);
  }

  /// 同一題再試一次（答錯後）。
  void retry() {
    state = state.copyWith(clearFeedback: true);
  }
}

final practiceProvider = NotifierProvider.autoDispose
    .family<PracticeController, PracticeState, PracticeMode>(
  PracticeController.new,
);
