import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/storage/backup_service.dart';
import 'package:kana_trainer/data/storage/secure_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SecureStore', () {
    test('load 搬移 prefs 舊明文 → 加密儲存 + 刪明文', () async {
      SharedPreferences.setMockInitialValues(
        {'claude_api_key': 'sk-ant-legacy'},
      );
      final prefs = await SharedPreferences.getInstance();
      final written = <String, String>{};

      final store = await SecureStore.load(
        read: (key) async => written[key],
        write: (key, value) async => written[key] = value,
        prefs: prefs,
      );

      expect(store.getString('claude_api_key'), 'sk-ant-legacy');
      expect(written['claude_api_key'], 'sk-ant-legacy'); // 已寫入加密儲存
      expect(prefs.getString('claude_api_key'), isNull); // 明文已刪
    });

    test('無舊明文時從加密儲存讀取', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = await SecureStore.load(
        read: (key) async => key == 'claude_api_key' ? 'sk-ant-stored' : null,
        write: (_, _) async => fail('不該寫入'),
        prefs: prefs,
      );
      expect(store.getString('claude_api_key'), 'sk-ant-stored');
    });

    test('setString write-through：快取即讀 + 底層有寫', () async {
      final prefs = await SharedPreferences.getInstance();
      final written = <String, String>{};
      final store = await SecureStore.load(
        read: (_) async => null,
        write: (key, value) async => written[key] = value,
        prefs: prefs,
      );
      await store.setString('claude_api_key', 'sk-ant-new');
      expect(store.getString('claude_api_key'), 'sk-ant-new');
      expect(written['claude_api_key'], 'sk-ant-new');
    });
  });

  group('BackupService 版本檢查', () {
    test('無 version 欄位視為 v1，可匯入', () async {
      final prefs = await SharedPreferences.getInstance();
      final legacy = jsonEncode({
        'app': 'kana_trainer',
        'data': {'mastery': '{"か":3}'},
      });
      final count = await BackupService.import(prefs, legacy);
      expect(count, 1);
      expect(prefs.getString('mastery'), '{"か":3}');
    });

    test('版本過新拒絕匯入且不寫任何資料', () async {
      final prefs = await SharedPreferences.getInstance();
      final tooNew = jsonEncode({
        'app': 'kana_trainer',
        'version': BackupService.version + 1,
        'data': {'mastery': '{"か":3}'},
      });
      expect(
        () => BackupService.import(prefs, tooNew),
        throwsFormatException,
      );
      expect(prefs.getString('mastery'), isNull);
    });

    test('匯出檔帶目前版本，round-trip 匯入成功', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('stats', '{"total":9}');
      final exported = BackupService.export(prefs);
      final decoded = jsonDecode(exported) as Map<String, dynamic>;
      expect(decoded['version'], BackupService.version);

      await prefs.clear();
      final count = await BackupService.import(prefs, exported);
      expect(count, greaterThanOrEqualTo(1));
      expect(prefs.getString('stats'), '{"total":9}');
    });
  });
}
