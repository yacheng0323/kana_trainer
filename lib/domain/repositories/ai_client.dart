/// AI 功能共用錯誤（UI 直接顯示 message）。
class AiException implements Exception {
  final String message;

  const AiException(this.message);

  @override
  String toString() => message;
}

/// LLM 後端抽象：丟 system + messages + JSON schema，回結構化 JSON。
/// 正式實作：ClaudeClient（data/ai/claude_client.dart）；
/// 測試可注入 fake 回固定 payload，不經網路。
abstract class AiClient {
  Future<Map<String, dynamic>> completeJson({
    required String apiKey,
    required String system,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> schema,
    int maxTokens,
  });
}
