import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/vocab_data.dart';
import '../../core/logic/quiz_generator.dart';
import '../../core/models/vocab.dart';
import '../progress/mastery_notifier.dart';
import '../progress/srs_notifier.dart';
import '../progress/stats_notifier.dart';
import '../progress/wrong_notifier.dart';

class ListeningFeedback {
  final bool correct;
  final int chosenIndex;

  const ListeningFeedback({required this.correct, required this.chosenIndex});
}

/// 聽力測驗狀態：播放單字發音，從 4 個日文選項選出聽到的字。
class ListeningState {
  final VocabWord current;
  final List<String> options; // 日文字
  final int correctIndex;
  final ListeningFeedback? feedback;
  final int streak;
  final int sessionTotal;
  final int sessionCorrect;

  const ListeningState({
    required this.current,
    required this.options,
    required this.correctIndex,
    this.feedback,
    this.streak = 0,
    this.sessionTotal = 0,
    this.sessionCorrect = 0,
  });
}

class ListeningController extends AutoDisposeNotifier<ListeningState> {
  final QuizGenerator<VocabWord> _generator =
      QuizGenerator(keyOf: (w) => w.key);

  @override
  ListeningState build() => _question(null);

  ListeningState _question(ListeningState? prev) {
    final word = _generator.next(
      allVocab,
      ref.read(masteryProvider),
      previous: prev?.current,
    );
    // 干擾項同主題優先，聽感混淆度較高
    final samesTopic =
        allVocab.where((w) => w.topic == word.topic).toList();
    final (options, correctIndex) = _generator.buildOptions(
      word,
      samesTopic,
      valueOf: (w) => w.jp,
      fallback: allVocab,
    );
    return ListeningState(
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
    final masteryAfter = ref.read(masteryProvider)[word.key] ?? 0;
    ref
        .read(srsProvider.notifier)
        .schedule(word.key, masteryAfter, correct: correct);
    if (!correct) {
      ref.read(vocabWrongProvider.notifier).add(word.key);
    }

    state = ListeningState(
      current: word,
      options: state.options,
      correctIndex: state.correctIndex,
      feedback: ListeningFeedback(correct: correct, chosenIndex: index),
      streak: correct ? state.streak + 1 : 0,
      sessionTotal: state.sessionTotal + 1,
      sessionCorrect: state.sessionCorrect + (correct ? 1 : 0),
    );
  }

  void nextQuestion() {
    state = _question(state);
  }
}

final listeningProvider =
    NotifierProvider.autoDispose<ListeningController, ListeningState>(
  ListeningController.new,
);
