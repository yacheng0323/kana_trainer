import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:kana_trainer/features/sentence/sentence_view_model.dart';
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
    expect(state.options.length, 4); // pool 建得起來、正常出題
    final repo = c.read(contentRepositoryProvider);
    expect(
        repo.vocab().where((x) => x.topic == VocabTopic.travel).length,
        allVocab.where((x) => x.topic == VocabTopic.travel).length + 1);

    // 錯題本 key 相容 + 動態題字面查得到
    c.read(vocabWrongProvider.notifier).add(w.key);
    expect(c.read(vocabWrongProvider)['v_搭乗券'], 1);
    expect(repo.findVocab('v_搭乗券')!.zh, '登機證');
  });

  test('refreshPool：擴充後併入新題、session 不重置', () async {
    final kv = InMemoryKeyValueStore();
    final store = DynamicContentStore(kv);
    final c = ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(kv),
      dynamicContentStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(c.dispose);
    // 保持 provider 存活（autoDispose）
    final sub = c.listen(vocabPracticeProvider(VocabPool.travel), (_, _) {});
    addTearDown(sub.close);

    final notifier = c.read(vocabPracticeProvider(VocabPool.travel).notifier);
    var state = c.read(vocabPracticeProvider(VocabPool.travel));
    notifier.choose(state.correctIndex); // 答對 → streak 1
    expect(c.read(vocabPracticeProvider(VocabPool.travel)).streak, 1);

    // 模擬背景擴充完成 → refreshPool
    const w = VocabWord(
        jp: '免税店', reading: 'めんぜいてん', zh: '免稅店', topic: VocabTopic.travel);
    await store.addVocab([w], existingKeys: {});
    notifier.refreshPool();

    // session 保留、新字已可被抽出
    state = c.read(vocabPracticeProvider(VocabPool.travel));
    expect(state.streak, 1);
    expect(
        c
            .read(contentRepositoryProvider)
            .vocab()
            .where((x) => x.topic == VocabTopic.travel)
            .any((x) => x.jp == '免税店'),
        isTrue);
  });

  test('句子 refreshPool：擴充後併入新句、session 不重置', () async {
    final kv = InMemoryKeyValueStore();
    final store = DynamicContentStore(kv);
    final c = ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(kv),
      dynamicContentStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(c.dispose);
    final sub =
        c.listen(sentencePracticeProvider(ScenePool.restaurant), (_, _) {});
    addTearDown(sub.close);

    final notifier =
        c.read(sentencePracticeProvider(ScenePool.restaurant).notifier);
    var state = c.read(sentencePracticeProvider(ScenePool.restaurant));
    // 克漏字題直接答對；重組題跳過作答（只驗 refreshPool 不重置）
    var expectedStreak = 0;
    if (state.type == SentenceQuizType.cloze) {
      notifier.choose(state.correctIndex);
      expectedStreak = 1;
    }

    const s = Sentence(
        chunks: ['お会計', 'を', 'お願いします'],
        blankIndex: 0,
        zh: '請幫我結帳',
        scene: Scene.restaurant);
    await store.addSentences([s], existingKeys: {});
    notifier.refreshPool();

    state = c.read(sentencePracticeProvider(ScenePool.restaurant));
    expect(state.streak, expectedStreak);
    expect(
        c
            .read(contentRepositoryProvider)
            .sentences()
            .any((x) => x.jp == 'お会計をお願いします'),
        isTrue);
  });
}
