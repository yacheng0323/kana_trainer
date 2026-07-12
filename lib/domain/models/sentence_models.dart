import 'package:kana_trainer/domain/entities/sentence.dart';

class SentenceFeedback {
  final bool correct;
  final int? chosenIndex; // 克漏字

  const SentenceFeedback({required this.correct, this.chosenIndex});
}

/// 句子練習 session 狀態。
class SentencePracticeState {
  final Sentence current;
  final SentenceQuizType type;
  // 克漏字
  final List<String> options;
  final int correctIndex;
  // 重組
  final List<String> shuffled; // 打亂後的語塊池
  final List<int> picked; // 已點選的 shuffled 索引（依序）
  final SentenceFeedback? feedback;
  final int streak;
  final int sessionTotal;
  final int sessionCorrect;

  const SentencePracticeState({
    required this.current,
    required this.type,
    this.options = const [],
    this.correctIndex = 0,
    this.shuffled = const [],
    this.picked = const [],
    this.feedback,
    this.streak = 0,
    this.sessionTotal = 0,
    this.sessionCorrect = 0,
  });

  SentencePracticeState copyWith({
    List<int>? picked,
    SentenceFeedback? feedback,
    int? streak,
    int? sessionTotal,
    int? sessionCorrect,
  }) =>
      SentencePracticeState(
        current: current,
        type: type,
        options: options,
        correctIndex: correctIndex,
        shuffled: shuffled,
        picked: picked ?? this.picked,
        feedback: feedback ?? this.feedback,
        streak: streak ?? this.streak,
        sessionTotal: sessionTotal ?? this.sessionTotal,
        sessionCorrect: sessionCorrect ?? this.sessionCorrect,
      );
}
