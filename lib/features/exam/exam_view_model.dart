import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/data/static/grammar_data.dart';
import 'package:kana_trainer/data/static/kana_data.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/logic/quiz_generator.dart';
import 'package:kana_trainer/domain/entities/kana.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'exam_history_notifier.dart';
import 'package:kana_trainer/domain/models/exam_models.dart';
export 'package:kana_trainer/domain/models/exam_models.dart';

/// 模擬測驗（等級跟 settings）：20 題（單字 10 + 假名 5 + 文法 5），限時 10 分鐘。
/// N5 = 靜態題庫；N4~N1 = 該等級動態池組卷（可考性由 ExamReadiness 把關）。
/// 作答中不給回饋，交卷後評分 + 檢討。
class ExamViewModel extends AutoDisposeNotifier<ExamState> {
  static const examSeconds = 600; // 10 分鐘
  late DateTime _startedAt;

  @override
  ExamState build() {
    final level = ref.read(settingsProvider).jlptLevel;
    final questions = level == 5
        ? buildQuestions(Random())
        : buildQuestions(
            Random(),
            level: level,
            vocabPool: ref
                .read(contentRepositoryProvider)
                .vocab()
                .where((w) => w.jlpt == level)
                .toList(),
            grammarPool: [
              for (final l in ref
                  .read(dynamicContentStoreProvider)
                  .grammarLessons()
                  .where((l) => l.level == level))
                ...l.quiz,
            ],
          );
    _startedAt = DateTime.now();
    return ExamState(
      questions: questions,
      answers: List.filled(questions.length, null),
    );
  }

  /// 出卷：單字 10（日→中）+ 假名 5（→ 羅馬拼音）+ 文法 5。
  /// [level]==5 或 pool 未傳 → 靜態 N5 路徑（行為不變）。
  static List<ExamQuestion> buildQuestions(
    Random rng, {
    int level = 5,
    List<VocabWord>? vocabPool,
    List<GrammarQuiz>? grammarPool,
  }) {
    final questions = <ExamQuestion>[];
    final vocabGen = QuizGenerator<VocabWord>(keyOf: (w) => w.key, rng: rng);
    final kanaGen = QuizGenerator<Kana>(keyOf: (k) => k.kana, rng: rng);
    final vocabSource =
        (level == 5 || vocabPool == null) ? allVocab : vocabPool;

    final words = List.of(vocabSource)..shuffle(rng);
    for (final w in words.take(10)) {
      final (options, correctIndex) = vocabGen.buildOptions(w, vocabSource,
          valueOf: (x) => x.zh, fallback: allVocab);
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

    // 文法題來源：N5 = 靜態課（帶課名）；N4~N1 = 動態課 quiz 池
    final grammarQs = (level == 5 || grammarPool == null)
        ? ([
            for (final g in allGrammar)
              for (final q in g.quiz) (g.title, q),
          ]..shuffle(rng))
        : ([
            for (final q in grammarPool) ('N$level', q),
          ]..shuffle(rng));
    for (final (title, q) in grammarQs.take(5)) {
      // 打亂選項順序
      final order = List.generate(q.options.length, (i) => i)..shuffle(rng);
      final options = [for (final i in order) q.options[i]];
      questions.add(ExamQuestion(
        prompt: q.question,
        sub: '文法・$title',
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
          level: ref.read(settingsProvider).jlptLevel,
        ));
  }
}

final examProvider = NotifierProvider.autoDispose<ExamViewModel, ExamState>(
  ExamViewModel.new,
);
