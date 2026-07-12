import 'package:kana_trainer/domain/entities/kana.dart';

/// 單題作答結果。
class AnswerFeedback {
  final bool correct;
  final String canonical;
  final List<String> accepted;
  final String input;
  final int? chosenIndex; // 選擇題模式：使用者點的選項

  const AnswerFeedback({
    required this.correct,
    required this.canonical,
    required this.accepted,
    required this.input,
    this.chosenIndex,
  });
}

/// 練習 session 狀態。
class PracticeState {
  final Kana current;
  final List<String> options; // 4 選 1 選項（romaji）
  final int correctIndex;
  final AnswerFeedback? feedback; // null = 等待作答
  final int streak;
  final int sessionTotal;
  final int sessionCorrect;

  const PracticeState({
    required this.current,
    required this.options,
    required this.correctIndex,
    this.feedback,
    this.streak = 0,
    this.sessionTotal = 0,
    this.sessionCorrect = 0,
  });

  double get accuracy => sessionTotal == 0 ? 0 : sessionCorrect / sessionTotal;

  PracticeState copyWith({
    Kana? current,
    List<String>? options,
    int? correctIndex,
    AnswerFeedback? feedback,
    bool clearFeedback = false,
    int? streak,
    int? sessionTotal,
    int? sessionCorrect,
  }) {
    return PracticeState(
      current: current ?? this.current,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      streak: streak ?? this.streak,
      sessionTotal: sessionTotal ?? this.sessionTotal,
      sessionCorrect: sessionCorrect ?? this.sessionCorrect,
    );
  }
}
