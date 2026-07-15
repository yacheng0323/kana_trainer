import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/ai/ai_quiz_service.dart';
import 'package:kana_trainer/data/ai/content_expansion_service.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/data/storage/secure_store.dart';
import 'package:kana_trainer/domain/repositories/ai_client.dart';
import 'package:kana_trainer/features/grammar/grammar_list_page.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';

class FakeAiClient implements AiClient {
  final Map<String, dynamic> payload;

  FakeAiClient(this.payload);

  @override
  Future<Map<String, dynamic>> completeJson({
    required String apiKey,
    required String system,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> schema,
    int maxTokens = 4096,
  }) async =>
      payload;
}

final _lessonPayload = {
  'title': '受身形',
  'explanation': '動詞被動態，表示「被～」。',
  'examples': [
    {'jp': '先生に褒められました。', 'zh': '被老師稱讚了。'},
    {'jp': '雨に降られました。', 'zh': '被雨淋了。'},
  ],
  'quiz': [
    {
      'question': '先生に＿＿ました。',
      'options': ['褒められ', '褒め', '褒めて', '褒めよう'],
      'correctIndex': 0
    },
    {
      'question': '犬に＿＿ました。',
      'options': ['噛まれ', '噛み', '噛んで', '噛もう'],
      'correctIndex': 0
    },
    {
      'question': '友達に＿＿ました。',
      'options': ['笑われ', '笑い', '笑って', '笑おう'],
      'correctIndex': 0
    },
  ],
};

Future<ProviderContainer> pump(WidgetTester tester) async {
  final kv = InMemoryKeyValueStore();
  final secure = InMemoryKeyValueStore();
  await secure.setString(ApiKeyNotifier.storageKey, 'sk-ant-test');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(kv),
        secureStoreProvider.overrideWithValue(secure),
        contentExpansionServiceProvider.overrideWithValue(
            ContentExpansionService(aiClient: FakeAiClient(_lessonPayload))),
      ],
      child: const MaterialApp(home: GrammarListPage()),
    ),
  );
  return ProviderScope.containerOf(
      tester.element(find.byType(GrammarListPage)));
}

void main() {
  testWidgets('N4：空列表 + 生成按鈕 → 生成後課卡出現（AI badge）', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = await pump(tester);
    container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(jlptLevel: 4));
    await tester.pumpAndSettle();

    expect(find.textContaining('N4 文法（0 課'), findsOneWidget);
    expect(find.text('AI 生成下一課'), findsOneWidget);

    await tester.tap(find.text('AI 生成下一課'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('受身形'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(
        container.read(dynamicContentStoreProvider).grammarLessons().length,
        1);
  });

  testWidgets('N5：維持靜態 12 課線性解鎖', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester); // 預設 N5
    expect(find.textContaining('N5 文法（0/12）'), findsOneWidget);
    expect(find.text('可開始'), findsOneWidget);
    expect(find.text('AI 生成下一課'), findsNothing);
  });
}
