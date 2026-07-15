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
  static const grammarLessonsKey = 'dyn_grammar_lessons';

  /// 使用者刪除過的 key：永不再入池（擋 AI 重生成同題）。
  static const blacklistKey = 'dyn_blacklist';

  final KeyValueStore _kv;
  late final List<VocabWord> _vocab;
  late final List<Sentence> _sentences;
  late final List<DynamicGrammarQuiz> _grammar;
  late final List<DynamicGrammarLesson> _grammarLessons;
  late final Set<String> _blacklist;

  DynamicContentStore(this._kv) {
    _vocab = _load(vocabKey, vocabWordFromJson);
    _sentences = _load(sentencesKey, sentenceFromJson);
    _grammar = _load(grammarQuizKey, dynamicGrammarQuizFromJson);
    _grammarLessons = _load(grammarLessonsKey, dynamicGrammarLessonFromJson);
    _blacklist = _loadBlacklist();
  }

  Set<String> _loadBlacklist() {
    final raw = _kv.getString(blacklistKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List).whereType<String>().toSet();
    } catch (_) {
      return {};
    }
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
  List<DynamicGrammarLesson> grammarLessons() =>
      List.unmodifiable(_grammarLessons);

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

  Future<int> addGrammarLessons(List<DynamicGrammarLesson> items,
      {required Set<String> existingKeys}) {
    return _add(items, _grammarLessons, (l) => l.id, existingKeys,
        grammarLessonsKey, dynamicGrammarLessonToJson);
  }

  Future<int> _add<T>(
    List<T> items,
    List<T> pool,
    String Function(T) keyOf,
    Set<String> existingKeys,
    String storageKey,
    Map<String, dynamic> Function(T) encode,
  ) async {
    final seen = {...existingKeys, ...pool.map(keyOf), ..._blacklist};
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

  /// 使用者刪除：移出對應池 + 永久黑名單（AI 重生成同 key 會被 [_add] 擋）。
  Future<void> remove(String key) async {
    if (_vocab.any((w) => w.key == key)) {
      _vocab.removeWhere((w) => w.key == key);
      await _kv.setString(
          vocabKey, jsonEncode(_vocab.map(vocabWordToJson).toList()));
    } else if (_sentences.any((s) => s.key == key)) {
      _sentences.removeWhere((s) => s.key == key);
      await _kv.setString(
          sentencesKey, jsonEncode(_sentences.map(sentenceToJson).toList()));
    } else if (_grammar.any((q) => q.key == key)) {
      _grammar.removeWhere((q) => q.key == key);
      await _kv.setString(grammarQuizKey,
          jsonEncode(_grammar.map(dynamicGrammarQuizToJson).toList()));
    } else if (_grammarLessons.any((l) => l.id == key)) {
      _grammarLessons.removeWhere((l) => l.id == key);
      await _kv.setString(grammarLessonsKey,
          jsonEncode(_grammarLessons.map(dynamicGrammarLessonToJson).toList()));
    }
    _blacklist.add(key);
    await _kv.setString(blacklistKey, jsonEncode(_blacklist.toList()));
  }
}

final dynamicContentStoreProvider = Provider<DynamicContentStore>(
  (ref) => DynamicContentStore(ref.read(keyValueStoreProvider)),
);
