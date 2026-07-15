import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/models/dynamic_content.dart';

void main() {
  group('vocab codec', () {
    test('round-trip', () {
      const w = VocabWord(
          jp: '切符', reading: 'きっぷ', zh: '車票', topic: VocabTopic.transport);
      final restored = vocabWordFromJson(vocabWordToJson(w));
      expect(restored!.jp, '切符');
      expect(restored.reading, 'きっぷ');
      expect(restored.zh, '車票');
      expect(restored.topic, VocabTopic.transport);
      expect(restored.key, 'v_切符');
    });

    test('jlpt round-trip、舊資料缺 jlpt → 5', () {
      const w = VocabWord(
          jp: '敬語', reading: 'けいご', zh: '敬語', topic: VocabTopic.work, jlpt: 3);
      expect(vocabWordFromJson(vocabWordToJson(w))!.jlpt, 3);
      // 舊格式（無 jlpt）
      expect(
          vocabWordFromJson(
              {'jp': 'x', 'reading': 'x', 'zh': 'x', 'topic': 'travel'})!.jlpt,
          5);
    });

    test('壞資料回 null（未知 topic、缺欄位、空字串）', () {
      expect(
          vocabWordFromJson(
              {'jp': 'x', 'reading': 'x', 'zh': 'x', 'topic': 'nope'}),
          isNull);
      expect(vocabWordFromJson({'jp': 'x'}), isNull);
      expect(
          vocabWordFromJson(
              {'jp': '', 'reading': 'x', 'zh': 'x', 'topic': 'travel'}),
          isNull);
    });
  });

  group('sentence codec', () {
    test('round-trip', () {
      const s = Sentence(
          chunks: ['駅は', 'どこ', 'ですか'],
          blankIndex: 1,
          zh: '車站在哪裡？',
          scene: Scene.train);
      final restored = sentenceFromJson(sentenceToJson(s));
      expect(restored!.jp, '駅はどこですか');
      expect(restored.blankIndex, 1);
      expect(restored.scene, Scene.train);
      expect(restored.key, 's_駅はどこですか');
    });

    test('句子 jlpt round-trip、舊資料缺 → 5', () {
      const s = Sentence(
          chunks: ['會議', 'に', '出ます'],
          blankIndex: 1,
          zh: '參加會議',
          scene: Scene.hotel,
          jlpt: 4);
      expect(sentenceFromJson(sentenceToJson(s))!.jlpt, 4);
      expect(
          sentenceFromJson({
            'chunks': ['a', 'b'],
            'blankIndex': 0,
            'zh': 'x',
            'scene': 'train'
          })!
              .jlpt,
          5);
    });

    test('壞資料回 null（blankIndex 超界、chunks 空）', () {
      expect(
          sentenceFromJson({
            'chunks': ['a'],
            'blankIndex': 5,
            'zh': 'x',
            'scene': 'train'
          }),
          isNull);
      expect(
          sentenceFromJson(
              {'chunks': [], 'blankIndex': 0, 'zh': 'x', 'scene': 'train'}),
          isNull);
    });
  });

  group('DynamicGrammarQuiz codec', () {
    test('round-trip + key', () {
      const q = DynamicGrammarQuiz(
        lessonId: 'g03',
        quiz: GrammarQuiz(
            question: '私＿＿学生です。',
            options: ['は', 'を', 'に', 'で'],
            correctIndex: 0),
      );
      final restored = dynamicGrammarQuizFromJson(dynamicGrammarQuizToJson(q));
      expect(restored!.lessonId, 'g03');
      expect(restored.quiz.options.length, 4);
      expect(restored.key, 'g03|私＿＿学生です。');
    });

    test('壞資料回 null（選項數≠4、重複、index 超界）', () {
      Map<String, dynamic> j(List<String> opts, int idx) => {
            'lessonId': 'g01',
            'question': 'q',
            'options': opts,
            'correctIndex': idx,
          };
      expect(dynamicGrammarQuizFromJson(j(['a', 'b', 'c'], 0)), isNull);
      expect(dynamicGrammarQuizFromJson(j(['a', 'a', 'b', 'c'], 0)), isNull);
      expect(dynamicGrammarQuizFromJson(j(['a', 'b', 'c', 'd'], 4)), isNull);
    });
  });
}
