# 動態題庫池 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 單字/句子/文法測驗題可由 AI 批次生成擴充本地題庫池，練習出題 = 靜態種子 + 動態池合併，離線可玩、成本受控（每日 5 批）。

**Architecture:** domain 加 `ContentRepository` 抽象與 `ExpansionPolicy` 純函式；data 加 `DynamicContentStore`（KeyValueStore 持久化）、`MergedContentRepository`、`ContentExpansionService`（走既有 `AiClient`）；features 加 `ExpansionNotifier`（fire-and-forget 補貨狀態機）。學習引擎（mastery/SRS/錯題本）靠沿用 key 規則（`v_<jp>`、`s_<jp>`）零改動。

**Tech Stack:** Flutter + Riverpod（手寫 provider）、既有 ClaudeClient（structured outputs）、SharedPreferences（經 KeyValueStore）。

**Spec:** `docs/superpowers/specs/2026-07-14-dynamic-content-pool-design.md`

**慣例提醒：**
- 每次新 shell：`$env:PATH = "D:\flutter\bin;$env:PATH"`；工作目錄 `C:\Users\a0920\Desktop\kana_trainer`
- git commit 訊息不可含雙引號（PS 5.1 會裂）
- 測試 MockClient 含中文回應必須帶 `charset=utf-8`（本計畫用 FakeAiClient，不經 HTTP，無此問題）
- exam（模擬測驗）與 AI 弱點分析**不在本計畫範圍**（維持靜態，spec 非目標）

---

### Task 1: 動態內容 JSON codec（domain/models）

**Files:**
- Create: `lib/domain/models/dynamic_content.dart`
- Test: `test/dynamic_content_test.dart`

- [ ] **Step 1: 寫失敗測試**

```dart
// test/dynamic_content_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/models/dynamic_content.dart';

void main() {
  group('vocab codec', () {
    test('round-trip', () {
      const w = VocabWord(
          jp: '切符', reading: 'きっぷ', zh: '車票', topic: VocabTopic.transport);
      final restored = vocabWordFromJson(vocabWordToJson(w));
      expect(restored!.jp, '切符');
      expect(restored.reading, 'きっぷ');
      expect(restored.zh, '車票');
      expect(restored.topic, VocabTopic.transport);
      expect(restored.key, 'v_切符');
    });

    test('壞資料回 null（未知 topic、缺欄位、空字串）', () {
      expect(vocabWordFromJson({'jp': 'x', 'reading': 'x', 'zh': 'x', 'topic': 'nope'}), isNull);
      expect(vocabWordFromJson({'jp': 'x'}), isNull);
      expect(vocabWordFromJson({'jp': '', 'reading': 'x', 'zh': 'x', 'topic': 'travel'}), isNull);
    });
  });

  group('sentence codec', () {
    test('round-trip', () {
      const s = Sentence(
          chunks: ['駅は', 'どこ', 'ですか'],
          blankIndex: 1,
          zh: '車站在哪裡？',
          scene: Scene.train);
      final restored = sentenceFromJson(sentenceToJson(s));
      expect(restored!.jp, '駅はどこですか');
      expect(restored.blankIndex, 1);
      expect(restored.scene, Scene.train);
      expect(restored.key, 's_駅はどこですか');
    });

    test('壞資料回 null（blankIndex 超界、chunks 空）', () {
      expect(
          sentenceFromJson({'chunks': ['a'], 'blankIndex': 5, 'zh': 'x', 'scene': 'train'}),
          isNull);
      expect(
          sentenceFromJson({'chunks': [], 'blankIndex': 0, 'zh': 'x', 'scene': 'train'}),
          isNull);
    });
  });

  group('DynamicGrammarQuiz codec', () {
    test('round-trip + key', () {
      const q = DynamicGrammarQuiz(
        lessonId: 'g03',
        quiz: GrammarQuiz(
            question: '私＿＿学生です。',
            options: ['は', 'を', 'に', 'で'],
            correctIndex: 0),
      );
      final restored = dynamicGrammarQuizFromJson(dynamicGrammarQuizToJson(q));
      expect(restored!.lessonId, 'g03');
      expect(restored.quiz.options.length, 4);
      expect(restored.key, 'g03|私＿＿学生です。');
    });

    test('壞資料回 null（選項數≠4、重複、index 超界）', () {
      Map<String, dynamic> j(List<String> opts, int idx) => {
            'lessonId': 'g01',
            'question': 'q',
            'options': opts,
            'correctIndex': idx,
          };
      expect(dynamicGrammarQuizFromJson(j(['a', 'b', 'c'], 0)), isNull);
      expect(dynamicGrammarQuizFromJson(j(['a', 'a', 'b', 'c'], 0)), isNull);
      expect(dynamicGrammarQuizFromJson(j(['a', 'b', 'c', 'd'], 4)), isNull);
    });
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/dynamic_content_test.dart`
Expected: FAIL（`dynamic_content.dart` 不存在）

- [ ] **Step 3: 實作**

```dart
// lib/domain/models/dynamic_content.dart
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
```

- [ ] **Step 4: 跑測試確認通過**

Run: `flutter test test/dynamic_content_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models/dynamic_content.dart test/dynamic_content_test.dart
git commit -m 'feat: dynamic content JSON codecs with null-on-bad-data'
```

---

### Task 2: ExpansionPolicy 純函式（domain/logic）

**Files:**
- Create: `lib/domain/logic/expansion_policy.dart`
- Test: `test/expansion_policy_test.dart`

- [ ] **Step 1: 寫失敗測試**

