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

class ExamState {
  final List<ExamQuestion> questions;
  final List<int?> answers; // 每題選了哪個（null = 未答）
  final int index; // 目前題號
  final bool submitted;
  final int score;
  final int durationSec;

  const ExamState({
    required this.questions,
    required this.answers,
    this.index = 0,
    this.submitted = false,
    this.score = 0,
    this.durationSec = 0,
  });

  int get answeredCount => answers.where((a) => a != null).length;

  ExamState copyWith({
    List<int?>? answers,
    int? index,
    bool? submitted,
    int? score,
    int? durationSec,
  }) =>
      ExamState(
        questions: questions,
        answers: answers ?? this.answers,
        index: index ?? this.index,
        submitted: submitted ?? this.submitted,
        score: score ?? this.score,
        durationSec: durationSec ?? this.durationSec,
      );
}
