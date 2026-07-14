import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/domain/logic/quiz_generator.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/srs_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:kana_trainer/domain/models/listening_models.dart';
export 'package:kana_trainer/domain/models/listening_models.dart';

class ListeningViewModel extends AutoDisposeNotifier<ListeningState> {
  final QuizGenerator<VocabWord> _generator =
      QuizGenerator(keyOf: (w) => w.key);

  @override
  ListeningState build() => _question(null);

  ListeningState _question(ListeningState? prev) {
    final all = ref.read(contentRepositoryProvider).vocab();
    final word = _generator.next(
      all,
      ref.read(masteryProvider),
      previous: prev?.current,
    );
    // 干擾項同主題優先，聽感混淆度較高
    final samesTopic = all.where((w) => w.topic == word.topic).toList();
    final (options, correctIndex) = _generator.buildOptions(
      word,
      samesTopic,
      valueOf: (w) => w.jp,
      fallback: all,
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
    NotifierProvider.autoDispose<ListeningViewModel, ListeningState>(
  ListeningViewModel.new,
);
