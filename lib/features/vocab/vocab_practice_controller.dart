import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/vocab_data.dart';
import '../../core/logic/quiz_generator.dart';
import '../../core/models/vocab.dart';
import '../progress/mastery_notifier.dart';
import '../progress/stats_notifier.dart';
import '../progress/wrong_notifier.dart';

/// 單字單題作答結果。
class VocabFeedback {
  final bool correct;
  final int chosenIndex;

  const VocabFeedback({required this.correct, required this.chosenIndex});
}

/// 單字練習 session 狀態（M1：日→中 4 選 1）。
class VocabPracticeState {
  final VocabWord current;
  final List<String> options; // 4 個中文意思
  final int correctIndex;
  final VocabFeedback? feedback;
  final int streak;
  final int sessionTotal;
  final int sessionCorrect;

  const VocabPracticeState({
    required this.current,
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
    _pool = arg.buildPool(allVocab, wrongKeys: wrongKeys);
    if (_pool.isEmpty) {
      _pool = List.of(allVocab); // 保險：錯題模式無錯題時由 UI 擋掉
    }
    return _question(null);
  }

  VocabPracticeState _question(VocabPracticeState? prev) {
    final word = _generator.next(
      _pool,
      ref.read(masteryProvider),
      previous: prev?.current,
    );
    final (options, correctIndex) = _generator.buildOptions(
      word,
      _pool,
      valueOf: (w) => w.zh,
      fallback: allVocab,
    );
    return VocabPracticeState(
      current: word,
      options: options,
      correctIndex: correctIndex,
      streak: prev?.streak ?? 0,
      sessionTotal: prev?.sessionTotal ?? 0,
      sessionCorrect: prev?.sessionCorrect ?? 0,
    );
  }

  void choose(int index) {
    if (state.feedback != null) return;
    if (index < 0 || index >= state.options.length) return;
    final correct = index == state.correctIndex;
    final word = state.current;

    ref.read(masteryProvider.notifier).record(word.key, correct: correct);
    ref.read(statsProvider.notifier).record(correct: correct);
    if (correct) {
      if (arg == VocabPool.wrongReview) {
        ref.read(vocabWrongProvider.notifier).resolve(word.key);
      }
    } else {
      ref.read(vocabWrongProvider.notifier).add(word.key);
    }

    state = VocabPracticeState(
      current: word,
      options: state.options,
      correctIndex: state.correctIndex,
      feedback: VocabFeedback(correct: correct, chosenIndex: index),
      streak: correct ? state.streak + 1 : 0,
      sessionTotal: state.sessionTotal + 1,
      sessionCorrect: state.sessionCorrect + (correct ? 1 : 0),
    );
  }

  void nextQuestion() {
    state = _question(state);
  }
}

final vocabPracticeProvider = NotifierProvider.autoDispose
    .family<VocabPracticeController, VocabPracticeState, VocabPool>(
  VocabPracticeController.new,
);
