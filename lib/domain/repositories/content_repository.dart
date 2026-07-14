import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';

/// 題庫內容的唯一取用介面：靜態種子 + 動態池合併。
/// ViewModel 一律走這裡，不直接 import data/static。
abstract class ContentRepository {
  List<VocabWord> vocab();
  List<Sentence> sentences();

  /// 該文法課的測驗題（靜態 3 題 + 該課動態題）。
  List<GrammarQuiz> grammarQuiz(String lessonId);

  VocabWord? findVocab(String key);
  Sentence? findSentence(String key);
}
