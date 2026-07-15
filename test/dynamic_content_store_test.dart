import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/models/dynamic_content.dart';
import 'package:kana_trainer/domain/repositories/key_value_store.dart';

const _w1 = VocabWord(
    jp: '切符', reading: 'きっぷ', zh: '車票', topic: VocabTopic.transport);
const _w2 = VocabWord(
    jp: '窓口', reading: 'まどぐち', zh: '窗口', topic: VocabTopic.transport);

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

  group('remove + 黑名單', () {
    test('remove：移出池、加黑名單、reload 後仍生效', () async {
      await store.addVocab([_w1, _w2], existingKeys: {});
      await store.remove(_w1.key);
      expect(store.vocab().map((w) => w.jp), ['窓口']);

      final reloaded = DynamicContentStore(kv);
      expect(reloaded.vocab().map((w) => w.jp), ['窓口']);
      // 黑名單擋 re-add（AI 重生成同字）
      final added = await reloaded.addVocab([_w1], existingKeys: {});
      expect(added, 0);
      expect(reloaded.vocab().length, 1);
    });

    test('remove 句子與文法題', () async {
      const s = Sentence(
          chunks: ['お水', 'を', 'ください'],
          blankIndex: 0,
          zh: '請給我水',
          scene: Scene.restaurant);
      const g = DynamicGrammarQuiz(
          lessonId: 'g01',
          quiz: GrammarQuiz(
              question: 'q＿＿', options: ['a', 'b', 'c', 'd'], correctIndex: 1));
      await store.addSentences([s], existingKeys: {});
      await store.addGrammarQuiz([g], existingKeys: {});
      await store.remove(s.key);
      await store.remove(g.key);
      expect(store.sentences(), isEmpty);
      expect(store.grammarQuiz(), isEmpty);
      expect(await store.addSentences([s], existingKeys: {}), 0);
      expect(await store.addGrammarQuiz([g], existingKeys: {}), 0);
    });

    test('remove 不存在的 key 不炸、仍進黑名單', () async {
      await store.remove('v_幽靈');
      final added = await store.addVocab([
        const VocabWord(
            jp: '幽靈', reading: 'ゆうれい', zh: '幽靈', topic: VocabTopic.daily),
      ], existingKeys: {});
      expect(added, 0);
    });
  });

  group('DynamicGrammarLesson', () {
    const lesson = DynamicGrammarLesson(
      id: 'gdyn_n4_受身形',
      level: 4,
      title: '受身形',
      explanation: '動詞被動態，表示被～。',
      examples: [
        GrammarExample('先生に褒められました。', '被老師稱讚了。'),
        GrammarExample('雨に降られました。', '被雨淋了。'),
      ],
      quiz: [
        GrammarQuiz(
            question: '先生に＿＿ました。',
            options: ['褒められ', '褒め', '褒めて', '褒めよう'],
            correctIndex: 0),
        GrammarQuiz(
            question: '犬に＿＿ました。',
            options: ['噛まれ', '噛み', '噛んで', '噛もう'],
            correctIndex: 0),
        GrammarQuiz(
            question: '友達に＿＿ました。',
            options: ['笑われ', '笑い', '笑って', '笑おう'],
            correctIndex: 0),
      ],
    );

    test('codec round-trip + toGrammarPoint', () {
      final restored =
          dynamicGrammarLessonFromJson(dynamicGrammarLessonToJson(lesson));
      expect(restored!.id, lesson.id);
      expect(restored.level, 4);
      expect(restored.examples.length, 2);
      expect(restored.quiz.length, 3);
      final point = restored.toGrammarPoint();
      expect(point.id, lesson.id);
      expect(point.quiz.length, 3);
    });

    test('壞課回 null（quiz≠3、examples<2、題面無挖空）', () {
      final base = dynamicGrammarLessonToJson(lesson);
      expect(
          dynamicGrammarLessonFromJson(
              {...base, 'quiz': (base['quiz'] as List).sublist(0, 2)}),
          isNull);
      expect(
          dynamicGrammarLessonFromJson({
            ...base,
            'examples': [
              {'jp': 'x', 'zh': 'y'}
            ]
          }),
          isNull);
      final noBlank = dynamicGrammarLessonToJson(lesson);
      (noBlank['quiz'] as List)[0] = {
        'question': '沒有挖空的題面',
        'options': ['a', 'b', 'c', 'd'],
        'correctIndex': 0,
      };
      expect(dynamicGrammarLessonFromJson(noBlank), isNull);
    });

    test('store 持久化 + remove 進黑名單擋 re-add', () async {
      await store.addGrammarLessons([lesson], existingKeys: {});
      final reloaded = DynamicContentStore(kv);
      expect(reloaded.grammarLessons().single.title, '受身形');

      await reloaded.remove(lesson.id);
      expect(reloaded.grammarLessons(), isEmpty);
      expect(await reloaded.addGrammarLessons([lesson], existingKeys: {}), 0);
    });
  });

  test('儲存內容壞掉（手動塞爛 JSON）→ 靜默略過壞筆', () async {
    await kv.setString(DynamicContentStore.vocabKey,
        '[{"jp":"良","reading":"よい","zh":"好","topic":"daily"},{"jp":""}]');
    expect(DynamicContentStore(kv).vocab().single.jp, '良');
  });
}
