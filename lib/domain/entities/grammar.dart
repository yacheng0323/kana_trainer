/// 文法課（M4）。
class GrammarExample {
  final String jp;
  final String zh;

  const GrammarExample(this.jp, this.zh);
}

class GrammarQuiz {
  final String question; // 含 ＿＿ 挖空
  final List<String> options; // 4 選 1
  final int correctIndex;

  const GrammarQuiz({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

class GrammarPoint {
  final String id; // 唯一，如 g01
  final String title; // 文法點名稱
  final String explanation; // 說明（2-4 行）
  final List<GrammarExample> examples;
  final List<GrammarQuiz> quiz; // 3 題

  const GrammarPoint({
    required this.id,
    required this.title,
    required this.explanation,
    required this.examples,
    required this.quiz,
  });
}