```dart
// test/expansion_policy_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/domain/logic/expansion_policy.dart';

void main() {
  test('未見過 < 5 且今日 < 5 批且開啟 → 補貨', () {
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: true, unseenCount: 4, dailyCount: 0),
        isTrue);
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: true, unseenCount: 0, dailyCount: 4),
        isTrue);
  });

  test('未見過夠多 → 不補', () {
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: true, unseenCount: 5, dailyCount: 0),
        isFalse);
  });

  test('今日達上限 → 不補', () {
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: true, unseenCount: 0, dailyCount: 5),
        isFalse);
  });

  test('關閉 → 永不補', () {
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: false, unseenCount: 0, dailyCount: 0),
        isFalse);
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `flutter test test/expansion_policy_test.dart`
Expected: FAIL

- [ ] **Step 3: 實作**

```dart
// lib/domain/logic/expansion_policy.dart
/// 題庫補貨決策（純函式，成本控制的單一事實來源）。
class ExpansionPolicy {
  const ExpansionPolicy._();

  /// 範圍內「未見過」（熟練度 0）項目低於此值時觸發補貨。
  static const unseenThreshold = 5;

  /// 每日 AI 生成批數上限（一批一次 API 呼叫）。
  static const dailyLimit = 5;

  static bool shouldExpand({
    required bool enabled,
    required int unseenCount,
    required int dailyCount,
  }) =>
      enabled && unseenCount < unseenThreshold && dailyCount < dailyLimit;
}
```

- [ ] **Step 4: 跑測試確認通過** — `flutter test test/expansion_policy_test.dart` → PASS

- [ ] **Step 5: Commit**

```bash
git add lib/domain/logic/expansion_policy.dart test/expansion_policy_test.dart
git commit -m 'feat: expansion policy pure function (threshold 5, daily cap 5)'
```

---

### Task 3: DynamicContentStore（data/storage）

**Files:**
- Create: `lib/data/storage/dynamic_content_store.dart`
- Test: `test/dynamic_content_store_test.dart`

- [ ] **Step 1: 寫失敗測試**

```dart
// test/dynamic_content_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/models/dynamic_content.dart';
import 'package:kana_trainer/domain/repositories/key_value_store.dart';

const _w1 = VocabWord(jp: '切符', reading: 'きっぷ', zh: '車票', topic: VocabTopic.transport);
const _w2 = VocabWord(jp: '窓口', reading: 'まどぐち', zh: '窗口', topic: VocabTopic.transport);

void main() {
  late InMemoryKeyValueStore kv;
  late DynamicContentStore store;

  setUp(() {
    kv = InMemoryKeyValueStore();
    store = DynamicContentStore(kv);
  });

  test('addVocab 持久化，新 store 讀回', () async {
    final added = await store.addVocab([_w1, _w2], existingKeys: {});
    expect(added, 2);
    final reloaded = DynamicContentStore(kv);
    expect(reloaded.vocab().map((w) => w.jp), ['切符', '窓口']);
  });

  test('dedup：existingKeys（靜態）與池內既有都擋', () async {
    await store.addVocab([_w1], existingKeys: {});
    final added = await store.addVocab(
      [_w1, _w2], // _w1 池內已有
      existingKeys: {_w2.key}, // _w2 當作靜態已有
    );
    expect(added, 0);
    expect(store.vocab().length, 1);
  });

  test('sentences 與 grammarQuiz 各自獨立持久化', () async {
    const s = Sentence(
        chunks: ['お会計', 'を', 'お願いします'],
        blankIndex: 0,
        zh: '請幫我結帳',
        scene: Scene.restaurant);
    const g = DynamicGrammarQuiz(
        lessonId: 'g01',
        quiz: GrammarQuiz(
            question: 'q＿＿', options: ['a', 'b', 'c', 'd'], correctIndex: 1));
    await store.addSentences([s], existingKeys: {});
    await store.addGrammarQuiz([g], existingKeys: {});
    final reloaded = DynamicContentStore(kv);
    expect(reloaded.sentences().single.zh, '請幫我結帳');
    expect(reloaded.grammarQuiz().single.lessonId, 'g01');
    expect(reloaded.vocab(), isEmpty);
  });

  test('儲存內容壞掉（手動塞爛 JSON）→ 靜默略過壞筆', () async {
    await kv.setString(DynamicContentStore.vocabKey,
        '[{"jp":"良","reading":"よい","zh":"好","topic":"daily"},{"jp":""}]');
    expect(DynamicContentStore(kv).vocab().single.jp, '良');
  });
}
```

- [ ] **Step 2: 跑測試確認失敗** — `flutter test test/dynamic_content_store_test.dart` → FAIL

- [ ] **Step 3: 實作**

```dart
// lib/data/storage/dynamic_content_store.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/models/dynamic_content.dart';
import 'package:kana_trainer/domain/repositories/key_value_store.dart';

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
    return _add(items, _vocab, (w) => w.key, existingKeys, vocabKey,
        vocabWordToJson);
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
```

- [ ] **Step 4: 跑測試確認通過** — `flutter test test/dynamic_content_store_test.dart` → PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/storage/dynamic_content_store.dart test/dynamic_content_store_test.dart
git commit -m 'feat: DynamicContentStore - persisted AI content pool with dedup'
```

---

### Task 4: ContentRepository 抽象 + Merged 實作

**Files:**
- Create: `lib/domain/repositories/content_repository.dart`
- Create: `lib/data/content/merged_content_repository.dart`
- Test: `test/content_repository_test.dart`

- [ ] **Step 1: 寫失敗測試**

