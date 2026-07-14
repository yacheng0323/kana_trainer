import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/domain/logic/quiz_generator.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:kana_trainer/domain/models/sentence_models.dart';
export 'package:kana_trainer/domain/models/sentence_models.dart';

class SentenceViewModel
    extends AutoDisposeFamilyNotifier<SentencePracticeState, ScenePool> {
  // freshWeight 12：沒見過的新句優先出（同單字，v2.6.2 機制）
  final QuizGenerator<Sentence> _generator =
      QuizGenerator(keyOf: (s) => s.key, freshWeight: 12);
  final Random _rng = Random();
  late List<Sentence> _all; // 靜態 + 動態合併池
  late List<Sentence> _pool;

  @override
  SentencePracticeState build(ScenePool arg) {
    _rebuildPool();
    return _question(null);
  }

  void _rebuildPool() {
    _all = ref.read(contentRepositoryProvider).sentences();
    final wrongKeys = ref.read(sentenceWrongProvider).keys.toSet();
    _pool = arg.buildPool(_all, wrongKeys: wrongKeys);
    if (_pool.isEmpty) {
      _pool = List.of(_all);
    }
  }

  /// 題庫擴充完成後呼叫：新題併入當前池，session 不重置。
  void refreshPool() {
    _rebuildPool();
  }

  SentencePracticeState _question(SentencePracticeState? prev) {
    final sentence = _generator.next(
      _pool,
      ref.read(masteryProvider),
      previous: prev?.current,
    );
    // 語塊少於 3 的句子不適合重組，固定出克漏字
    final type = sentence.chunks.length >= 3 && _rng.nextBool()
        ? SentenceQuizType.reorder
        : SentenceQuizType.cloze;

    if (type == SentenceQuizType.cloze) {
      // 干擾項 = 其他句子的挖空詞（同場景優先）
      final (options, correctIndex) = _generator.buildOptions(
        sentence,
        _pool,
        valueOf: (s) => s.blank,
        fallback: _all,
      );
      return SentencePracticeState(
        current: sentence,
        type: type,
        options: options,
        correctIndex: correctIndex,
        streak: prev?.streak ?? 0,
        sessionTotal: prev?.sessionTotal ?? 0,
        sessionCorrect: prev?.sessionCorrect ?? 0,
      );
    }

    // 重組：打亂到與原順序不同
    var shuffled = List.of(sentence.chunks);
    do {
      shuffled.shuffle(_rng);
    } while (shuffled.join() == sentence.jp);
    return SentencePracticeState(
      current: sentence,
      type: type,
      shuffled: shuffled,
      streak: prev?.streak ?? 0,
      sessionTotal: prev?.sessionTotal ?? 0,
      sessionCorrect: prev?.sessionCorrect ?? 0,
    );
  }

  /// 克漏字作答。
  void choose(int index) {
    if (state.feedback != null || state.type != SentenceQuizType.cloze) return;
    if (index < 0 || index >= state.options.length) return;
    _apply(
      correct: index == state.correctIndex,
      feedback: (c) => SentenceFeedback(correct: c, chosenIndex: index),
    );
  }

  /// 重組：點選語塊池中第 [shuffledIndex] 塊。集滿自動判定。
  void pickChunk(int shuffledIndex) {
    if (state.feedback != null || state.type != SentenceQuizType.reorder) {
      return;
    }
    if (state.picked.contains(shuffledIndex)) return;
    final picked = [...state.picked, shuffledIndex];
    if (picked.length < state.shuffled.length) {
      state = state.copyWith(picked: picked);
      return;
    }
    final answer = picked.map((i) => state.shuffled[i]).join();
    state = state.copyWith(picked: picked);
    _apply(
      correct: answer == state.current.jp,
      feedback: (c) => SentenceFeedback(correct: c),
    );
  }

  /// 重組：移除已選的語塊。
  void unpickChunk(int pickedPosition) {
    if (state.feedback != null || state.type != SentenceQuizType.reorder) {
      return;
    }
    if (pickedPosition < 0 || pickedPosition >= state.picked.length) return;
    state = state.copyWith(picked: [...state.picked]..removeAt(pickedPosition));
  }

  void _apply({
    required bool correct,
    required SentenceFeedback Function(bool) feedback,
  }) {
    final s = state.current;
    ref.read(masteryProvider.notifier).record(s.key, correct: correct);
    ref.read(statsProvider.notifier).record(correct: correct);
    if (correct) {
      if (arg == ScenePool.wrongReview) {
        ref.read(sentenceWrongProvider.notifier).resolve(s.key);
      }
    } else {
      ref.read(sentenceWrongProvider.notifier).add(s.key);
    }
    state = state.copyWith(
      feedback: feedback(correct),
      streak: correct ? state.streak + 1 : 0,
      sessionTotal: state.sessionTotal + 1,
      sessionCorrect: state.sessionCorrect + (correct ? 1 : 0),
    );
  }

  void nextQuestion() {
    state = _question(state);
  }

  /// 重組答錯後重試：清空已選，同一題再排一次。
  void retryReorder() {
    if (state.type != SentenceQuizType.reorder) return;
    state = SentencePracticeState(
      current: state.current,
      type: state.type,
      shuffled: state.shuffled,
      streak: state.streak,
      sessionTotal: state.sessionTotal,
      sessionCorrect: state.sessionCorrect,
    );
  }
}

final sentencePracticeProvider = NotifierProvider.autoDispose
    .family<SentenceViewModel, SentencePracticeState, ScenePool>(
  SentenceViewModel.new,
);
