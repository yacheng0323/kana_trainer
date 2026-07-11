import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'claude_client.dart';

/// 對話一回合（AI 側）。
class ChatReply {
  final String reply; // AI 角色的日文回覆
  final String translation; // 繁中翻譯
  final String correction; // 對使用者上一句的糾正建議（空字串 = 沒問題）

  const ChatReply({
    required this.reply,
    required this.translation,
    required this.correction,
  });
}

/// 情境角色扮演對話（Claude 扮演店員/地勤等，使用者練習 N5 日語）。
class AiChatService {
  final ClaudeClient _client;

  AiChatService({http.Client? client})
      : _client = ClaudeClient(httpClient: client);

  static const _schema = {
    'type': 'object',
    'properties': {
      'reply': {'type': 'string'},
      'translation': {'type': 'string'},
      'correction': {'type': 'string'},
    },
    'required': ['reply', 'translation', 'correction'],
    'additionalProperties': false,
  };

  /// [history]：交錯的 user/assistant 純文字（assistant 為上輪 reply 日文）。
  Future<ChatReply> send({
    required String apiKey,
    required String scenario,
    required List<({bool isUser, String text})> history,
  }) async {
    final messages = [
      for (final turn in history)
        {
          'role': turn.isUser ? 'user' : 'assistant',
          'content': turn.text,
        },
    ];

    final payload = await _client.completeJson(
      apiKey: apiKey,
      system: '你是日語會話練習夥伴，情境：$scenario。'
          '你扮演該情境的服務人員，使用者是顧客/旅客（日語初學者 N5）。'
          '規則：reply 用簡短自然的 N5 日語（1-2 句，全用 N5 詞彙與文法，漢字可用）；'
          'translation 是 reply 的繁體中文翻譯；'
          'correction 檢查使用者上一句日語——有錯就用繁中溫和說明正確說法，'
          '沒問題或使用者用中文則給空字串。對話持續進行，適時推進情境。',
      messages: messages,
      schema: _schema,
      maxTokens: 1024,
    );

    return ChatReply(
      reply: payload['reply'] as String? ?? '',
      translation: payload['translation'] as String? ?? '',
      correction: payload['correction'] as String? ?? '',
    );
  }
}

final aiChatServiceProvider = Provider<AiChatService>((ref) => AiChatService());
