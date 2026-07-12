import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/ai/ai_quiz_service.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/domain/repositories/ai_client.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';

/// MVVM 抽象層驗證：ViewModel 只依賴介面，
/// 測試不需要 SharedPreferences mock、不需要 HTTP mock。

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

void main() {
  setUp(() => StatsNotifier.today = () => '2026-07-11');

  test('KeyValueStore：InMemory 實作直接驅動 notifiers（免 prefs mock）', () {
    final store = InMemoryKeyValueStore();
    final container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    container.read(masteryProvider.notifier).record('か', correct: true);
    container.read(statsProvider.notifier).record(correct: true);

    // 寫入落在 InMemory store，且重建 container 後可讀回（持久化路徑一致）
    expect(store.getString('mastery'), contains('か'));
    final container2 = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container2.dispose);
    expect(container2.read(masteryProvider)['か'], 1);
    expect(container2.read(statsProvider).total, 1);
  });

  test('AiClient：注入 fake 即可測 service，不經 HTTP', () async {
    final fake = FakeAiClient({
      'questions': [
        {
          'question': '「駅」是什麼意思？',
          'options': ['車站', '公車', '機場', '碼頭'],
          'correctIndex': 0,
          'note': '駅（えき）= 車站',
        },
      ],
    });
    final service = AiQuizService(aiClient: fake);
    final questions =
        await service.generate(apiKey: 'sk-any', topic: '交通', count: 1);
    expect(fake.calls, 1);
    expect(questions.single.options.first, '車站');
  });
}