```dart
// test/content_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/data/static/grammar_data.dart';
import 'package:kana_trainer/data/static/sentence_data.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/models/dynamic_content.dart';
import 'package:kana_trainer/domain/repositories/key_value_store.dart';

void main() {
  late DynamicContentStore store;
  late MergedContentRepository repo;

  setUp(() {
    store = DynamicContentStore(InMemoryKeyValueStore());
    repo = MergedContentRepository(store);
  });

  test('動態池空 → 回靜態全量', () {
    expect(repo.vocab().length, allVocab.length);
    expect(repo.sentences().length, allSentences.length);
    final g1 = allGrammar.first;
    expect(repo.grammarQuiz(g1.id).length, g1.quiz.length);
  });

  test('動態單字合併在後、findVocab 查得到', () async {
    const w = VocabWord(jp: '搭乗券', reading: 'とうじょうけん', zh: '登機證', topic: VocabTopic.travel);
    await store.addVocab([w], existingKeys: {});
    expect(repo.vocab().length, allVocab.length + 1);
    expect(repo.findVocab('v_搭乗券')!.zh, '登機證');
    expect(repo.findVocab('v_不存在'), isNull);
    // 靜態的照常查得到
    expect(repo.findVocab('v_駅')!.zh, '車站');
  });

  test('grammarQuiz 合併該課動態題、不混他課', () async {
    final g1 = allGrammar.first;
    const extra = DynamicGrammarQuiz(
        lessonId: '', // 下面覆蓋
        quiz: GrammarQuiz(question: '新題＿＿', options: ['は', 'が', 'を', 'に'], correctIndex: 0));
    await store.addGrammarQuiz([
      DynamicGrammarQuiz(lessonId: g1.id, quiz: extra.quiz),
      DynamicGrammarQuiz(lessonId: 'g99', quiz: extra.quiz),
    ], existingKeys: {});
    expect(repo.grammarQuiz(g1.id).length, g1.quiz.length + 1);
  });
}
```

- [ ] **Step 2: 跑測試確認失敗** — `flutter test test/content_repository_test.dart` → FAIL

- [ ] **Step 3: 實作抽象**

```dart
// lib/domain/repositories/content_repository.dart
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
```

- [ ] **Step 4: 實作 Merged**

```dart
// lib/data/content/merged_content_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/static/grammar_data.dart';
import 'package:kana_trainer/data/static/sentence_data.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/repositories/content_repository.dart';

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
```

- [ ] **Step 5: 跑測試確認通過** — `flutter test test/content_repository_test.dart` → PASS

- [ ] **Step 6: Commit**

```bash
git add lib/domain/repositories/content_repository.dart lib/data/content/merged_content_repository.dart test/content_repository_test.dart
git commit -m 'feat: ContentRepository abstraction + merged static/dynamic impl'
```

---

### Task 5: ContentExpansionService（data/ai）

**Files:**
- Create: `lib/data/ai/content_expansion_service.dart`
- Test: `test/content_expansion_service_test.dart`

- [ ] **Step 1: 寫失敗測試**

```dart
// test/content_expansion_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/ai/content_expansion_service.dart';
import 'package:kana_trainer/data/static/grammar_data.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/repositories/ai_client.dart';

class FakeAiClient implements AiClient {
  final Map<String, dynamic> payload;
  String? lastSystem;
  List<Map<String, dynamic>>? lastMessages;

  FakeAiClient(this.payload);

  @override
  Future<Map<String, dynamic>> completeJson({
    required String apiKey,
    required String system,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> schema,
    int maxTokens = 4096,
  }) async {
    lastSystem = system;
    lastMessages = messages;
    return payload;
  }
}

void main() {
  group('generateVocab', () {
    test('合法批次全收、topic 固定為請求主題、避開清單有進 prompt', () async {
      final fake = FakeAiClient({
        'items': [
          {'jp': '搭乗券', 'reading': 'とうじょうけん', 'zh': '登機證'},
          {'jp': '荷物', 'reading': 'にもつ', 'zh': '行李'},
        ],
      });
      final service = ContentExpansionService(aiClient: fake);
      final words = await service.generateVocab(
        apiKey: 'sk',
        topic: VocabTopic.travel,
        existingJp: {'駅', '切符'},
      );
      expect(words.length, 2);
      expect(words.every((w) => w.topic == VocabTopic.travel), isTrue);
      final userMsg = fake.lastMessages!.first['content'] as String;
      expect(userMsg, contains('駅'));
      expect(userMsg, contains('切符'));
    });

    test('壞筆丟棄、重複（清單內/批內）丟棄，好筆保留', () async {
      final fake = FakeAiClient({
        'items': [
          {'jp': '駅', 'reading': 'えき', 'zh': '車站'}, // 已存在
          {'jp': '荷物', 'reading': 'にもつ', 'zh': '行李'},
          {'jp': '荷物', 'reading': 'にもつ', 'zh': '行李'}, // 批內重複
          {'jp': '', 'reading': 'x', 'zh': 'x'}, // 壞
        ],
      });
      final service = ContentExpansionService(aiClient: fake);
      final words = await service.generateVocab(
          apiKey: 'sk', topic: VocabTopic.travel, existingJp: {'駅'});
      expect(words.single.jp, '荷物');
    });
  });

  group('generateSentences', () {
    test('chunks 驗證：blankIndex 超界的丟棄', () async {
      final fake = FakeAiClient({
        'items': [
          {
            'chunks': ['お水', 'を', 'ください'],
            'blankIndex': 2,
            'zh': '請給我水'
          },
          {
            'chunks': ['壞'],
            'blankIndex': 9,
            'zh': 'x'
          },
        ],
      });
      final service = ContentExpansionService(aiClient: fake);
      final items = await service.generateSentences(
          apiKey: 'sk', scene: Scene.restaurant, existingJp: {});
      expect(items.single.jp, 'お水をください');
      expect(items.single.scene, Scene.restaurant);
    });
  });

  group('generateGrammarQuiz', () {
    test('綁 lessonId、同課題面重複丟棄', () async {
      final g = allGrammar.first;
      final existing = g.quiz.first.question;
      final fake = FakeAiClient({
        'items': [
          {
            'question': existing, // 與靜態重複
            'options': ['は', 'が', 'を', 'に'],
            'correctIndex': 0
          },
          {
            'question': '彼＿＿先生です。',
            'options': ['は', 'を', 'に', 'で'],
            'correctIndex': 0
          },
        ],
      });
      final service = ContentExpansionService(aiClient: fake);
      final items = await service.generateGrammarQuiz(
        apiKey: 'sk',
        point: g,
        existingQuestions: {existing},
      );
      expect(items.single.lessonId, g.id);
      expect(items.single.quiz.question, '彼＿＿先生です。');
    });
  });

  test('AiException 原樣往上丟', () async {
    final service = ContentExpansionService(aiClient: _ThrowingAiClient());
    expect(
      () => service.generateVocab(
          apiKey: 'sk', topic: VocabTopic.daily, existingJp: {}),
      throwsA(isA<AiException>()),
    );
  });
}

class _ThrowingAiClient implements AiClient {
  @override
  Future<Map<String, dynamic>> completeJson({
    required String apiKey,
    required String system,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> schema,
    int maxTokens = 4096,
  }) async {
    throw const AiException('網路連線失敗');
  }
}
```

