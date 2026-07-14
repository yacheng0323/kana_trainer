import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/static/grammar_data.dart';
import 'package:kana_trainer/data/static/sentence_data.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/repositories/content_repository.dart';

export 'package:kana_trainer/domain/repositories/content_repository.dart';

/// 靜態種子 + DynamicContentStore 合併。store 端 add 已用靜態 key dedup，
/// 這裡再以「靜態優先」防禦一次（key 衝突時動態版本不出現）。
class MergedContentRepository implements ContentRepository {
  final DynamicContentStore _store;

  MergedContentRepository(this._store);

  @override
  List<VocabWord> vocab() {
    final staticKeys = allVocab.map((w) => w.key).toSet();
    return [
      ...allVocab,
      ..._store.vocab().where((w) => !staticKeys.contains(w.key)),
    ];
  }

  @override
  List<Sentence> sentences() {
    final staticKeys = allSentences.map((s) => s.key).toSet();
    return [
      ...allSentences,
      ..._store.sentences().where((s) => !staticKeys.contains(s.key)),
    ];
  }

  @override
  List<GrammarQuiz> grammarQuiz(String lessonId) {
    final point = allGrammar.where((g) => g.id == lessonId).firstOrNull;
    return [
      ...?point?.quiz,
      ..._store
          .grammarQuiz()
          .where((q) => q.lessonId == lessonId)
          .map((q) => q.quiz),
    ];
  }

  @override
  VocabWord? findVocab(String key) =>
      vocab().where((w) => w.key == key).firstOrNull;

  @override
  Sentence? findSentence(String key) =>
      sentences().where((s) => s.key == key).firstOrNull;
}

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => MergedContentRepository(ref.read(dynamicContentStoreProvider)),
);
