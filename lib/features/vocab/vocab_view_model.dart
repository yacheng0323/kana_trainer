import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/domain/logic/quiz_generator.dart';
import 'package:kana_trainer/domain/logic/romaji_converter.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/srs_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'package:kana_trainer/domain/models/vocab_models.dart';
export 'package:kana_trainer/domain/models/vocab_models.dart';

class VocabViewModel
    extends AutoDisposeFamilyNotifier<VocabPracticeState, VocabPool> {
  // freshWeight 12：沒見過的新字出現機率加倍，詞彙量持續往前推
  final QuizGenerator<VocabWord> _generator =
      QuizGenerator(keyOf: (w) => w.key, freshWeight: 12);
  late List<VocabWord> _all; // 靜態 + 動態合併池
  late List<VocabWord> _pool;

  @override
  VocabPracticeState build(VocabPool arg) {
    _rebuildPool();
    return _question(null);
  }

  void _rebuildPool() {
    _all = ref.read(contentRepositoryProvider).vocab();
    final wrongKeys = ref.read(vocabWrongProvider).keys.toSet();
    final dueKeys =
        ref.read(srsProvider.notifier).dueKeys(_all.map((w) => w.key));
    _pool = arg.buildPool(_all, wrongKeys: wrongKeys, dueKeys: dueKeys);
    if (_pool.isEmpty) {
      _pool = List.of(_all); // 保險：空池由 UI 擋掉
    }
  }

  /// 題庫擴充完成後呼叫：把新題併入當前池，session（連對/統計）不重置。
  void refreshPool() {
    _rebuildPool();
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
        fallback: _all,
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
    .family<VocabViewModel, VocabPracticeState, VocabPool>(
  VocabViewModel.new,
);
