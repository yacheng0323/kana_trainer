import 'dart:convert';

import 'package:http/http.dart' as http;

/// AI 功能共用錯誤（UI 直接顯示 message）。
class AiException implements Exception {
  final String message;

  const AiException(this.message);

  @override
  String toString() => message;
}

/// Claude API 共用 client（raw HTTP — Dart 無官方 SDK）。
/// 一律用 structured outputs（json_schema）保證回傳合法 JSON。
class ClaudeClient {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const model = 'claude-opus-4-8';

  final http.Client _http;

  ClaudeClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  /// 呼叫 messages API，回傳解析後的 JSON payload（content[0].text）。
  Future<Map<String, dynamic>> completeJson({
    required String apiKey,
    required String system,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> schema,
    int maxTokens = 4096,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const AiException('尚未設定 API Key，請到「設定與備份」貼上');
    }

    final body = jsonEncode({
      'model': model,
      'max_tokens': maxTokens,
      'system': system,
      'output_config': {
        'format': {'type': 'json_schema', 'schema': schema},
      },
      'messages': messages,
    });

    final http.Response response;
    try {
      response = await _http
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
    } catch (_) {
      throw const AiException('網路連線失敗，請檢查網路後再試');
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 401:
        throw const AiException('API Key 無效，請確認後重新設定');
      case 429:
        throw const AiException('請求太頻繁，請稍後再試');
      case >= 500:
        throw const AiException('AI 服務暫時無法使用，請稍後再試');
      default:
        throw AiException('AI 請求失敗（HTTP ${response.statusCode}）');
    }

    try {
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final content = decoded['content'] as List;
      final text = (content.firstWhere(
        (b) => b['type'] == 'text',
      ) as Map<String, dynamic>)['text'] as String;
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw const AiException('AI 回傳格式異常，請再試一次');
    }
  }
}
