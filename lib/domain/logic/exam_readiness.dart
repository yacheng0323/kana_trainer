/// N4~N1 模擬測驗可考性（純函式）。N5 靜態題庫恆 ready。
class ExamReadiness {
  final bool ready;
  final int vocabGap; // 還差幾個單字
  final int grammarGap; // 還差幾題文法

  const ExamReadiness._(this.ready, this.vocabGap, this.grammarGap);

  /// 單字池最低量（出 10 題 + 4 選項干擾需要的餘裕）。
  static const minVocab = 20;

  /// 文法題池最低量（出 5 題）。
  static const minGrammar = 5;

  static ExamReadiness check({
    required int level,
    required int vocabCount,
    required int grammarCount,
  }) {
    if (level == 5) return const ExamReadiness._(true, 0, 0);
    final vocabGap = (minVocab - vocabCount).clamp(0, minVocab);
    final grammarGap = (minGrammar - grammarCount).clamp(0, minGrammar);
    return ExamReadiness._(
        vocabGap == 0 && grammarGap == 0, vocabGap, grammarGap);
  }
}
