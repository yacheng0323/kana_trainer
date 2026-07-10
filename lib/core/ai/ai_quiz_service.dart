import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../storage/prefs_provider.dart';

/// AI 生成的 4 選 1 題目。
class AiQuestion {
  final String question; // 題面（可含 ＿＿ 挖空）
  final List<String> options;
  final int correctIndex;
  final String note; // 檢討說明

  const AiQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'note': note,
      };

  factory AiQuestion.fromJson(Map<String, dynamic> json) {
    final options = (json['options'] as List).cast<String>();
    final correctIndex = json['correctIndex'] as int;
    if (options.length != 4 ||
        options.toSet().length != 4 ||
        correctIndex < 0 ||
        correctIndex > 3) {
      throw const FormatException('AI 題目格式不合法');
    }
    return AiQuestion(
      question: json['question'] as String,
      options: options,
      correctIndex: correctIndex,
      note: json['note'] as String? ?? '',
    );
  }
}

/// AI 出題失敗原因（給 UI 顯示中文訊息）。
class AiQuizException implements Exception {
  final String message;

  const AiQuizException(this.message);

  @override
  String toString() => message;
}

/// Claude API 出題服務（raw HTTP — Dart 無官方 SDK）。
/// structured outputs（output_config.format）保證回傳合法 JSON。
class AiQuizService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-opus-4-8';

  final http.Client _client;

  AiQuizService({http.Client? client}) : _client = client ?? http.Client();

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
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const AiQuizException('尚未設定 API Key，請到「設定與備份」貼上');
    }

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 4096,
      'system': '你是專業日語教師，為繁體中文使用者出 JLPT N5 程度的日語測驗題。'
          '題型混合：單字意思（日→中）、克漏字（句中以＿＿挖空選詞）、假名讀音。'
          '規則：每題恰好 4 個不重複選項；干擾項要合理但明確錯誤；'
          'note 用繁體中文簡短說明正解（含讀音）；難度維持 N5，不出偏僻詞。',
      'output_config': {
        'format': {'type': 'json_schema', 'schema': _schema},
      },
      'messages': [
        {
          'role': 'user',
          'content': '主題「$topic」，出 $count 題，題目彼此不重複。',
        },
      ],
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey.trim(),
              'anthropic-version': '2023-06-01',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 90));
    } on AiQuizException {
      rethrow;
    } catch (_) {
      throw const AiQuizException('網路連線失敗，請檢查網路後再試');
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 401:
        throw const AiQuizException('API Key 無效，請確認後重新設定');
      case 429:
        throw const AiQuizException('請求太頻繁，請稍後再試');
      case >= 500:
        throw const AiQuizException('AI 服務暫時無法使用，請稍後再試');
      default:
        throw AiQuizException('出題失敗（HTTP ${response.statusCode}）');
    }

    try {
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = decoded['content'] as List;
      final text = (content.firstWhere(
        (b) => b['type'] == 'text',
      ) as Map<String, dynamic>)['text'] as String;
      final payload = jsonDecode(text) as Map<String, dynamic>;
      final questions = (payload['questions'] as List)
          .map((q) => AiQuestion.fromJson(q as Map<String, dynamic>))
          .toList();
      if (questions.isEmpty) {
        throw const FormatException('empty');
      }
      return questions;
    } on AiQuizException {
      rethrow;
    } catch (_) {
      throw const AiQuizException('AI 回傳格式異常，請再試一次');
    }
  }
}

final aiQuizServiceProvider = Provider<AiQuizService>((ref) => AiQuizService());

/// Claude API Key。獨立儲存（不在 settings JSON 內），
/// 因此**不會**被備份匯出（BackupService.backupKeys 未包含此 key）。
class ApiKeyNotifier extends Notifier<String> {
  static const storageKey = 'claude_api_key';

  @override
  String build() => ref.read(prefsProvider).getString(storageKey) ?? '';

  void set(String key) {
    state = key.trim();
    ref.read(prefsProvider).setString(storageKey, state);
  }
}

final apiKeyProvider =
    NotifierProvider<ApiKeyNotifier, String>(ApiKeyNotifier.new);
