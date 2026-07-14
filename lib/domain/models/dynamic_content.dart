import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';

/// AI 生成內容的 JSON codec。fromJson 一律「壞資料回 null」——
/// AI 回傳不可信，單筆壞掉丟棄即可，不炸整批。

Map<String, dynamic> vocabWordToJson(VocabWord w) => {
      'jp': w.jp,
      'reading': w.reading,
      'zh': w.zh,
      'topic': w.topic.name,
    };

VocabWord? vocabWordFromJson(Map<String, dynamic> json) {
  final jp = json['jp'], reading = json['reading'], zh = json['zh'];
  final topic = VocabTopic.values.asNameMap()[json['topic']];
  if (jp is! String || jp.isEmpty) return null;
  if (reading is! String || reading.isEmpty) return null;
  if (zh is! String || zh.isEmpty) return null;
  if (topic == null) return null;
  return VocabWord(jp: jp, reading: reading, zh: zh, topic: topic);
}

Map<String, dynamic> sentenceToJson(Sentence s) => {
      'chunks': s.chunks,
      'blankIndex': s.blankIndex,
      'zh': s.zh,
      'scene': s.scene.name,
    };

Sentence? sentenceFromJson(Map<String, dynamic> json) {
  final rawChunks = json['chunks'], blankIndex = json['blankIndex'];
  final zh = json['zh'];
  final scene = Scene.values.asNameMap()[json['scene']];
  if (rawChunks is! List || rawChunks.isEmpty) return null;
  final chunks = rawChunks.whereType<String>().toList();
  if (chunks.length != rawChunks.length || chunks.any((c) => c.isEmpty)) {
    return null;
  }
  if (blankIndex is! int || blankIndex < 0 || blankIndex >= chunks.length) {
    return null;
  }
  if (zh is! String || zh.isEmpty) return null;
  if (scene == null) return null;
  return Sentence(chunks: chunks, blankIndex: blankIndex, zh: zh, scene: scene);
}

/// 動態文法測驗題：綁定既有文法課（lessonId = GrammarPoint.id）。
class DynamicGrammarQuiz {
  final String lessonId;
  final GrammarQuiz quiz;

  const DynamicGrammarQuiz({required this.lessonId, required this.quiz});

  /// 去重 key：同課同題面視為重複。
  String get key => '$lessonId|${quiz.question}';
}

Map<String, dynamic> dynamicGrammarQuizToJson(DynamicGrammarQuiz q) => {
      'lessonId': q.lessonId,
      'question': q.quiz.question,
      'options': q.quiz.options,
      'correctIndex': q.quiz.correctIndex,
    };

DynamicGrammarQuiz? dynamicGrammarQuizFromJson(Map<String, dynamic> json) {
  final lessonId = json['lessonId'], question = json['question'];
  final rawOptions = json['options'], correctIndex = json['correctIndex'];
  if (lessonId is! String || lessonId.isEmpty) return null;
  if (question is! String || question.isEmpty) return null;
  if (rawOptions is! List) return null;
  final options = rawOptions.whereType<String>().toList();
  if (options.length != 4 || options.toSet().length != 4) return null;
  if (options.any((o) => o.isEmpty)) return null;
  if (correctIndex is! int || correctIndex < 0 || correctIndex > 3) return null;
  return DynamicGrammarQuiz(
    lessonId: lessonId,
    quiz: GrammarQuiz(
        question: question, options: options, correctIndex: correctIndex),
  );
}
