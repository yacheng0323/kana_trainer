import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/progress/vocab_history_notifier.dart';
import 'package:kana_trainer/features/stats/vocab_stats_page.dart';

void main() {
  setUp(() => StatsNotifier.today = () => '2026-07-15');

  testWidgets('大數字、主題 7 行、開頁記快照', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final kv = InMemoryKeyValueStore();
    final store = DynamicContentStore(kv);
    await store.addVocab([
      const VocabWord(
          jp: '搭乗券', reading: 'とうじょうけん', zh: '登機證', topic: VocabTopic.travel),
    ], existingKeys: {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(kv),
          dynamicContentStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(home: VocabStatsPage()),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VocabStatsPage)),
    );
    // 種一個已學會的字（v_駅 → 4）
    for (var i = 0; i < 4; i++) {
      container.read(masteryProvider.notifier).record('v_駅', correct: true);
    }
    await tester.pump(); // rebuild with mastery
    await tester.pump(); // flush microtask snapshot

    // 池內總數 = 105 靜態 + 1 動態
    expect(find.text('${allVocab.length + 1}'), findsWidgets);
    expect(find.text('池內總數'), findsOneWidget);
    expect(find.text('已學會'), findsWidgets);
    // 主題 7 行
    for (final t in VocabTopic.values) {
      expect(find.text(t.label), findsWidgets);
    }
    // 開頁快照已寫入
    expect(
        container.read(vocabHistoryProvider).containsKey('2026-07-15'), isTrue);
    // 資料 <2 點 → 佔位文案
    expect(find.textContaining('再練幾天'), findsOneWidget);
  });
}