- [ ] **Step 2: 跑測試確認失敗** — `flutter test test/content_expansion_service_test.dart` → FAIL

- [ ] **Step 3: 實作**

```dart
// lib/data/ai/content_expansion_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kana_trainer/data/ai/claude_client.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/models/dynamic_content.dart';
import 'package:kana_trainer/domain/repositories/ai_client.dart';

/// AI 題庫擴充：一次生成一批，本地驗證（AI 回傳不可信）+ 去重後回傳。
/// 整批全滅回空 list（呼叫端視為失敗批，仍計入每日批數避免壞回應重試迴圈）。
class ContentExpansionService {
  static const vocabBatch = 15;
  static const sentenceBatch = 8;
  static const grammarBatch = 5;

  final AiClient _client;

  ContentExpansionService({AiClient? aiClient})
      : _client = aiClient ?? ClaudeClient();

  static const _vocabSchema = {
    'type': 'object',
    'properties': {
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'jp': {'type': 'string'},
            'reading': {'type': 'string'},
            'zh': {'type': 'string'},
          },
          'required': ['jp', 'reading', 'zh'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['items'],
    'additionalProperties': false,
  };

  static const _sentenceSchema = {
    'type': 'object',
    'properties': {
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'chunks': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'blankIndex': {'type': 'integer'},
            'zh': {'type': 'string'},
          },
          'required': ['chunks', 'blankIndex', 'zh'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['items'],
    'additionalProperties': false,
  };

  static const _grammarSchema = {
    'type': 'object',
    'properties': {
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'question': {'type': 'string'},
            'options': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'correctIndex': {'type': 'integer', 'enum': [0, 1, 2, 3]},
          },
          'required': ['question', 'options', 'correctIndex'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['items'],
    'additionalProperties': false,
  };

  Future<List<VocabWord>> generateVocab({
    required String apiKey,
    required VocabTopic topic,
    required Set<String> existingJp,
  }) async {
    final payload = await _client.completeJson(
      apiKey: apiKey,
      system: '你是專業日語教師，為繁體中文使用者挑選 JLPT N5 程度的日語單字。'
          '規則：jp 為顯示字（常用漢字或假名）、reading 為假名讀音、'
          'zh 為繁體中文意思（簡短）；全部必須是 N5 常用詞，不出偏僻詞。',
      messages: [
        {
          'role': 'user',
          'content': '主題「${topic.label}」，出 $vocabBatch 個新單字。'
              '絕對不要出這些已有的字：${existingJp.join('、')}',
        },
      ],
      schema: _vocabSchema,
    );
    final seen = {...existingJp};
    final out = <VocabWord>[];
    for (final raw in _items(payload)) {
      final w = vocabWordFromJson({...raw, 'topic': topic.name});
      if (w == null || seen.contains(w.jp)) continue;
      seen.add(w.jp);
      out.add(w);
    }
    return out;
  }

  Future<List<Sentence>> generateSentences({
    required String apiKey,
    required Scene scene,
    required Set<String> existingJp,
  }) async {
    final payload = await _client.completeJson(
      apiKey: apiKey,
      system: '你是專業日語教師，為繁體中文使用者編寫 JLPT N5 程度的日語情境句。'
          '規則：chunks 為正確語序的語塊（3~6 塊，供重組題用），'
          'blankIndex 為克漏字挖空的語塊索引（挑助詞或關鍵詞），'
          'zh 為繁體中文翻譯。句子必須自然、實用、N5 程度。',
      messages: [
        {
          'role': 'user',
          'content': '情境「${scene.label}」，出 $sentenceBatch 句新句子。'
              '絕對不要出這些已有的句子：${existingJp.join('／')}',
        },
      ],
      schema: _sentenceSchema,
    );
    final seen = {...existingJp};
    final out = <Sentence>[];
    for (final raw in _items(payload)) {
      final s = sentenceFromJson({...raw, 'scene': scene.name});
      if (s == null || seen.contains(s.jp)) continue;
      seen.add(s.jp);
      out.add(s);
    }
    return out;
  }

  Future<List<DynamicGrammarQuiz>> generateGrammarQuiz({
    required String apiKey,
    required GrammarPoint point,
    required Set<String> existingQuestions,
  }) async {
    final payload = await _client.completeJson(
      apiKey: apiKey,
      system: '你是專業日語教師，為繁體中文使用者出 JLPT N5 文法測驗題。'
          '規則：question 為含「＿＿」挖空的日文句子；options 恰 4 個不重複；'
          '干擾項合理但明確錯誤；緊扣指定文法點，不混入其他文法。',
      messages: [
        {
          'role': 'user',
          'content': '文法點「${point.title}」：${point.explanation}\n'
              '出 $grammarBatch 題新題目。絕對不要出這些已有的題面：'
              '${existingQuestions.join('／')}',
        },
      ],
      schema: _grammarSchema,
    );
    final seen = {...existingQuestions};
    final out = <DynamicGrammarQuiz>[];
    for (final raw in _items(payload)) {
      final q = dynamicGrammarQuizFromJson({...raw, 'lessonId': point.id});
      if (q == null || seen.contains(q.quiz.question)) continue;
      seen.add(q.quiz.question);
      out.add(q);
    }
    return out;
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> payload) {
    final raw = payload['items'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }
}

final contentExpansionServiceProvider =
    Provider<ContentExpansionService>((ref) => ContentExpansionService());
```

