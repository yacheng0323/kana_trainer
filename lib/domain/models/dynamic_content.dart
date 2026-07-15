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
      'jlpt': w.jlpt,
    };

VocabWord? vocabWordFromJson(Map<String, dynamic> json) {
  final jp = json['jp'], reading = json['reading'], zh = json['zh'];
  final topic = VocabTopic.values.asNameMap()[json['topic']];
  if (jp is! String || jp.isEmpty) return null;
  if (reading is! String || reading.isEmpty) return null;
  if (zh is! String || zh.isEmpty) return null;
  if (topic == null) return null;
  final jlpt = (json['jlpt'] as int? ?? 5).clamp(1, 5); // 舊資料缺 → N5
  return VocabWord(
      jp: jp, reading: reading, zh: zh, topic: topic, jlpt: jlpt);
}

Map<String, dynamic> sentenceToJson(Sentence s) => {
      'chunks': s.chunks,
      'blankIndex': s.blankIndex,
      'zh': s.zh,
      'scene': s.scene.name,
      'jlpt': s.jlpt,
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
  final jlpt = (json['jlpt'] as int? ?? 5).clamp(1, 5); // 舊資料缺 → N5
  return Sentence(
      chunks: chunks, blankIndex: blankIndex, zh: zh, scene: scene, jlpt: jlpt);
}

/// 動態文法測驗題：綁定既有文法課（lessonId = GrammarPoint.id）。
class DynamicGrammarQuiz {
  final String lessonId;
  final GrammarQuiz quiz;

  const DynamicGrammarQuiz({required this.lessonId, required this.quiz});

  /// 去重 key：同課同題面視為重複。
  String get key => '$lessonId|${quiz.question}';
}

/// AI 生成的文法「課程」（N4~N1：教學卡+例句+3 題，未人審，可刪+黑名單）。
class DynamicGrammarLesson {
  final String id; // gdyn_n{level}_{title}，全域唯一（黑名單 key）
  final int level; // 4..1
  final String title;
  final String explanation;
  final List<GrammarExample> examples;
  final List<GrammarQuiz> quiz; // 恰 3 題

  const DynamicGrammarLesson({
    required this.id,
    required this.level,
    required this.title,
    required this.explanation,
    required this.examples,
    required this.quiz,
  });

  /// 直接餵既有 GrammarLessonPage（零 UI 重工）。
  GrammarPoint toGrammarPoint() => GrammarPoint(
        id: id,
        title: title,
        explanation: explanation,
        examples: examples,
        quiz: quiz,
      );
}

Map<String, dynamic> dynamicGrammarLessonToJson(DynamicGrammarLesson l) => {
      'id': l.id,
      'level': l.level,
      'title': l.title,
      'explanation': l.explanation,
      'examples': [
        for (final e in l.examples) {'jp': e.jp, 'zh': e.zh},
      ],
      'quiz': [
        for (final q in l.quiz)
          {
            'question': q.question,
            'options': q.options,
            'correctIndex': q.correctIndex,
          },
      ],
    };

DynamicGrammarLesson? dynamicGrammarLessonFromJson(Map<String, dynamic> json) {
  final id = json['id'], level = json['level'];
  final title = json['title'], explanation = json['explanation'];
  final rawExamples = json['examples'], rawQuiz = json['quiz'];
  if (id is! String || id.isEmpty) return null;
  if (level is! int || level < 1 || level > 4) return null;
  if (title is! String || title.isEmpty) return null;
  if (explanation is! String || explanation.isEmpty) return null;
  if (rawExamples is! List || rawQuiz is! List) return null;

  final examples = <GrammarExample>[];
  for (final raw in rawExamples.whereType<Map<String, dynamic>>()) {
    final jp = raw['jp'], zh = raw['zh'];
    if (jp is! String || jp.isEmpty || zh is! String || zh.isEmpty) continue;
    examples.add(GrammarExample(jp, zh));
  }
  if (examples.length < 2) return null;

  final quiz = <GrammarQuiz>[];
  for (final raw in rawQuiz.whereType<Map<String, dynamic>>()) {
    final q = dynamicGrammarQuizFromJson({...raw, 'lessonId': id});
    if (q == null || !q.quiz.question.contains('＿＿')) continue;
    quiz.add(q.quiz);
  }
  if (quiz.length != 3) return null;

  return DynamicGrammarLesson(
    id: id,
    level: level,
    title: title,
    explanation: explanation,
    examples: examples,
    quiz: quiz,
  );
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
