import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/ai/ai_quiz_service.dart';
import 'package:kana_trainer/data/ai/content_expansion_service.dart';
import 'package:kana_trainer/data/storage/backup_service.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/data/storage/secure_store.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/logic/expansion_policy.dart';
import 'package:kana_trainer/domain/repositories/ai_client.dart';
import 'package:kana_trainer/features/expansion/expansion_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';

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

  test('未見過不足 → 生成並入池、lastAdded、批數 +1', () async {
    final fake = FakeAiClient(_payload);
    final c = makeContainer(fake);
    await c
        .read(expansionProvider.notifier)
        .maybeExpandVocab(VocabTopic.travel, unseenOverride: 0);
    expect(fake.calls, 1);
    expect(c.read(expansionProvider).todayCount, 1);
    expect(c.read(expansionProvider).lastAdded, 1);
    expect(c.read(expansionProvider).status, ExpansionStatus.done);
    expect(c.read(dynamicContentStoreProvider).vocab().single.jp, '搭乗券');
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

  test('設定關閉 autoExpand → 不呼叫', () async {
    final fake = FakeAiClient(_payload);
    final c = makeContainer(fake);
    c
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(autoExpand: false));
    await c
        .read(expansionProvider.notifier)
        .maybeExpandVocab(VocabTopic.travel, unseenOverride: 0);
    expect(fake.calls, 0);
  });

  test('每日批數封頂、跨日重置', () async {
    final fake = FakeAiClient(_payload);
    final c = makeContainer(fake);
    final n = c.read(expansionProvider.notifier);
    for (var i = 0; i < ExpansionPolicy.dailyLimit + 2; i++) {
      await n.maybeExpandVocab(VocabTopic.travel, unseenOverride: 0);
    }
    expect(fake.calls, ExpansionPolicy.dailyLimit);
    StatsNotifier.today = () => '2026-07-15';
    await n.maybeExpandVocab(VocabTopic.travel, unseenOverride: 0);
    expect(fake.calls, ExpansionPolicy.dailyLimit + 1);
    expect(c.read(expansionProvider).todayCount, 1);
  });

  test('動態池進備份、日計數不進', () {
    expect(BackupService.backupKeys, contains('dyn_vocab'));
    expect(BackupService.backupKeys, contains('dyn_sentences'));
    expect(BackupService.backupKeys, contains('dyn_grammar_quiz'));
    expect(BackupService.backupKeys, contains('dyn_blacklist'));
    expect(
        BackupService.backupKeys, isNot(contains(ExpansionNotifier.dailyKey)));
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
