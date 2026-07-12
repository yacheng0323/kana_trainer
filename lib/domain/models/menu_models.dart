/// 今日菜單的統一題目格式（假名/單字/句子混合，皆 4 選 1）。
class MenuQuestion {
  final String kind; // 'kana' | 'vocab' | 'sentence'
  final String sourceKey; // mastery / 錯題本 key
  final String prompt;
  final String? subtitle; // 輔助（單字讀音等）
  final List<String> options;
  final int correctIndex;
  final String note; // 答後說明

  const MenuQuestion({
    required this.kind,
    required this.sourceKey,
    required this.prompt,
    this.subtitle,
    required this.options,
    required this.correctIndex,
    required this.note,
  });
}

/// 今日菜單組成預覽（首頁卡片顯示用）。
class MenuPreview {
  final int due;
  final int wrong;
  final int fresh;

  const MenuPreview({required this.due, required this.wrong, required this.fresh});

  int get total => due + wrong + fresh;
}

/// 今日菜單完成紀錄：{date, score, total}。跨日自動視為未完成。
class MenuDone {
  final String date;
  final int score;
  final int total;

  const MenuDone({this.date = '', this.score = 0, this.total = 0});

  Map<String, dynamic> toJson() => {'date': date, 'score': score, 'total': total};

  factory MenuDone.fromJson(Map<String, dynamic> json) => MenuDone(
        date: json['date'] as String? ?? '',
        score: json['score'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
      );
}
