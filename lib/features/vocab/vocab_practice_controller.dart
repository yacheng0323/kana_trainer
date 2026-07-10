import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/vocab_data.dart';
import '../../core/logic/quiz_generator.dart';
import '../../core/logic/romaji_converter.dart';
import '../../core/models/vocab.dart';
import '../progress/mastery_notifier.dart';
import '../progress/srs_notifier.dart';
import '../progress/stats_notifier.dart';
import '../progress/wrong_notifier.dart';
import '../settings/settings_notifier.dart';

/// 單字單題作答結果。
class VocabFeedback {
  final bool correct;
  final int? chosenIndex; // MC 題型
  final String? input; // 讀音輸入題型

  const VocabFeedback({required this.correct, this.chosenIndex, this.input});
}

/// 單字練習 session 狀態。
/// [options] 依題型：日→中 = 中文意思、中→日 = 日文字；讀音輸入 = 空。
class VocabPracticeState {
  final VocabWord current;
  final VocabMode mode;
  final List<String> options;
  final int correctIndex;
  final VocabFeedback? feedback;
  final int streak;
  final int sessionTotal;
  final int sessionCorrect;

  const VocabPracticeState({
    required this.current,
    required this.mode,
    required this.options,
    required this.correctIndex,
    this.feedback,
    this.streak = 0,
    this.sessionTotal = 0,
    this.sessionCorrect = 0,
  });
}

class VocabPracticeController
    extends AutoDisposeFamilyNotifier<VocabPracticeState, VocabPool> {
  final QuizGenerator<VocabWord> _generator =
      QuizGenerator(keyOf: (w) => w.key);
  late List<VocabWord> _pool;

  @override
  VocabPracticeState build(VocabPool arg) {
    final wrongKeys = ref.read(vocabWrongProvider).keys.toSet();
    final dueKeys = ref
        .read(srsProvider.notifier)
        .dueKeys(allVocab.map((w) => w.key));
    _pool = arg.buildPool(allVocab, wrongKeys: wrongKeys, dueKeys: dueKeys);
    if (_pool.isEmpty) {
      _pool = List.of(allVocab); // 保險：空池由 UI 擋掉
    }
    return _question(null);
  }

  VocabPracticeState _question(VocabPracticeState? prev) {
    final mode = ref.read(settingsProvider).vocabMode;
    final word = _generator.next(
      _pool,
      ref.read(masteryProvider),
      previous: prev?.current,
    );
    List<String> options = const [];
    var correctIndex = 0;
    if (mode != VocabMode.reading) {
      (options, correctIndex) = _generator.buildOptions(
        word,
        _pool,
        valueOf: mode == VocabMode.jpZh ? (w) => w.zh : (w) => w.jp,
        fallback: allVocab,
      );
    }
    return VocabPracticeState(
      current: word,
      mode: mode,
      options: options,
      correctIndex: correctIndex,
      streak: prev?.streak ?? 0,
      sessionTotal: prev?.sessionTotal ?? 0,
      sessionCorrect: prev?.sessionCorrect ?? 0,
    );
  }

  /// MC 題型作答。
  void choose(int index) {
    if (state.feedback != null || state.mode == VocabMode.reading) return;
    if (index < 0 || index >= state.options.length) return;
    _apply(
      correct: index == state.correctIndex,
      feedback: (c) => VocabFeedback(correct: c, chosenIndex: index),
    );
  }

  /// 讀音輸入作答（接受假名 / Hepburn 羅馬拼音）。
  void submitReading(String input) {
    if (state.feedback != null || state.mode != VocabMode.reading) return;
    if (input.trim().isEmpty) return;
    _apply(
      correct: RomajiConverter.matchesReading(state.current.reading, input),
      feedback: (c) => VocabFeedback(correct: c, input: input.trim()),
    );
  }

  void _apply({
    required bool correct,
    required VocabFeedback Function(bool) feedback,
  }) {
    final word = state.current;
    ref.read(masteryProvider.notifier).record(word.key, correct: correct);
    ref.read(statsProvider.notifier).record(correct: correct);
    // SRS 排程（依作答後熟練度）
    final masteryAfter = ref.read(masteryProvider)[word.key] ?? 0;
    ref
        .read(srsProvider.notifier)
        .schedule(word.key, masteryAfter, correct: correct);
    if (correct) {
      if (arg == VocabPool.wrongReview) {
        ref.read(vocabWrongProvider.notifier).resolve(word.key);
      }
    } else {
      ref.read(vocabWrongProvider.notifier).add(word.key);
    }

    state = VocabPracticeState(
      current: word,
      mode: state.mode,
      options: state.options,
      correctIndex: state.correctIndex,
      feedback: feedback(correct),
      streak: correct ? state.streak + 1 : 0,
      sessionTotal: state.sessionTotal + 1,
      sessionCorrect: state.sessionCorrect + (correct ? 1 : 0),
    );
  }

  void nextQuestion() {
    state = _question(state);
  }

  /// 讀音輸入答錯後再試一次。
  void retry() {
    state = VocabPracticeState(
      current: state.current,
      mode: state.mode,
      options: state.options,
      correctIndex: state.correctIndex,
      streak: state.streak,
      sessionTotal: state.sessionTotal,
      sessionCorrect: state.sessionCorrect,
    );
  }
}

final vocabPracticeProvider = NotifierProvider.autoDispose
    .family<VocabPracticeController, VocabPracticeState, VocabPool>(
  VocabPracticeController.new,
);