- [ ] **Step 4: 跑測試確認通過** — `flutter test test/content_expansion_service_test.dart` → PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/ai/content_expansion_service.dart test/content_expansion_service_test.dart
git commit -m 'feat: ContentExpansionService - AI batch generation with local validation'
```

---

### Task 6: Settings.autoExpand + ExpansionNotifier（features）

**Files:**
- Modify: `lib/domain/models/app_settings.dart`（加 `autoExpand` 欄位，預設 true — 照既有 toJson/fromJson/copyWith 三處模式）
- Create: `lib/features/expansion/expansion_notifier.dart`
- Test: `test/expansion_notifier_test.dart`

- [ ] **Step 1: Settings 加欄位**

`app_settings.dart` 仿 `sound` 欄位模式加：
- 欄位：`final bool autoExpand; // AI 自動擴充題庫`
- 建構子：`this.autoExpand = true,`
- toJson：`'autoExpand': autoExpand,`
- fromJson：`autoExpand: json['autoExpand'] as bool? ?? true,`
- copyWith：`bool? autoExpand,` + `autoExpand: autoExpand ?? this.autoExpand,`

- [ ] **Step 2: 寫失敗測試**

```dart
// test/expansion_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/ai/ai_quiz_service.dart';
import 'package:kana_trainer/data/ai/content_expansion_service.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/data/storage/secure_store.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/repositories/ai_client.dart';
import 'package:kana_trainer/features/expansion/expansion_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';

class FakeAiClient implements AiClient {
  final Map<String, dynamic> payload;
  int calls = 0;

  FakeAiClient(this.payload);

  @override
  Future<Map<String, dynamic>> completeJson({
    required String apiKey,
    required String system,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> schema,
    int maxTokens = 4096,
  }) async {
    calls++;
    return payload;
  }
}

ProviderContainer makeContainer(FakeAiClient fake, {String apiKey = 'sk'}) {
  final kv = InMemoryKeyValueStore();
  final secure = InMemoryKeyValueStore();
  if (apiKey.isNotEmpty) secure.setString(ApiKeyNotifier.storageKey, apiKey);
  final container = ProviderContainer(overrides: [
    keyValueStoreProvider.overrideWithValue(kv),
    secureStoreProvider.overrideWithValue(secure),
    contentExpansionServiceProvider
        .overrideWithValue(ContentExpansionService(aiClient: fake)),
  ]);
  addTearDown(container.dispose);
  return container;
}

final _payload = {
  'items': [
    {'jp': '搭乗券', 'reading': 'とうじょうけん', 'zh': '登機證'},
  ],
};

void main() {
  setUp(() => StatsNotifier.today = () => '2026-07-14');

  test('未見過不足 → 生成並入池、SnackBar 資料（lastAdded）、批數 +1', () async {
    final fake = FakeAiClient(_payload);
    final c = makeContainer(fake);
    // 靜態 travel 主題 15 詞全標熟練（unseen = 0 → 觸發）
    // 直接用 masteryProvider 太囉唆：travel 15 詞 unseen < 5 需 11 詞熟練。
    // 簡化：maybeExpandVocab 的 unseen 判斷注入自 pool + mastery；
    // 這裡把 mastery 全填。
    final mastery = c.read(masteryProviderForTest);
    // （實作段落見 Step 3 — notifier 提供 @visibleForTesting 的 unseen 覆寫）
    await c
        .read(expansionProvider.notifier)
        .maybeExpandVocab(VocabTopic.travel, unseenOverride: 0);
    expect(fake.calls, 1);
    expect(c.read(expansionProvider).todayCount, 1);
    expect(c.read(expansionProvider).lastAdded, 1);
    expect(
        c.read(dynamicContentStoreProvider).vocab().single.jp, '搭乗券');
  });

  test('unseen 足夠 → 不呼叫', () async {
    final fake = FakeAiClient(_payload);
    final c = makeContainer(fake);
    await c
        .read(expansionProvider.notifier)
        .maybeExpandVocab(VocabTopic.travel, unseenOverride: 10);
    expect(fake.calls, 0);
  });

  test('無 API Key → 不呼叫', () async {
    final fake = FakeAiClient(_payload);
    final c = makeContainer(fake, apiKey: '');
    await c
        .read(expansionProvider.notifier)
        .maybeExpandVocab(VocabTopic.travel, unseenOverride: 0);
    expect(fake.calls, 0);
  });

  test('每日 5 批封頂、跨日重置', () async {
    final fake = FakeAiClient(_payload);
    final c = makeContainer(fake);
    final n = c.read(expansionProvider.notifier);
    for (var i = 0; i < 7; i++) {
      await n.maybeExpandVocab(VocabTopic.travel, unseenOverride: 0);
    }
    expect(fake.calls, 5);
    StatsNotifier.today = () => '2026-07-15';
    await n.maybeExpandVocab(VocabTopic.travel, unseenOverride: 0);
    expect(fake.calls, 6);
    expect(c.read(expansionProvider).todayCount, 1);
  });

  test('AI 失敗 → error 狀態、批數仍 +1（防重試迴圈）、不炸', () async {
    final c = makeContainer(_ThrowingFake());
    await c
        .read(expansionProvider.notifier)
        .maybeExpandVocab(VocabTopic.travel, unseenOverride: 0);
    expect(c.read(expansionProvider).status, ExpansionStatus.error);
    expect(c.read(expansionProvider).todayCount, 1);
  });
}

class _ThrowingFake extends FakeAiClient {
  _ThrowingFake() : super(const {});
  @override
  Future<Map<String, dynamic>> completeJson({
    required String apiKey,
    required String system,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> schema,
    int maxTokens = 4096,
  }) async {
    calls++;
    throw const AiException('網路連線失敗');
  }
}
```

