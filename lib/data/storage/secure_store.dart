import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kana_trainer/domain/repositories/key_value_store.dart';

export 'package:kana_trainer/domain/repositories/key_value_store.dart';

/// 需要加密儲存的 key（進 Android Keystore，不落 SharedPreferences 明文）。
const secureKeys = ['claude_api_key'];

/// [KeyValueStore] 的加密實作：介面是同步讀，因此啟動時 [load] 先把
/// [secureKeys] 預載進記憶體快取；寫入 write-through 到底層加密儲存。
/// 底層以 read/write callback 注入（正式為 flutter_secure_storage，
/// 測試可注入純函式，不需要平台 plugin）。
class SecureStore implements KeyValueStore {
  SecureStore._(this._write, this._cache);

  final Future<void> Function(String key, String value) _write;
  final Map<String, String> _cache;

  @override
  String? getString(String key) => _cache[key];

  @override
  Future<void> setString(String key, String value) {
    _cache[key] = value;
    return _write(key, value);
  }

  /// 預載 [keys]。若 SharedPreferences 還留有舊版明文值，
  /// 搬進加密儲存後把明文刪掉（一次性 migration）。
  static Future<SecureStore> load({
    required Future<String?> Function(String key) read,
    required Future<void> Function(String key, String value) write,
    required SharedPreferences prefs,
    List<String> keys = secureKeys,
  }) async {
    final cache = <String, String>{};
    for (final key in keys) {
      final legacy = prefs.getString(key);
      if (legacy != null) {
        await write(key, legacy);
        await prefs.remove(key);
        cache[key] = legacy;
      } else {
        final v = await read(key);
        if (v != null) cache[key] = v;
      }
    }
    return SecureStore._(write, cache);
  }
}

/// 機敏值（API Key）一律走這個 provider，不走 keyValueStoreProvider。
/// 正式環境由 main() override 成 [SecureStore]；
/// 測試預設 InMemory，不觸平台 plugin。
final secureStoreProvider = Provider<KeyValueStore>(
  (_) => InMemoryKeyValueStore(),
);
