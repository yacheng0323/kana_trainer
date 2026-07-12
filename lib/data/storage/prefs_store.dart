import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kana_trainer/data/storage/prefs_provider.dart';
import 'package:kana_trainer/domain/repositories/key_value_store.dart';

export 'package:kana_trainer/domain/repositories/key_value_store.dart';

/// [KeyValueStore] 的 SharedPreferences 實作。
class SharedPrefsStore implements KeyValueStore {
  final SharedPreferences _prefs;

  SharedPrefsStore(this._prefs);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
}

/// ViewModel 層一律依賴這個抽象 provider，不直接碰 SharedPreferences。
/// 預設由 prefsProvider 組出實作，因此測試 override prefsProvider 即生效；
/// 也可直接 override 成 InMemoryKeyValueStore。
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => SharedPrefsStore(ref.read(prefsProvider)),
);