> 注意：測試裡 `masteryProviderForTest` 那兩行是草稿雜訊 — **實際寫測試時刪掉**，
> unseen 一律用 `unseenOverride` 參數注入（見 Step 3 實作），不用 mastery 鋪資料。

- [ ] **Step 3: 實作 ExpansionNotifier**

```dart
// lib/features/expansion/expansion_notifier.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/ai/ai_quiz_service.dart';
import 'package:kana_trainer/data/ai/content_expansion_service.dart';
import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/logic/expansion_policy.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';

enum ExpansionStatus { idle, generating, done, error }

class ExpansionState {
  final ExpansionStatus status;
  final int todayCount; // 今日已生成批數
  final int lastAdded; // 最近一批入池題數（SnackBar 用）
  final String? error;

  const ExpansionState({
    this.status = ExpansionStatus.idle,
    this.todayCount = 0,
    this.lastAdded = 0,
    this.error,
  });

  ExpansionState copyWith({
    ExpansionStatus? status,
    int? todayCount,
    int? lastAdded,
    String? error,
  }) =>
      ExpansionState(
        status: status ?? this.status,
        todayCount: todayCount ?? this.todayCount,
        lastAdded: lastAdded ?? this.lastAdded,
        error: error,
      );
}

/// 題庫自動補貨。fire-and-forget：練習頁 initState 呼叫，不 await 不擋 UI。
/// 失敗靜默（練習照常用現有池），僅設定頁可見狀態。
class ExpansionNotifier extends Notifier<ExpansionState> {
  static const dailyKey = 'expansion_daily';

  @override
  ExpansionState build() =>
      ExpansionState(todayCount: _readDailyCount());

  int _readDailyCount() {
    final raw = ref.read(keyValueStoreProvider).getString(dailyKey);
    if (raw == null) return 0;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['date'] != StatsNotifier.today()) return 0; // 跨日重置
      return json['count'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _bumpDailyCount() async {
    final count = _readDailyCount() + 1;
    await ref.read(keyValueStoreProvider).setString(
        dailyKey, jsonEncode({'date': StatsNotifier.today(), 'count': count}));
    state = state.copyWith(todayCount: count);
  }

  /// 共用補貨流程。[unseenOverride] 供測試注入，生產一律傳 null。
  Future<void> _maybeExpand({
    required int unseenCount,
    required Future<int> Function(String apiKey) generateAndStore,
  }) async {
    final apiKey = ref.read(apiKeyProvider);
    final enabled =
        ref.read(settingsProvider).autoExpand && apiKey.isNotEmpty;
    if (!ExpansionPolicy.shouldExpand(
      enabled: enabled,
      unseenCount: unseenCount,
      dailyCount: _readDailyCount(),
    )) {
      return;
    }
    await _bumpDailyCount(); // 先計數：壞回應/失敗也算，防重試迴圈
    state = state.copyWith(status: ExpansionStatus.generating);
    try {
      final added = await generateAndStore(apiKey);
      state = state.copyWith(
          status: ExpansionStatus.done, lastAdded: added, error: null);
    } on AiException catch (e) {
      state = state.copyWith(status: ExpansionStatus.error, error: e.message);
    }
  }

  int _unseen(Iterable<String> keys) {
    final mastery = ref.read(masteryProvider);
    return keys.where((k) => (mastery[k] ?? 0) == 0).length;
  }

  Future<void> maybeExpandVocab(VocabTopic topic,
      {@visibleForTesting int? unseenOverride}) async {
    final repo = ref.read(contentRepositoryProvider);
    final pool = repo.vocab().where((w) => w.topic == topic).toList();
    await _maybeExpand(
      unseenCount: unseenOverride ?? _unseen(pool.map((w) => w.key)),
      generateAndStore: (apiKey) async {
        final batch =
            await ref.read(contentExpansionServiceProvider).generateVocab(
                  apiKey: apiKey,
                  topic: topic,
                  existingJp: repo.vocab().map((w) => w.jp).toSet(),
                );
        return ref.read(dynamicContentStoreProvider).addVocab(batch,
            existingKeys: repo.vocab().map((w) => w.key).toSet());
      },
    );
  }

  Future<void> maybeExpandSentences(Scene scene,
      {@visibleForTesting int? unseenOverride}) async {
    final repo = ref.read(contentRepositoryProvider);
    final pool = repo.sentences().where((s) => s.scene == scene).toList();
    await _maybeExpand(
      unseenCount: unseenOverride ?? _unseen(pool.map((s) => s.key)),
      generateAndStore: (apiKey) async {
        final batch =
            await ref.read(contentExpansionServiceProvider).generateSentences(
                  apiKey: apiKey,
                  scene: scene,
                  existingJp: repo.sentences().map((s) => s.jp).toSet(),
                );
        return ref.read(dynamicContentStoreProvider).addSentences(batch,
            existingKeys: repo.sentences().map((s) => s.key).toSet());
      },
    );
  }

  Future<void> maybeExpandGrammar(GrammarPoint point,
      {@visibleForTesting int? unseenOverride}) async {
    final repo = ref.read(contentRepositoryProvider);
    final existing =
        repo.grammarQuiz(point.id).map((q) => q.question).toSet();
    // 文法「未見過」定義：該課動態題少於門檻就補（教學固定、題目愈多愈好）
    final dynamicCount = existing.length - point.quiz.length;
    await _maybeExpand(
      unseenCount: unseenOverride ?? dynamicCount,
      generateAndStore: (apiKey) async {
        final batch = await ref
            .read(contentExpansionServiceProvider)
            .generateGrammarQuiz(
                apiKey: apiKey, point: point, existingQuestions: existing);
        return ref.read(dynamicContentStoreProvider).addGrammarQuiz(batch,
            existingKeys: batch.isEmpty
                ? const {}
                : repo
                    .grammarQuiz(point.id)
                    .map((q) => '${point.id}|${q.question}')
                    .toSet());
      },
    );
  }
}

final expansionProvider = NotifierProvider<ExpansionNotifier, ExpansionState>(
    ExpansionNotifier.new);
```

