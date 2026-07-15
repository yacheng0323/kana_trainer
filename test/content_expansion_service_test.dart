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

  group('等級化', () {
    test('generateVocab level 4：prompt 帶 N4、產出 jlpt=4', () async {
      final fake = FakeAiClient({
        'items': [
          {'jp': '会議', 'reading': 'かいぎ', 'zh': '會議'},
        ],
      });
      final service = ContentExpansionService(aiClient: fake);
      final words = await service.generateVocab(
          apiKey: 'sk', topic: VocabTopic.work, existingJp: {}, level: 4);
      expect(fake.lastSystem, contains('N4'));
      expect(words.single.jlpt, 4);
    });

    test('generateSentences level 3：產出 jlpt=3', () async {
      final fake = FakeAiClient({
        'items': [
          {
            'chunks': ['会議に', '出席', 'させて', 'いただきます'],
            'blankIndex': 2,
            'zh': '請容我出席會議'
          },
        ],
      });
      final service = ContentExpansionService(aiClient: fake);
      final items = await service.generateSentences(
          apiKey: 'sk', scene: Scene.hotel, existingJp: {}, level: 3);
      expect(fake.lastSystem, contains('N3'));
      expect(items.single.jlpt, 3);
    });
  });

  group('generateGrammarLesson', () {
    final goodPayload = {
      'title': '受身形',
      'explanation': '動詞被動態。',
      'examples': [
        {'jp': '先生に褒められました。', 'zh': '被老師稱讚了。'},
        {'jp': '雨に降られました。', 'zh': '被雨淋了。'},
        {'jp': '犬に噛まれました。', 'zh': '被狗咬了。'},
      ],
      'quiz': [
        {
          'question': '先生に＿＿ました。',
          'options': ['褒められ', '褒め', '褒めて', '褒めよう'],
          'correctIndex': 0
        },
        {
          'question': '犬に＿＿ました。',
          'options': ['噛まれ', '噛み', '噛んで', '噛もう'],
          'correctIndex': 0
        },
        {
          'question': '友達に＿＿ました。',
          'options': ['笑われ', '笑い', '笑って', '笑おう'],
          'correctIndex': 0
        },
      ],
    };

    test('合格課：id/level 正確、prompt 帶避開清單', () async {
      final fake = FakeAiClient(goodPayload);
      final service = ContentExpansionService(aiClient: fake);
      final lesson = await service.generateGrammarLesson(
          apiKey: 'sk', level: 4, existingTitles: {'使役形'});
      expect(lesson!.id, 'gdyn_n4_受身形');
      expect(lesson.level, 4);
      expect(lesson.quiz.length, 3);
      expect(fake.lastMessages!.first['content'], contains('使役形'));
      expect(fake.lastSystem, contains('N4'));
    });

    test('title 重複 → null', () async {
      final service = ContentExpansionService(aiClient: FakeAiClient(goodPayload));
      final lesson = await service.generateGrammarLesson(
          apiKey: 'sk', level: 4, existingTitles: {'受身形'});
      expect(lesson, isNull);
    });

    test('quiz 不合格（僅 2 題）→ null', () async {
      final bad = {
        ...goodPayload,
        'quiz': (goodPayload['quiz'] as List).sublist(0, 2),
      };
      final service = ContentExpansionService(aiClient: FakeAiClient(bad));
      final lesson = await service.generateGrammarLesson(
          apiKey: 'sk', level: 4, existingTitles: {});
      expect(lesson, isNull);
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
