import 'package:kana_trainer/domain/entities/vocab.dart';

class ListeningFeedback {
  final bool correct;
  final int chosenIndex;

  const ListeningFeedback({required this.correct, required this.chosenIndex});
}

/// 聽力測驗狀態：播放單字發音，從 4 個日文選項選出聽到的字。
class ListeningState {
  final VocabWord current;
  final List<String> options; // 日文字
  final int correctIndex;
  final ListeningFeedback? feedback;
  final int streak;
  final int sessionTotal;
  final int sessionCorrect;

  const ListeningState({
    required this.current,
    required this.options,
    required this.correctIndex,
    this.feedback,
    this.streak = 0,
    this.sessionTotal = 0,
    this.sessionCorrect = 0,
  });
}