- [ ] **Step 4: 跑測試** — `flutter test test/expansion_notifier_test.dart` → PASS；`flutter test` 全綠（Settings 變動不能壞舊測試）

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models/app_settings.dart lib/features/expansion/expansion_notifier.dart test/expansion_notifier_test.dart
git commit -m 'feat: ExpansionNotifier - auto-restock state machine with daily cap'
```

---

### Task 7: ViewModel / 頁面接線

**Files:**
- Modify: `lib/features/vocab/vocab_view_model.dart`（`allVocab` → repo）
- Modify: `lib/features/sentence/sentence_view_model.dart`（`allSentences` → repo）
- Modify: `lib/features/listening/listening_view_model.dart`（`allVocab` → repo）
- Modify: `lib/features/today/daily_menu_builder.dart` + `lib/features/today/daily_menu_page.dart`（pool 參數化）
- Modify: `lib/features/vocab/vocab_practice_page.dart`、`lib/features/sentence/sentence_practice_page.dart`（initState 觸發補貨 + SnackBar）
- Modify: `lib/features/grammar/grammar_lesson_page.dart`（quiz 走 repo 合併 + 觸發補貨）
- Modify: `lib/features/progress/wrong_list_page.dart`（label 查找走 repo，動態題錯題才顯示得出字面）
- Test: `test/dynamic_wiring_test.dart`

- [ ] **Step 1: ViewModel 改 repo（機械替換）**

三個 ViewModel 模式相同 — 以 vocab 為例：

```dart
// vocab_view_model.dart：import 換掉
// - import 'package:kana_trainer/data/static/vocab_data.dart';
// + import 'package:kana_trainer/data/content/merged_content_repository.dart';

// build() 開頭加：
final allWords = ref.read(contentRepositoryProvider).vocab();
// 其後所有 `allVocab` 出現處改用 `allWords`（build 與 _question 的 fallback，
// _question 內取不到 build 區域變數 → 存成 field `late List<VocabWord> _all;`
// build 裡 `_all = ref.read(contentRepositoryProvider).vocab();`）
```

`sentence_view_model.dart`：同模式，`_all = ref.read(contentRepositoryProvider).sentences();`，`allSentences` 全換 `_all`。
`listening_view_model.dart`：同模式換 `allVocab`。

- [ ] **Step 2: daily_menu_builder 參數化**

`DailyMenuBuilder.build(...)` 與 `preview(...)` 各加兩個可選參數：

```dart
List<VocabWord>? vocabPool,
List<Sentence>? sentencePool,
```

函式內開頭：

```dart
final vocab = vocabPool ?? allVocab;
final sentences = sentencePool ?? allSentences;
```

內部所有 `allVocab`/`allSentences` 改用區域變數。`daily_menu_page.dart` 呼叫處傳入：

```dart
vocabPool: ref.read(contentRepositoryProvider).vocab(),
sentencePool: ref.read(contentRepositoryProvider).sentences(),
```

（既有 m8_test 不傳 → 走靜態 default，零改動。）

- [ ] **Step 3: 練習頁觸發補貨 + SnackBar**

`vocab_practice_page.dart`（ConsumerStatefulWidget）：

```dart
@override
void initState() {
  super.initState();
  final topic = widget.pool.topic;
  if (topic != null) {
    Future.microtask(
        () => ref.read(expansionProvider.notifier).maybeExpandVocab(topic));
  }
}
```

build() 內加 listener（三個練習頁同模式）：

```dart
ref.listen(expansionProvider, (prev, next) {
  if (next.status == ExpansionStatus.done &&
      next.lastAdded > 0 &&
      prev?.status == ExpansionStatus.generating) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('題庫 +${next.lastAdded} 題')),
    );
  }
});
```

`sentence_practice_page.dart`：`widget.pool.scene != null` → `maybeExpandSentences(scene)`。
`grammar_lesson_page.dart`：initState 加 `Future.microtask(() => ref.read(expansionProvider.notifier).maybeExpandGrammar(widget.point));`

- [ ] **Step 4: 文法課 quiz 走 repo**

`grammar_lesson_page.dart`：initState 中把 quiz 來源換掉 —

```dart
late List<GrammarQuiz> _quizzes;

@override
void initState() {
  super.initState();
  final merged = ref.read(contentRepositoryProvider).grammarQuiz(widget.point.id);
  final rng = Random();
  // 題數維持 3：靜態 3 + 動態池打亂取 3（動態夠多時每輪不同題）
  _quizzes = (List.of(merged)..shuffle(rng)).take(3).toList();
  _optionOrders = [
    for (final q in _quizzes)
      List.generate(q.options.length, (i) => i)..shuffle(rng),
  ];
  // …補貨 microtask（Step 3）
}
```

`widget.point.quiz` 其餘出現處全改 `_quizzes`。

- [ ] **Step 5: wrong_list_page 查找走 repo**

該頁用 `findVocab(key)` / `findSentence(key)`（data/static 的全域函式）顯示錯題字面。改為：

```dart
final repo = ref.read(contentRepositoryProvider);
// findVocab(key)  → repo.findVocab(key)
// findSentence(key) → repo.findSentence(key)
```

（頁面若是 ConsumerWidget 直接 ref；實作時看該檔案實際結構對應。）

- [ ] **Step 6: 接線測試**

```dart
// test/dynamic_wiring_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/repositories/key_value_store.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:kana_trainer/features/vocab/vocab_view_model.dart';

