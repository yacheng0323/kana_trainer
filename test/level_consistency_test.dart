import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/ai/ai_chat_service.dart';
import 'package:kana_trainer/data/ai/ai_quiz_service.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/logic/exam_readiness.dart';
import 'package:kana_trainer/domain/repositories/ai_client.dart';
import 'package:kana_trainer/features/exam/exam_view_model.dart';
import 'package:kana_trainer/features/today/daily_menu_builder.dart';

class FakeAiClient implements AiClient {
  final Map<String, dynamic> payload;
  String? lastSystem;

  FakeAiClient(this.payload);

  @override
  Future<Map<String, dynamic>> completeJson({
    required String apiKey,
    required String system,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> schema,
    int maxTokens = 4096,
  }) async {
    lastSystem = system;
    return payload;
  }
}

List<VocabWord> n4Vocab(int n) => [
      for (var i = 1; i <= n; i++)
        VocabWord(
            jp: '語彙$i',
            reading: 'ごい$i',
            zh: '詞彙$i',
            topic: VocabTopic.work,
            jlpt: 4),
    ];

List<GrammarQuiz> n4Grammar(int n) => [
      for (var i = 1; i <= n; i++)
        GrammarQuiz(
            question: '第$i題＿＿です。',
            options: ['あ$i', 'い$i', 'う$i', 'え$i'],
            correctIndex: 0),
    ];

void main() {
  group('ExamReadiness', () {
    test('N5 恆 ready', () {
      expect(
          ExamReadiness.check(level: 5, vocabCount: 0, grammarCount: 0).ready,
          isTrue);
    });

    test('N4 不足 → 缺口正確', () {
      final r =
          ExamReadiness.check(level: 4, vocabCount: 12, grammarCount: 2);
      expect(r.ready, isFalse);
      expect(r.vocabGap, 8);
      expect(r.grammarGap, 3);
    });

    test('N4 足夠 → ready', () {
      expect(
          ExamReadiness.check(level: 4, vocabCount: 20, grammarCount: 5).ready,
          isTrue);
    });
  });

  group('buildQuestions 等級化', () {
    test('level 4：配比 10/5/5、單字全來自等級池、選項合法', () {
      final pool = n4Vocab(25);
      final poolJp = pool.map((w) => w.jp).toSet();
      final qs = ExamViewModel.buildQuestions(
        Random(1),
        level: 4,
        vocabPool: pool,
        grammarPool: n4Grammar(8),
      );
      expect(qs.length, 20);
      final vocabQs = qs.where((q) => q.sub!.startsWith('單字')).toList();
      expect(vocabQs.length, 10);
      expect(qs.where((q) => q.sub!.startsWith('假名')).length, 5);
      expect(qs.where((q) => q.sub!.startsWith('文法')).length, 5);
      for (final q in vocabQs) {
        expect(poolJp.contains(q.prompt), isTrue,
            reason: '${q.prompt} 不在 N4 池');
      }
      for (final q in qs) {
        expect(q.options.length, 4);
        expect(q.options.toSet().length, 4);
        expect(q.correctIndex, inInclusiveRange(0, 3));
      }
    });

    test('不帶參數 → N5 靜態路徑（回歸）', () {
      final qs = ExamViewModel.buildQuestions(Random(2));
      expect(qs.length, 20);
    });
  });

  group('ExamRecord level', () {
    test('round-trip + 舊 JSON 缺 level → 5', () {
      const r = ExamRecord(
          dateIso: '2026-07-16', score: 15, total: 20, durationSec: 300, level: 3);
      expect(ExamRecord.fromJson(r.toJson()).level, 3);
      expect(
          ExamRecord.fromJson(
                  {'dateIso': 'x', 'score': 1, 'total': 20, 'durationSec': 1})
              .level,
          5);
    });
  });

  group('AI 服務等級化', () {
    test('AiQuizService prompt 帶 N3', () async {
      final fake = FakeAiClient({
        'questions': [
          {
            'question': 'q',
            'options': ['a', 'b', 'c', 'd'],
            'correctIndex': 0,
            'note': 'n'
          },
        ],
      });
      await AiQuizService(aiClient: fake)
          .generate(apiKey: 'sk', topic: '職場', level: 3);
      expect(fake.lastSystem, contains('N3'));
    });

    test('AiChatService prompt 帶 N2 且指示敬語', () async {
      final fake = FakeAiClient(
          {'reply': 'r', 'translation': 't', 'correction': ''});
      await AiChatService(aiClient: fake).send(
        apiKey: 'sk',
        scenario: '飯店',
        level: 2,
        history: [(isUser: true, text: 'こんにちは')],
      );
      expect(fake.lastSystem, contains('N2'));
      expect(fake.lastSystem, contains('敬語'));
    });
  });

  group('DailyMenu lookupPool', () {
    test('fresh 來自等級池、跨等級錯題仍查得到字面', () {
      final n4pool = n4Vocab(20);
      final full = [...n4pool];
      // 錯題 key 屬於「另一等級」的字（不在 vocabPool、只在 lookupPool）
      const other = VocabWord(
          jp: '駅前', reading: 'えきまえ', zh: '車站前', topic: VocabTopic.travel);
      full.add(other);

      final questions = DailyMenuBuilder.build(
        mastery: {},
        dueVocabKeys: {},
        kanaWrong: {},
        vocabWrong: {other.key: 2},
        sentenceWrong: {},
        vocabPool: n4pool,
        lookupPool: full,
        rng: Random(3),
      );
      // 錯題（跨等級）有進菜單
      expect(questions.any((q) => q.sourceKey == other.key), isTrue);
      // 新內容單字全來自 N4 池
      final freshVocab = questions
          .where((q) => q.kind == 'vocab' && q.note.startsWith('新內容'));
      final n4keys = n4pool.map((w) => w.key).toSet();
      for (final q in freshVocab) {
        expect(n4keys.contains(q.sourceKey), isTrue);
      }
    });
  });
}
