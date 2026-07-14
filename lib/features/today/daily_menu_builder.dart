import 'dart:math';

import 'package:kana_trainer/data/static/kana_data.dart';
import 'package:kana_trainer/data/static/sentence_data.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/domain/logic/quiz_generator.dart';
import 'package:kana_trainer/domain/entities/kana.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/models/menu_models.dart';
export 'package:kana_trainer/domain/models/menu_models.dart';

/// 組今日菜單：SRS 到期單字 → 三本錯題 → 新內容（低熟練度）補滿。
/// 全部 4 選 1、立即回饋；key 去重。
class DailyMenuBuilder {
  static const targetSize = 15;
  static const maxDue = 6;
  static const maxWrongKana = 3;
  static const maxWrongVocab = 3;
  static const maxWrongSentence = 2;

  /// 首頁預覽（不生成題目，只算數量）。
  static MenuPreview preview({
    required Set<String> dueVocabKeys,
    required Map<String, int> kanaWrong,
    required Map<String, int> vocabWrong,
    required Map<String, int> sentenceWrong,
  }) {
    final due = min<int>(dueVocabKeys.length, maxDue);
    final wrong = min<int>(kanaWrong.length, maxWrongKana) +
        min<int>(vocabWrong.length, maxWrongVocab) +
        min<int>(sentenceWrong.length, maxWrongSentence);
    final fresh = max<int>(0, targetSize - due - wrong);
    return MenuPreview(due: due, wrong: wrong, fresh: fresh);
  }

  static List<MenuQuestion> build({
    required Map<String, int> mastery,
    required Set<String> dueVocabKeys,
    required Map<String, int> kanaWrong,
    required Map<String, int> vocabWrong,
    required Map<String, int> sentenceWrong,
    List<VocabWord>? vocabPool, // 不傳 = 靜態表（動態池由呼叫端經 repo 傳入）
    List<Sentence>? sentencePool,
    Random? rng,
  }) {
    final random = rng ?? Random();
    final vocabAll = vocabPool ?? allVocab;
    final sentenceAll = sentencePool ?? allSentences;
    VocabWord? vocabByKey(String key) =>
        vocabAll.where((w) => w.key == key).firstOrNull;
    Sentence? sentenceByKey(String key) =>
        sentenceAll.where((s) => s.key == key).firstOrNull;
    final kanaGen = QuizGenerator<Kana>(keyOf: (k) => k.kana, rng: random);
    final vocabGen = QuizGenerator<VocabWord>(keyOf: (w) => w.key, rng: random);
    final sentenceGen =
        QuizGenerator<Sentence>(keyOf: (s) => s.key, rng: random);

    final used = <String>{};
    final questions = <MenuQuestion>[];

    MenuQuestion vocabQuestion(VocabWord w, String noteTag) {
      final (options, correctIndex) = vocabGen.buildOptions(
        w,
        vocabAll.where((x) => x.topic == w.topic).toList(),
        valueOf: (x) => x.zh,
        fallback: vocabAll,
      );
      return MenuQuestion(
        kind: 'vocab',
        sourceKey: w.key,
        // 漢字洩題（漢字常＝中文答案）：出題用假名，note 作答後揭曉漢字
        prompt: w.reading,
        options: options,
        correctIndex: correctIndex,
        note: '$noteTag：${w.jp}（${w.reading}）= ${w.zh}',
      );
    }

    MenuQuestion kanaQuestion(Kana k, String noteTag) {
      final (options, correctIndex) = kanaGen.buildOptions(
        k,
        allKana,
        valueOf: (x) => x.romaji,
      );
      return MenuQuestion(
        kind: 'kana',
        sourceKey: k.kana,
        prompt: k.kana,
        options: options,
        correctIndex: correctIndex,
        note: '$noteTag：${k.kana} = ${k.romaji}',
      );
    }

    MenuQuestion sentenceQuestion(Sentence s, String noteTag) {
      final (options, correctIndex) = sentenceGen.buildOptions(
        s,
        sentenceAll.where((x) => x.scene == s.scene).toList(),
        valueOf: (x) => x.blank,
        fallback: sentenceAll,
      );
      return MenuQuestion(
        kind: 'sentence',
        sourceKey: s.key,
        prompt: s.clozeText,
        subtitle: s.zh,
        options: options,
        correctIndex: correctIndex,
        note: '$noteTag：${s.jp}',
      );
    }

    // 1. SRS 到期單字
    var dueTaken = 0;
    for (final key in dueVocabKeys.toList()..shuffle(random)) {
      if (dueTaken >= maxDue) break;
      final w = vocabByKey(key);
      if (w == null || !used.add(key)) continue;
      questions.add(vocabQuestion(w, '複習'));
      dueTaken++;
    }

    // 2. 錯題（假名/單字/句子）
    var t = 0;
    for (final key in kanaWrong.keys.toList()..shuffle(random)) {
      if (t >= maxWrongKana) break;
      final k = findKana(key);
      if (k == null || !used.add(key)) continue;
      questions.add(kanaQuestion(k, '錯題'));
      t++;
    }
    t = 0;
    for (final key in vocabWrong.keys.toList()..shuffle(random)) {
      if (t >= maxWrongVocab) break;
      final w = vocabByKey(key);
      if (w == null || !used.add(key)) continue;
      questions.add(vocabQuestion(w, '錯題'));
      t++;
    }
    t = 0;
    for (final key in sentenceWrong.keys.toList()..shuffle(random)) {
      if (t >= maxWrongSentence) break;
      final s = sentenceByKey(key);
      if (s == null || !used.add(key)) continue;
      questions.add(sentenceQuestion(s, '錯題'));
      t++;
    }

    // 3. 新內容補滿：熟練度最低者優先，假名/單字交錯
    final freshKana = allKana.where((k) => !used.contains(k.kana)).toList()
      ..shuffle(random)
      ..sort((a, b) => (mastery[a.kana] ?? 0).compareTo(mastery[b.kana] ?? 0));
    final freshVocab = vocabAll.where((w) => !used.contains(w.key)).toList()
      ..shuffle(random)
      ..sort((a, b) => (mastery[a.key] ?? 0).compareTo(mastery[b.key] ?? 0));
    var ki = 0, vi = 0, turn = 0;
    while (questions.length < targetSize &&
        (ki < freshKana.length || vi < freshVocab.length)) {
      final useKana = turn.isEven ? ki < freshKana.length : vi >= freshVocab.length;
      if (useKana) {
        final k = freshKana[ki++];
        if (used.add(k.kana)) questions.add(kanaQuestion(k, '新內容'));
      } else {
        final w = freshVocab[vi++];
        if (used.add(w.key)) questions.add(vocabQuestion(w, '新內容'));
      }
      turn++;
    }

    return questions;
  }
}