void main() {
  test('動態單字會進練習池、答錯進錯題本（key 相容）', () async {
    final kv = InMemoryKeyValueStore();
    final store = DynamicContentStore(kv);
    const w = VocabWord(
        jp: '搭乗券', reading: 'とうじょうけん', zh: '登機證', topic: VocabTopic.travel);
    await store.addVocab([w], existingKeys: {});

    final c = ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(kv),
      dynamicContentStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(c.dispose);

    // 練習池含動態字
    final state = c.read(vocabPracticeProvider(VocabPool.travel));
    expect(state, isNotNull); // pool 建得起來
    final repo = c.read(contentRepositoryProvider);
    expect(
        repo.vocab().where((x) => x.topic == VocabTopic.travel).length,
        allVocab.where((x) => x.topic == VocabTopic.travel).length + 1);

    // 錯題本 key 相容
    c.read(vocabWrongProvider.notifier).add(w.key);
    expect(c.read(vocabWrongProvider)['v_搭乗券'], 1);
    expect(repo.findVocab('v_搭乗券')!.zh, '登機證');
  });
}
```

- [ ] **Step 7: 全測試 + analyze**

Run: `dart analyze lib/ test/` → 零 issue；`flutter test` → 全綠（既有 vocab/sentence/m4/m8 測試都不能壞 — 它們 override prefsProvider，動態池空 → 行為同靜態）

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m 'feat: wire practice pools through ContentRepository + auto-expansion triggers'
```

---

### Task 8: 設定頁 UI + 備份

**Files:**
- Modify: `lib/features/settings/settings_page.dart`（AI 區塊加開關 + 今日批數）
- Modify: `lib/data/storage/backup_service.dart`（backupKeys 加 3 個 dyn key）
- Test: 擴充 `test/expansion_notifier_test.dart`（備份斷言）+ settings widget 測試

- [ ] **Step 1: 設定頁**

settings_page.dart 的 AI（API Key）區塊下方加（仿既有 SwitchListTile 模式）：

```dart
SwitchListTile(
  title: const Text('AI 自動擴充題庫'),
  subtitle: Text(
      '練習時題目快輪完自動生成新題（今日已生成 ${ref.watch(expansionProvider).todayCount}/${ExpansionPolicy.dailyLimit} 批）'),
  value: ref.watch(settingsProvider).autoExpand,
  onChanged: (v) => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(autoExpand: v)),
),
```

- [ ] **Step 2: 備份 keys**

`backup_service.dart` 的 `backupKeys` 加：

```dart
'dyn_vocab',
'dyn_sentences',
'dyn_grammar_quiz',
```

（`expansion_daily` **不加** — 日計數無跨機意義。）

- [ ] **Step 3: 測試**

`expansion_notifier_test.dart` 加：

```dart
test('動態池進備份、日計數不進', () {
  expect(BackupService.backupKeys, contains('dyn_vocab'));
  expect(BackupService.backupKeys, contains('dyn_sentences'));
  expect(BackupService.backupKeys, contains('dyn_grammar_quiz'));
  expect(BackupService.backupKeys, isNot(contains(ExpansionNotifier.dailyKey)));
});
```

settings widget 測試（加進既有 `test/settings_test.dart`）：

```dart
testWidgets('AI 自動擴充開關切換持久化', (tester) async {
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const MaterialApp(home: SettingsPage()),
  ));
  final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)));
  expect(container.read(settingsProvider).autoExpand, isTrue);
  await tester.ensureVisible(find.text('AI 自動擴充題庫'));
  await tester.tap(find.text('AI 自動擴充題庫'));
  await tester.pumpAndSettle();
  expect(container.read(settingsProvider).autoExpand, isFalse);
});
```

- [ ] **Step 4: 全測試 + analyze** — `dart analyze lib/ test/` 零 issue、`flutter test` 全綠

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m 'feat: auto-expand settings toggle + dynamic pool in backup'
```

---

### Task 9: 文件 + Release v2.6.0

**Files:**
- Modify: `CLAUDE.md`（版本歷程、架構圖加 expansion/content、prefs keys 表加 dyn_*、測試數）
- Modify: `docs/ROADMAP.md`（v2.6.0 條目）
- Modify: `pubspec.yaml`（`version: 2.6.0+10`）
- Modify: `lib/features/home/tabs/profile_tab.dart`（`kana_trainer v2.6.0`）

- [ ] **Step 1: 文件更新**（CLAUDE.md 版本表加 v2.6.0 行、prefs keys 表加 `dyn_vocab`/`dyn_sentences`/`dyn_grammar_quiz`（✅ 備份）與 `expansion_daily`（❌）、測試總數更新）

- [ ] **Step 2: Release gates**

```powershell
dart analyze lib/ test/     # 零 issue
flutter test                 # 全綠
flutter build web --release  # 過
flutter build apk --release  # 過
```

- [ ] **Step 3: 合併 + tag + APK**

```bash
git add -A && git commit -m 'docs: v2.6.0 dynamic content pool - CLAUDE.md, ROADMAP, version bump'
git checkout dev && git merge --no-ff feature/dynamic-content -m 'merge: feature/dynamic-content into dev - AI dynamic question pool'
git checkout main && git merge --no-ff dev -m 'merge: dev into main - release v2.6.0'
git tag v2.6.0
git push origin main dev feature/dynamic-content v2.6.0
git checkout dev
cp build/app/outputs/flutter-apk/app-release.apk /c/Users/a0920/Desktop/kana_trainer-v2.6.0.apk
```

---

## Self-Review 紀錄

- **Spec 覆蓋**：§4 元件 → Task 2-6；§5 資料模型 → Task 1；§6 生成規格 → Task 5；§7 觸發/成本 → Task 2+6；§8 備份 → Task 8；§9 UI → Task 7-8；§10 測試 → 各 task；§11 驗收 → Task 7 wiring test + Task 9 gates。exam/AI 分析維持靜態（spec 非目標）已標注。
- **Placeholder**：Task 6 Step 2 測試草稿內 `masteryProviderForTest` 已標注刪除、改用 `unseenOverride`。
- **型別一致**：`ExpansionStatus`、`expansionProvider`、`contentRepositoryProvider`、`dynamicContentStoreProvider`、`contentExpansionServiceProvider` 命名各 task 一致；`DynamicGrammarQuiz.key` 格式 `<lessonId>|<question>` 於 Task 1/3/6 一致。
