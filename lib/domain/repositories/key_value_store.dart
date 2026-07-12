/// 鍵值儲存抽象（Model 層對外的唯一儲存介面）。
/// 正式實作：SharedPrefsStore（data/storage/prefs_store.dart）；
/// 測試可用 [InMemoryKeyValueStore]，不需要 SharedPreferences mock。
abstract class KeyValueStore {
  String? getString(String key);

  Future<void> setString(String key, String value);
}

/// 純記憶體實作（單元測試用）。
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _map = {};

  @override
  String? getString(String key) => _map[key];

  @override
  Future<void> setString(String key, String value) async {
    _map[key] = value;
  }
}
