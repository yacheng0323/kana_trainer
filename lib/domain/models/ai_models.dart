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

/// AI 弱點分析結果。
class WeaknessReport {
  final String summary;
  final List<String> weakPoints;
  final List<String> suggestions;

  const WeaknessReport({
    required this.summary,
    required this.weakPoints,
    required this.suggestions,
  });

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'weakPoints': weakPoints,
        'suggestions': suggestions,
      };

  factory WeaknessReport.fromJson(Map<String, dynamic> json) =>
      WeaknessReport(
        summary: json['summary'] as String? ?? '',
        weakPoints: (json['weakPoints'] as List? ?? []).cast<String>(),
        suggestions: (json['suggestions'] as List? ?? []).cast<String>(),
      );
}
