import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
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
}
