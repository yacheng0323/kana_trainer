import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/static/grammar_data.dart';
import 'package:kana_trainer/data/static/kana_data.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/domain/logic/quiz_generator.dart';
import 'package:kana_trainer/domain/entities/kana.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'exam_history_notifier.dart';
import 'package:kana_trainer/domain/models/exam_models.dart';
export 'package:kana_trainer/domain/models/exam_models.dart';

/// N5 模擬測驗：20 題（單字 10 + 假名 5 + 文法 5），限時 10 分鐘。
/// 作答中不給回饋，交卷後評分 + 檢討。
class ExamViewModel extends AutoDisposeNotifier<ExamState> {
  static const examSeconds = 600; // 10 分鐘
  late DateTime _startedAt;

  @override
  ExamState build() {
    final questions = buildQuestions(Random());
    _startedAt = DateTime.now();
    return ExamState(
      questions: questions,
      answers: List.filled(questions.length, null),
    );
  }

  /// 出卷：單字 10（日→中）+ 假名 5（→ 羅馬拼音）+ 文法 5。
  static List<ExamQuestion> buildQuestions(Random rng) {
    final questions = <ExamQuestion>[];
    final vocabGen = QuizGenerator<VocabWord>(keyOf: (w) => w.key, rng: rng);
    final kanaGen = QuizGenerator<Kana>(keyOf: (k) => k.kana, rng: rng);

    final words = List.of(allVocab)..shuffle(rng);
    for (final w in words.take(10)) {
      final (options, correctIndex) =
          vocabGen.buildOptions(w, allVocab, valueOf: (x) => x.zh);
      questions.add(ExamQuestion(
        prompt: w.jp,
        sub: '單字・選出正確意思',
        options: options,
        correctIndex: correctIndex,
        answerNote: '${w.jp}（${w.reading}）= ${w.zh}',
      ));
    }

    final kanas = List.of(allKana)..shuffle(rng);
    for (final k in kanas.take(5)) {
      final (options, correctIndex) =
          kanaGen.buildOptions(k, allKana, valueOf: (x) => x.romaji);
      questions.add(ExamQuestion(
        prompt: k.kana,
        sub: '假名・選出正確讀音',
        options: options,
        correctIndex: correctIndex,
        answerNote: '${k.kana} = ${k.romaji}',
      ));
    }

    final grammarQs = [
      for (final g in allGrammar)
        for (final q in g.quiz) (g, q),
    ]..shuffle(rng);
    for (final (g, q) in grammarQs.take(5)) {
      // 打亂選項順序
      final order = List.generate(q.options.length, (i) => i)..shuffle(rng);
      final options = [for (final i in order) q.options[i]];
      questions.add(ExamQuestion(
        prompt: q.question,
        sub: '文法・${g.title}',
        options: options,
        correctIndex: order.indexOf(q.correctIndex),
        answerNote:
            q.question.replaceFirst('＿＿', '「${q.options[q.correctIndex]}」'),
      ));
    }

    return questions..shuffle(rng);
  }

  void select(int optionIndex) {
    if (state.submitted) return;
    final answers = List.of(state.answers);
    answers[state.index] = optionIndex;
    state = state.copyWith(answers: answers);
  }

  void goTo(int index) {
    if (state.submitted) return;
    if (index < 0 || index >= state.questions.length) return;
    state = state.copyWith(index: index);
  }

  void next() => goTo(state.index + 1);
  void previous() => goTo(state.index - 1);

  void submit() {
    if (state.submitted) return;
    var score = 0;
    for (var i = 0; i < state.questions.length; i++) {
      if (state.answers[i] == state.questions[i].correctIndex) score++;
    }
    final duration = DateTime.now().difference(_startedAt).inSeconds;
    state = state.copyWith(
      submitted: true,
      score: score,
      durationSec: duration,
    );
    ref.read(examHistoryProvider.notifier).add(ExamRecord(
          dateIso: DateTime.now().toIso8601String(),
          score: score,
          total: state.questions.length,
          durationSec: duration,
        ));
  }
}

final examProvider = NotifierProvider.autoDispose<ExamViewModel, ExamState>(
  ExamViewModel.new,
);
