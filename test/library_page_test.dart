import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/data/storage/prefs_provider.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/features/library/library_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dynWord = VocabWord(
    jp: '搭乗券', reading: 'とうじょうけん', zh: '登機證', topic: VocabTopic.travel);

Future<ProviderContainer> pump(WidgetTester tester,
    {DynamicContentStore? store}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final kv = InMemoryKeyValueStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        keyValueStoreProvider.overrideWithValue(kv),
        if (store != null) dynamicContentStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(home: LibraryPage()),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(LibraryPage)));
}

void main() {
  testWidgets('單字 tab：顯示靜態+動態、只有動態有 AI badge 與刪除鈕', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = DynamicContentStore(InMemoryKeyValueStore());
    await store.addVocab([_dynWord], existingKeys: {});
    await pump(tester, store: store);

    expect(find.textContaining('單字（${allVocab.length + 1}）'), findsOneWidget);
    // 搜尋鎖定動態字
    await tester.enterText(find.byType(TextField), '搭乗券');
    await tester.pump();
    expect(find.text('とうじょうけん・登機證'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    // 搜尋靜態字 → 無刪除鈕
    await tester.enterText(find.byType(TextField), '駅');
    await tester.pump();
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('刪除動態字 → 移出題庫 + 黑名單擋 re-add', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = DynamicContentStore(InMemoryKeyValueStore());
    await store.addVocab([_dynWord], existingKeys: {});
    final container = await pump(tester, store: store);

    await tester.enterText(find.byType(TextField), '搭乗券');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除'));
    await tester.pumpAndSettle();

    // 移出題庫
    expect(
        container
            .read(contentRepositoryProvider)
            .vocab()
            .any((w) => w.jp == '搭乗券'),
        isFalse);
    // 黑名單擋 re-add
    expect(await store.addVocab([_dynWord], existingKeys: {}), 0);
  });

  testWidgets('句子/文法題 tab 切換顯示', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester);
    await tester.tap(find.textContaining('句子（'));
    await tester.pumpAndSettle();
    expect(find.textContaining('機場'), findsWidgets);

    await tester.tap(find.textContaining('文法題（'));
    await tester.pumpAndSettle();
    expect(find.text('g01'), findsWidgets);
  });
}
