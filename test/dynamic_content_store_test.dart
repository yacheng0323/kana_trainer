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

  test('儲存內容壞掉（手動塞爛 JSON）→ 靜默略過壞筆', () async {
    await kv.setString(DynamicContentStore.vocabKey,
        '[{"jp":"良","reading":"よい","zh":"好","topic":"daily"},{"jp":""}]');
    expect(DynamicContentStore(kv).vocab().single.jp, '良');
  });
}
