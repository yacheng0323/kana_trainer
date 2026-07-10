/// 模擬測驗題（統一格式：假名/單字/文法混出）。
class ExamQuestion {
  final String prompt; // 題面
  final String? sub; // 輔助（如假名讀音提示欄位，不含答案）
  final List<String> options;
  final int correctIndex;
  final String answerNote; // 檢討用：完整答案說明

  const ExamQuestion({
    required this.prompt,
    this.sub,
    required this.options,
    required this.correctIndex,
    required this.answerNote,
  });
}

/// 一次測驗成績。
class ExamRecord {
  final String dateIso; // ISO8601
  final int score;
  final int total;
  final int durationSec;

  const ExamRecord({
    required this.dateIso,
    required this.score,
    required this.total,
    required this.durationSec,
  });

  double get percent => total == 0 ? 0 : score / total;

  Map<String, dynamic> toJson() => {
        'dateIso': dateIso,
        'score': score,
        'total': total,
        'durationSec': durationSec,
      };

  factory ExamRecord.fromJson(Map<String, dynamic> json) => ExamRecord(
        dateIso: json['dateIso'] as String? ?? '',
        score: json['score'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
        durationSec: json['durationSec'] as int? ?? 0,
      );
}
