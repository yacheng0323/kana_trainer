import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:kana_trainer/data/storage/secure_store.dart';
import 'claude_client.dart';
import 'package:kana_trainer/domain/models/ai_models.dart';
export 'package:kana_trainer/domain/models/ai_models.dart';

/// AI 出題失敗原因（給 UI 顯示中文訊息）。
class AiQuizException extends AiException {
  const AiQuizException(super.message);
}

/// Claude API 出題服務（共用 ClaudeClient，structured outputs 保證 JSON）。
class AiQuizService {
  final AiClient _client;

  AiQuizService({AiClient? aiClient, http.Client? client})
      : _client = aiClient ?? ClaudeClient(httpClient: client);

  static const _schema = {
    'type': 'object',
    'properties': {
      'questions': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'question': {'type': 'string'},
            'options': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'correctIndex': {'type': 'integer', 'enum': [0, 1, 2, 3]},
            'note': {'type': 'string'},
          },
          'required': ['question', 'options', 'correctIndex', 'note'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['questions'],
    'additionalProperties': false,
  };

  Future<List<AiQuestion>> generate({
    required String apiKey,
    required String topic,
    int count = 10,
    int level = 5,
  }) async {
    final Map<String, dynamic> payload;
    try {
      payload = await _client.completeJson(
        apiKey: apiKey,
        system: '你是專業日語教師，為繁體中文使用者出 JLPT N$level 程度的日語測驗題。'
            '題型混合：單字意思（日→中）、克漏字（句中以＿＿挖空選詞）、假名讀音。'
            '規則：每題恰好 4 個不重複選項；干擾項要合理但明確錯誤；'
            'note 用繁體中文簡短說明正解（含讀音）；難度精準落在 N$level。',
        messages: [
          {
            'role': 'user',
            'content': '主題「$topic」，出 $count 題，題目彼此不重複。',
          },
        ],
        schema: _schema,
      );
    } on AiQuizException {
      rethrow;
    } on AiException catch (e) {
      throw AiQuizException(e.message);
    }

    try {
      final questions = (payload['questions'] as List)
          .map((q) => AiQuestion.fromJson(q as Map<String, dynamic>))
          .toList();
      if (questions.isEmpty) {
        throw const FormatException('empty');
      }
      return questions;
    } catch (_) {
      throw const AiQuizException('AI 回傳格式異常，請再試一次');
    }
  }
}

final aiQuizServiceProvider = Provider<AiQuizService>((ref) => AiQuizService());

/// Claude API Key。存加密儲存（secureStoreProvider → Android Keystore），
/// 不落 SharedPreferences 明文，也**不會**被備份匯出
/// （BackupService.backupKeys 未包含此 key）。
class ApiKeyNotifier extends Notifier<String> {
  static const storageKey = 'claude_api_key';

  @override
  String build() => ref.read(secureStoreProvider).getString(storageKey) ?? '';

  void set(String key) {
    state = key.trim();
    ref.read(secureStoreProvider).setString(storageKey, state);
  }
}

final apiKeyProvider =
    NotifierProvider<ApiKeyNotifier, String>(ApiKeyNotifier.new);
