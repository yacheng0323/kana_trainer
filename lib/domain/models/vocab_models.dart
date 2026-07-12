import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/models/app_settings.dart';

/// 單字單題作答結果。
class VocabFeedback {
  final bool correct;
  final int? chosenIndex; // MC 題型
  final String? input; // 讀音輸入題型

  const VocabFeedback({required this.correct, this.chosenIndex, this.input});
}

/// 單字練習 session 狀態。
/// [options] 依題型：日→中 = 中文意思、中→日 = 日文字；讀音輸入 = 空。
class VocabPracticeState {
  final VocabWord current;
  final VocabMode mode;
  final List<String> options;
  final int correctIndex;
  final VocabFeedback? feedback;
  final int streak;
  final int sessionTotal;
  final int sessionCorrect;

  const VocabPracticeState({
    required this.current,
    required this.mode,
    required this.options,
    required this.correctIndex,
    this.feedback,
    this.streak = 0,
    this.sessionTotal = 0,
    this.sessionCorrect = 0,
  });
}
