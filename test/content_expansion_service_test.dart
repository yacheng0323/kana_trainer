import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/ai/content_expansion_service.dart';
import 'package:kana_trainer/data/static/grammar_data.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/repositories/ai_client.dart';

class FakeAiClient implements AiClient {
  final Map<String, dynamic> payload;
  String? lastSystem;
  List<Map<String, dynamic>>? lastMessages;

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
    lastMessages = messages;
    return payload;
  }
}

class _ThrowingAiClient implements AiClient {
  @override
  Future<Map<String, dynamic>> completeJson({
    required String apiKey,
    required String system,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> schema,
    int maxTokens = 4096,
  }) async {
    throw const AiException('網路連線失敗');
  }
}

void main() {
  group('generateVocab', () {
    test('合法批次全收、topic 固定為請求主題、避開清單有進 prompt', () async {
      final fake = FakeAiClient({
        'items': [
          {'jp': '搭乗券', 'reading': 'とうじょうけん', 'zh': '登機證'},
          {'jp': '荷物', 'reading': 'にもつ', 'zh': '行李'},
        ],
      });
      final service = ContentExpansionService(aiClient: fake);
      final words = await service.generateVocab(
        apiKey: 'sk',
        topic: VocabTopic.travel,
        existingJp: {'駅', '切符'},
      );
      expect(words.length, 2);
      expect(words.every((w) => w.topic == VocabTopic.travel), isTrue);
      final userMsg = fake.lastMessages!.first['content'] as String;
      expect(userMsg, contains('駅'));
      expect(userMsg, contains('切符'));
    });

    test('壞筆丟棄、重複（清單內/批內）丟棄，好筆保留', () async {
      final fake = FakeAiClient({
        'items': [
          {'jp': '駅', 'reading': 'えき', 'zh': '車站'}, // 已存在
          {'jp': '荷物', 'reading': 'にもつ', 'zh': '行李'},
          {'jp': '荷物', 'reading': 'にもつ', 'zh': '行李'}, // 批內重複
          {'jp': '', 'reading': 'x', 'zh': 'x'}, // 壞
        ],
      });
      final service = ContentExpansionService(aiClient: fake);
      final words = await service.generateVocab(
          apiKey: 'sk', topic: VocabTopic.travel, existingJp: {'駅'});
      expect(words.single.jp, '荷物');
    });
  });

  group('generateSentences', () {
    test('chunks 驗證：blankIndex 超界的丟棄', () async {
      final fake = FakeAiClient({
        'items': [
          {
            'chunks': ['お水', 'を', 'ください'],
            'blankIndex': 2,
            'zh': '請給我水'
          },
          {
            'chunks': ['壞'],
            'blankIndex': 9,
            'zh': 'x'
          },
        ],
      });
      final service = ContentExpansionService(aiClient: fake);
      final items = await service.generateSentences(
          apiKey: 'sk', scene: Scene.restaurant, existingJp: {});
      expect(items.single.jp, 'お水をください');
      expect(items.single.scene, Scene.restaurant);
    });
  });

  group('generateGrammarQuiz', () {
    test('綁 lessonId、同課題面重複丟棄', () async {
      final g = allGrammar.first;
      final existing = g.quiz.first.question;
      final fake = FakeAiClient({
        'items': [
          {
            'question': existing, // 與靜態重複
            'options': ['は', 'が', 'を', 'に'],
            'correctIndex': 0
          },
          {
            'question': '彼＿＿先生です。',
            'options': ['は', 'を', 'に', 'で'],
            'correctIndex': 0
          },
        ],
      });
      final service = ContentExpansionService(aiClient: fake);
      final items = await service.generateGrammarQuiz(
        apiKey: 'sk',
        point: g,
        existingQuestions: {existing},
      );
      expect(items.single.lessonId, g.id);
      expect(items.single.quiz.question, '彼＿＿先生です。');
    });
  });

  test('AiException 原樣往上丟', () async {
    final service = ContentExpansionService(aiClient: _ThrowingAiClient());
    expect(
      () => service.generateVocab(
          apiKey: 'sk', topic: VocabTopic.daily, existingJp: {}),
      throwsA(isA<AiException>()),
    );
  });
}
