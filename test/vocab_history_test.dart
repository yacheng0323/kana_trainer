import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/data/storage/backup_service.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/progress/vocab_history_notifier.dart';

ProviderContainer makeContainer(InMemoryKeyValueStore kv) {
  final c = ProviderContainer(overrides: [
    keyValueStoreProvider.overrideWithValue(kv),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(() => StatsNotifier.today = () => '2026-07-15');

  test('snapshot：只算 v_ 開頭且 ≥4、total = 池內總數、persist', () {
    final kv = InMemoryKeyValueStore();
    final c = makeContainer(kv);
    final m = c.read(masteryProvider.notifier);
    // v_駅 → 4（已學會）、v_水 → 2（學習中）、か → 5（假名，不算）
    for (var i = 0; i < 4; i++) {
      m.record('v_駅', correct: true);
    }
    m.record('v_水', correct: true);
    for (var i = 0; i < 5; i++) {
      m.record('か', correct: true);
    }

    c.read(vocabHistoryProvider.notifier).snapshot();
    final history = c.read(vocabHistoryProvider);
    final today = history['2026-07-15']!;
    expect(today.learned, 1);
    expect(today.total, c.read(contentRepositoryProvider).vocab().length);

    // persist：新 container 讀回
    final c2 = makeContainer(kv);
    expect(c2.read(vocabHistoryProvider)['2026-07-15']!.learned, 1);
  });

  test('同日快照覆寫、跨日各留一筆', () {
    final kv = InMemoryKeyValueStore();
    final c = makeContainer(kv);
    final n = c.read(vocabHistoryProvider.notifier);
    n.snapshot();
    n.snapshot(); // 同日第二次
    expect(c.read(vocabHistoryProvider).length, 1);

    StatsNotifier.today = () => '2026-07-16';
    n.snapshot();
    expect(c.read(vocabHistoryProvider).length, 2);
  });

  test('weeklyGained：今日已學會 − 7 天前（含）最近快照', () {
    final kv = InMemoryKeyValueStore();
    final c = makeContainer(kv);
    // 手動塞歷史
    kv.setString(VocabHistoryNotifier.storageKey,
        '{"2026-07-08":[3,120],"2026-07-15":[10,150]}');
    final c2 = makeContainer(kv);
    expect(c2.read(vocabHistoryProvider.notifier).weeklyGained(), 7);
    c.dispose;
  });

  test('動態單字入池後 total 跟著長', () async {
    final kv = InMemoryKeyValueStore();
    final store = DynamicContentStore(kv);
    await store.addVocab([
      const VocabWord(
          jp: '搭乗券', reading: 'とうじょうけん', zh: '登機證', topic: VocabTopic.travel),
    ], existingKeys: {});
    final c = ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(kv),
      dynamicContentStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(c.dispose);
    c.read(vocabHistoryProvider.notifier).snapshot();
    final today = c.read(vocabHistoryProvider)['2026-07-15']!;
    expect(today.total, 106); // 105 靜態 + 1 動態
  });

  test('vocab_history 進備份', () {
    expect(BackupService.backupKeys, contains('vocab_history'));
  });
}
