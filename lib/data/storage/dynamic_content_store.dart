import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/models/dynamic_content.dart';

/// AI 生成內容的本地持久化池。建構時全量載入記憶體（量級：數百筆 JSON），
/// add 時 dedup（against 既有池 + 呼叫端傳入的靜態 key）後 write-through。
class DynamicContentStore {
  static const vocabKey = 'dyn_vocab';
  static const sentencesKey = 'dyn_sentences';
  static const grammarQuizKey = 'dyn_grammar_quiz';

  final KeyValueStore _kv;
  late final List<VocabWord> _vocab;
  late final List<Sentence> _sentences;
  late final List<DynamicGrammarQuiz> _grammar;

  DynamicContentStore(this._kv) {
    _vocab = _load(vocabKey, vocabWordFromJson);
    _sentences = _load(sentencesKey, sentenceFromJson);
    _grammar = _load(grammarQuizKey, dynamicGrammarQuizFromJson);
  }

  List<T> _load<T>(String key, T? Function(Map<String, dynamic>) decode) {
    final raw = _kv.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(decode)
          .whereType<T>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<VocabWord> vocab() => List.unmodifiable(_vocab);
  List<Sentence> sentences() => List.unmodifiable(_sentences);
  List<DynamicGrammarQuiz> grammarQuiz() => List.unmodifiable(_grammar);

  Future<int> addVocab(List<VocabWord> items,
      {required Set<String> existingKeys}) {
    return _add(
        items, _vocab, (w) => w.key, existingKeys, vocabKey, vocabWordToJson);
  }

  Future<int> addSentences(List<Sentence> items,
      {required Set<String> existingKeys}) {
    return _add(items, _sentences, (s) => s.key, existingKeys, sentencesKey,
        sentenceToJson);
  }

  Future<int> addGrammarQuiz(List<DynamicGrammarQuiz> items,
      {required Set<String> existingKeys}) {
    return _add(items, _grammar, (q) => q.key, existingKeys, grammarQuizKey,
        dynamicGrammarQuizToJson);
  }

  Future<int> _add<T>(
    List<T> items,
    List<T> pool,
    String Function(T) keyOf,
    Set<String> existingKeys,
    String storageKey,
    Map<String, dynamic> Function(T) encode,
  ) async {
    final seen = {...existingKeys, ...pool.map(keyOf)};
    var added = 0;
    for (final item in items) {
      final k = keyOf(item);
      if (seen.contains(k)) continue;
      seen.add(k);
      pool.add(item);
      added++;
    }
    if (added > 0) {
      await _kv.setString(storageKey, jsonEncode(pool.map(encode).toList()));
    }
    return added;
  }
}

final dynamicContentStoreProvider = Provider<DynamicContentStore>(
  (ref) => DynamicContentStore(ref.read(keyValueStoreProvider)),
);
