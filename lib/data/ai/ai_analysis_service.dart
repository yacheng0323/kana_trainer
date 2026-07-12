import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'claude_client.dart';
import 'package:kana_trainer/domain/models/ai_models.dart';
export 'package:kana_trainer/domain/models/ai_models.dart';

/// 把錯題本＋統計丟給 Claude 分析學習弱點。
class AiAnalysisService {
  final AiClient _client;

  AiAnalysisService({AiClient? aiClient, http.Client? client})
      : _client = aiClient ?? ClaudeClient(httpClient: client);

  static const _schema = {
    'type': 'object',
    'properties': {
      'summary': {'type': 'string'},
      'weakPoints': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'suggestions': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['summary', 'weakPoints', 'suggestions'],
    'additionalProperties': false,
  };

  Future<WeaknessReport> analyze({
    required String apiKey,
    required String learnerData, // 組好的學習狀況文字
  }) async {
    final payload = await _client.completeJson(
      apiKey: apiKey,
      system: '你是日語學習教練，分析一位繁體中文使用者的 N5 學習資料。'
          '用繁體中文輸出：summary 是 2-3 句的總評（先講做得好的再講弱點）；'
          'weakPoints 是 2-4 條具體弱點模式（例：拗音混淆、五段動詞て形、助詞に/で），'
          '要引用資料中的實例；suggestions 是 2-4 條可操作的練習建議'
          '（對應這個 App 的功能：假名練習、單字 SRS、動詞變化訓練、錯題複習等）。'
          '語氣鼓勵但直接。',
      messages: [
        {'role': 'user', 'content': learnerData},
      ],
      schema: _schema,
      maxTokens: 2048,
    );
    return WeaknessReport.fromJson(payload);
  }
}

final aiAnalysisServiceProvider =
    Provider<AiAnalysisService>((ref) => AiAnalysisService());
