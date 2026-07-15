import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kana_trainer/data/ai/ai_quiz_service.dart';
import 'package:kana_trainer/data/storage/backup_service.dart';
import 'package:kana_trainer/data/storage/prefs_provider.dart';
import 'package:kana_trainer/data/storage/secure_store.dart';
import 'package:kana_trainer/features/ai_quiz/ai_quiz_page.dart';
import 'package:kana_trainer/features/practice/widgets/quiz_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 假 API 回應：Claude messages API 格式，content[0].text 為 JSON payload。
String _apiResponse(List<Map<String, dynamic>> questions) => jsonEncode({
      'content': [
        {'type': 'text', 'text': jsonEncode({'questions': questions})},
      ],
    });

final _sampleQuestions = List.generate(
  10,
  (i) => {
    'question': '「駅$i」是什麼意思？',
    'options': ['車站$i', '公車$i', '機場$i', '碼頭$i'],
    'correctIndex': 0,
    'note': '駅（えき）= 車站',
  },
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AiQuizService', () {
    test('成功解析 10 題', () async {
      final service = AiQuizService(
        client: MockClient((request) async {
          expect(request.url.path, '/v1/messages');
          expect(request.headers['x-api-key'], 'sk-ant-test');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['model'], isNotEmpty);
          expect(body['output_config'], isNotNull);
          return http.Response(
            _apiResponse(_sampleQuestions),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final questions =
          await service.generate(apiKey: 'sk-ant-test', topic: '交通');
      expect(questions.length, 10);
      expect(questions.first.options.length, 4);
      expect(questions.first.correctIndex, 0);
    });

    test('缺 API Key 丟例外', () async {
      final service = AiQuizService(
        client: MockClient((_) async => http.Response('', 200)),
      );
      expect(
        () => service.generate(apiKey: '', topic: '交通'),
        throwsA(isA<AiQuizException>()),
      );
    });

    test('401 → Key 無效訊息；429 → 稍後再試；500 → 服務異常', () async {
      Future<void> check(int status, String contains) async {
        final service = AiQuizService(
          client: MockClient((_) async => http.Response('{}', status)),
        );
        try {
          await service.generate(apiKey: 'sk-ant-test', topic: 'x');
          fail('should throw');
        } on AiQuizException catch (e) {
          expect(e.message, stringContainsInOrder([contains]));
        }
      }

      await check(401, 'API Key 無效');
      await check(429, '稍後再試');
      await check(500, '暫時無法使用');
    });

    test('格式異常（選項重複/超界）丟例外', () async {
      final bad = [
        {
          'question': 'q',
          'options': ['a', 'a', 'b', 'c'], // 重複
          'correctIndex': 0,
          'note': '',
        },
      ];
      final service = AiQuizService(
        client: MockClient(
          (_) async => http.Response(
            _apiResponse(bad),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      expect(
        () => service.generate(apiKey: 'sk-ant-test', topic: 'x'),
        throwsA(isA<AiQuizException>()),
      );
    });
  });

  group('API Key 儲存', () {
    test('存加密儲存、不落 prefs 明文、不在備份範圍', () async {
      final prefs = await SharedPreferences.getInstance();
      final secure = InMemoryKeyValueStore();
      final c = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(secure),
        ],
      );
      addTearDown(c.dispose);
      c.read(apiKeyProvider.notifier).set('  sk-ant-secret  ');
      expect(c.read(apiKeyProvider), 'sk-ant-secret'); // trim
      expect(secure.getString(ApiKeyNotifier.storageKey), 'sk-ant-secret');
      // 安全：不落 SharedPreferences 明文
      expect(prefs.getString(ApiKeyNotifier.storageKey), isNull);
      // 安全：備份匯出不得包含 API Key
      expect(
        BackupService.backupKeys.contains(ApiKeyNotifier.storageKey),
        isFalse,
      );
      expect(BackupService.export(prefs).contains('sk-ant-secret'), isFalse);
    });
  });

  group('AiQuizPage', () {
    Future<ProviderContainer> pump(
      WidgetTester tester, {
      String apiKey = 'sk-ant-test',
      MockClient? client,
    }) async {
      final prefs = await SharedPreferences.getInstance();
      final secure = InMemoryKeyValueStore();
      if (apiKey.isNotEmpty) {
        await secure.setString(ApiKeyNotifier.storageKey, apiKey);
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            secureStoreProvider.overrideWithValue(secure),
            if (client != null)
              aiQuizServiceProvider
                  .overrideWithValue(AiQuizService(client: client)),
          ],
          child: const MaterialApp(home: AiQuizPage()),
        ),
      );
      return ProviderScope.containerOf(
        tester.element(find.byType(AiQuizPage)),
      );
    }

    testWidgets('無 Key 時鎖定並引導設定', (tester) async {
      await pump(tester, apiKey: '');
      expect(find.text('前往設定 API Key'), findsOneWidget);
      final startButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '開始出題'),
      );
      expect(startButton.onPressed, isNull); // 停用
    });

    testWidgets('出題 → 作答 → 檢討 → 下一題；題組寫入快取', (tester) async {
      final container = await pump(
        tester,
        client: MockClient(
          (_) async => http.Response(
            _apiResponse(_sampleQuestions),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await tester.tap(find.text('開始出題'));
      await tester.pump(); // loading
      await tester.pump(const Duration(seconds: 1)); // flush async generate
      await tester.pump(const Duration(seconds: 1));

      // 第一題出現
      expect(find.textContaining('第 1/10 題'), findsOneWidget);
      final correctOption = find.descendant(
        of: find.byType(OptionButton),
        matching: find.text('車站0'),
      );
      await tester.ensureVisible(correctOption);
      await tester.tap(correctOption);
      await tester.pump();

      // 檢討與下一題
      expect(find.textContaining('駅（えき）'), findsOneWidget);
      await tester.ensureVisible(find.text('下一題'));
      await tester.tap(find.text('下一題'));
      await tester.pump();
      expect(find.textContaining('第 2/10 題'), findsOneWidget);

      // 快取已寫入
      final prefs = container.read(prefsProvider);
      expect(prefs.getString('ai_cache_n5_旅遊'), isNotNull); // 快取按等級分 key
    });

    testWidgets('API 失敗 → 顯示錯誤並回主題選擇', (tester) async {
      await pump(
        tester,
        client: MockClient((_) async => http.Response('{}', 401)),
      );
      await tester.tap(find.text('開始出題'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('API Key 無效'), findsOneWidget);
      expect(find.text('開始出題'), findsOneWidget); // 回到選擇畫面
    });
  });
}
