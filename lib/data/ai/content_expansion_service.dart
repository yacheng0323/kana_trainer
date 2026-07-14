import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/ai/claude_client.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/models/dynamic_content.dart';

/// AI 題庫擴充：一次生成一批，本地驗證（AI 回傳不可信）+ 去重後回傳。
/// 整批全滅回空 list（呼叫端視為失敗批，仍計入每日批數避免壞回應重試迴圈）。
class ContentExpansionService {
  static const vocabBatch = 15;
  static const sentenceBatch = 8;
  static const grammarBatch = 5;

  final AiClient _client;

  ContentExpansionService({AiClient? aiClient})
      : _client = aiClient ?? ClaudeClient();

  static const _vocabSchema = {
    'type': 'object',
    'properties': {
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'jp': {'type': 'string'},
            'reading': {'type': 'string'},
            'zh': {'type': 'string'},
          },
          'required': ['jp', 'reading', 'zh'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['items'],
    'additionalProperties': false,
  };

  static const _sentenceSchema = {
    'type': 'object',
    'properties': {
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'chunks': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'blankIndex': {'type': 'integer'},
            'zh': {'type': 'string'},
          },
          'required': ['chunks', 'blankIndex', 'zh'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['items'],
    'additionalProperties': false,
  };

  static const _grammarSchema = {
    'type': 'object',
    'properties': {
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'question': {'type': 'string'},
            'options': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'correctIndex': {
              'type': 'integer',
              'enum': [0, 1, 2, 3]
            },
          },
          'required': ['question', 'options', 'correctIndex'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['items'],
    'additionalProperties': false,
  };

  Future<List<VocabWord>> generateVocab({
    required String apiKey,
    required VocabTopic topic,
    required Set<String> existingJp,
  }) async {
    final payload = await _client.completeJson(
      apiKey: apiKey,
      system: '你是專業日語教師，為繁體中文使用者挑選 JLPT N5 程度的日語單字。'
          '規則：jp 為顯示字（常用漢字或假名）、reading 為假名讀音、'
          'zh 為繁體中文意思（簡短）；全部必須是 N5 常用詞，不出偏僻詞。',
      messages: [
        {
          'role': 'user',
          'content': '主題「${topic.label}」，出 $vocabBatch 個新單字。'
              '絕對不要出這些已有的字：${existingJp.join('、')}',
        },
      ],
      schema: _vocabSchema,
    );
    final seen = {...existingJp};
    final out = <VocabWord>[];
    for (final raw in _items(payload)) {
      final w = vocabWordFromJson({...raw, 'topic': topic.name});
      if (w == null || seen.contains(w.jp)) continue;
      seen.add(w.jp);
      out.add(w);
    }
    return out;
  }

  Future<List<Sentence>> generateSentences({
    required String apiKey,
    required Scene scene,
    required Set<String> existingJp,
  }) async {
    final payload = await _client.completeJson(
      apiKey: apiKey,
      system: '你是專業日語教師，為繁體中文使用者編寫 JLPT N5 程度的日語情境句。'
          '規則：chunks 為正確語序的語塊（3~6 塊，供重組題用），'
          'blankIndex 為克漏字挖空的語塊索引（挑助詞或關鍵詞），'
          'zh 為繁體中文翻譯。句子必須自然、實用、N5 程度。',
      messages: [
        {
          'role': 'user',
          'content': '情境「${scene.label}」，出 $sentenceBatch 句新句子。'
              '絕對不要出這些已有的句子：${existingJp.join('／')}',
        },
      ],
      schema: _sentenceSchema,
    );
    final seen = {...existingJp};
    final out = <Sentence>[];
    for (final raw in _items(payload)) {
      final s = sentenceFromJson({...raw, 'scene': scene.name});
      if (s == null || seen.contains(s.jp)) continue;
      seen.add(s.jp);
      out.add(s);
    }
    return out;
  }

  Future<List<DynamicGrammarQuiz>> generateGrammarQuiz({
    required String apiKey,
    required GrammarPoint point,
    required Set<String> existingQuestions,
  }) async {
    final payload = await _client.completeJson(
      apiKey: apiKey,
      system: '你是專業日語教師，為繁體中文使用者出 JLPT N5 文法測驗題。'
          '規則：question 為含「＿＿」挖空的日文句子；options 恰 4 個不重複；'
          '干擾項合理但明確錯誤；緊扣指定文法點，不混入其他文法。',
      messages: [
        {
          'role': 'user',
          'content': '文法點「${point.title}」：${point.explanation}\n'
              '出 $grammarBatch 題新題目。絕對不要出這些已有的題面：'
              '${existingQuestions.join('／')}',
        },
      ],
      schema: _grammarSchema,
    );
    final seen = {...existingQuestions};
    final out = <DynamicGrammarQuiz>[];
    for (final raw in _items(payload)) {
      final q = dynamicGrammarQuizFromJson({...raw, 'lessonId': point.id});
      if (q == null || seen.contains(q.quiz.question)) continue;
      seen.add(q.quiz.question);
      out.add(q);
    }
    return out;
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> payload) {
    final raw = payload['items'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }
}

final contentExpansionServiceProvider =
    Provider<ContentExpansionService>((ref) => ContentExpansionService());
