import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kana_trainer/data/ai/ai_analysis_service.dart';
import 'package:kana_trainer/data/ai/ai_chat_service.dart';
import 'package:kana_trainer/data/ai/claude_client.dart';
import 'package:kana_trainer/data/static/verb_data.dart';
import 'package:kana_trainer/domain/entities/verb.dart';
import 'package:kana_trainer/data/storage/prefs_provider.dart';
import 'package:kana_trainer/features/practice/widgets/quiz_widgets.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/verb/verb_drill_page.dart';
import 'package:kana_trainer/features/verb/verb_quiz_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _apiResponse(Map<String, dynamic> payload) => jsonEncode({
      'content': [
        {'type': 'text', 'text': jsonEncode(payload)},
      ],
    });

MockClient _mockOk(Map<String, dynamic> payload) => MockClient(
      (_) async => http.Response(
        _apiResponse(payload),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StatsNotifier.today = () => '2026-07-11';
  });

  group('verb_data', () {
    test('41 個動詞、dict 唯一、四形皆非空', () {
      expect(allVerbs.length, 41);
      expect(allVerbs.map((v) => v.dict).toSet().length, 41);
      for (final v in allVerbs) {
        for (final f in VerbForm.values) {
          expect(v.formOf(f), isNotEmpty, reason: '${v.dict} ${f.label}');
        }
      }
    });

    test('抽查變化正確性（含例外與不規則）', () {
      Verb find(String dict) => allVerbs.firstWhere((v) => v.dict == dict);
      expect(find('行く').te, '行って'); // 例外
      expect(find('行く').ta, '行った');
      expect(find('書く').te, '書いて');
      expect(find('泳ぐ').te, '泳いで');
      expect(find('飲む').te, '飲んで');
      expect(find('待つ').te, '待って');
      expect(find('話す').te, '話して');
      expect(find('食べる').nai, '食べない');
      expect(find('来る').nai, '来ない');
      expect(find('する').ta, 'した');
      expect(find('帰る').masu, '帰ります'); // 帰る是五段
      expect(find('帰る').group, VerbGroup.godan);
    });
  });

  group('VerbQuizBuilder', () {
    test('10 題、指定形、4 個不重複選項含正解', () {
      for (final form in VerbForm.values) {
        final qs = VerbQuizBuilder.build(form: form, rng: Random(3));
        expect(qs.length, 10);
        for (final q in qs) {
          expect(q.form, form);
          expect(q.options.length, 4);
          expect(q.options.toSet().length, 4);
          expect(q.options[q.correctIndex], q.verb.formOf(form));
        }
      }
    });

    test('混合模式題目動詞不重複', () {
      final qs = VerbQuizBuilder.build(rng: Random(7));
      expect(qs.map((q) => q.verb.dict).toSet().length, qs.length);
    });
  });

  group('VerbDrillPage', () {
    testWidgets('選題型 → 作答 → 檢討顯示全部變化', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: VerbDrillPage()),
        ),
      );
      await tester.tap(find.text('て形'));
      await tester.pump();
      await tester.tap(find.text('開始訓練'));
      await tester.pump();

      expect(find.textContaining('第 1/10 題'), findsOneWidget);
      expect(find.text('て形？'), findsOneWidget);
      // 點任一選項 → 出現四形檢討列
      final option = find.descendant(
        of: find.byType(OptionButton),
        matching: find.byType(Text),
      );
      await tester.ensureVisible(option.first);
      await tester.tap(option.first);
      await tester.pump();
      expect(find.textContaining('ます形'), findsOneWidget);
      expect(find.text('下一題'), findsOneWidget);
    });
  });

  group('AiChatService', () {
    test('history 正確映射 roles、解析回覆', () async {
      late Map<String, dynamic> sent;
      final service = AiChatService(
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            _apiResponse({
              'reply': 'いらっしゃいませ。',
              'translation': '歡迎光臨。',
              'correction': '',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final reply = await service.send(
        apiKey: 'sk-ant-test',
        scenario: '餐廳點餐',
        history: [
          (isUser: true, text: 'こんにちは。'),
          (isUser: false, text: 'いらっしゃいませ。'),
          (isUser: true, text: 'メニューをください。'),
        ],
      );
      expect(reply.reply, 'いらっしゃいませ。');
      expect(reply.translation, '歡迎光臨。');
      expect(reply.correction, isEmpty);
      final messages = sent['messages'] as List;
      expect(messages.length, 3);
      expect((messages[0] as Map)['role'], 'user');
      expect((messages[1] as Map)['role'], 'assistant');
      expect((sent['system'] as String), contains('餐廳點餐'));
    });

    test('API 錯誤轉 AiException', () async {
      final service = AiChatService(
        client: MockClient((_) async => http.Response('{}', 429)),
      );
      expect(
        () => service.send(apiKey: 'sk', scenario: 'x', history: [
          (isUser: true, text: 'hi'),
        ]),
        throwsA(isA<AiException>()),
      );
    });
  });

  group('AiAnalysisService', () {
    test('解析報告', () async {
      final service = AiAnalysisService(
        client: _mockOk({
          'summary': '整體不錯。',
          'weakPoints': ['拗音混淆', 'て形不熟'],
          'suggestions': ['多練拗音', '動詞變化訓練'],
        }),
      );
      final report = await service.analyze(
        apiKey: 'sk-ant-test',
        learnerData: '總答題 100…',
      );
      expect(report.summary, '整體不錯。');
      expect(report.weakPoints.length, 2);
      expect(report.suggestions, contains('動詞變化訓練'));
    });

    test('round-trip toJson/fromJson（快取用）', () {
      const report = WeaknessReport(
        summary: 's',
        weakPoints: ['a'],
        suggestions: ['b'],
      );
      final restored = WeaknessReport.fromJson(
        jsonDecode(jsonEncode(report.toJson())) as Map<String, dynamic>,
      );
      expect(restored.summary, 's');
      expect(restored.weakPoints, ['a']);
    });
  });
}
