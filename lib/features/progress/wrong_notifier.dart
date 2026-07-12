import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/storage/prefs_store.dart';

/// 錯題紀錄：key = 題目 key（假名字元 / 單字 `v_<jp>`），value = 答錯次數。
/// storage key 參數化：假名與單字各自獨立一本錯題本。
class WrongNotifier extends Notifier<Map<String, int>> {
  final String storageKey;

  WrongNotifier(this.storageKey);

  @override
  Map<String, int> build() {
    final raw = ref.read(keyValueStoreProvider).getString(storageKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  void add(String key) {
    state = {...state, key: (state[key] ?? 0) + 1};
    _save();
  }

  /// 錯題複習中答對：錯誤次數 -1，歸零移出錯題本。
  void resolve(String key) {
    final cur = state[key];
    if (cur == null) return;
    final next = Map.of(state);
    if (cur <= 1) {
      next.remove(key);
    } else {
      next[key] = cur - 1;
    }
    state = next;
    _save();
  }

  void remove(String key) {
    if (!state.containsKey(key)) return;
    state = Map.of(state)..remove(key);
    _save();
  }

  void clear() {
    state = {};
    _save();
  }

  void _save() {
    ref.read(keyValueStoreProvider).setString(storageKey, jsonEncode(state));
  }
}

/// 假名錯題本。
final wrongProvider = NotifierProvider<WrongNotifier, Map<String, int>>(
  () => WrongNotifier('wrong'),
);

/// 單字錯題本（M1）。
final vocabWrongProvider = NotifierProvider<WrongNotifier, Map<String, int>>(
  () => WrongNotifier('vocab_wrong'),
);

/// 句子錯題本（M3）。
final sentenceWrongProvider =
    NotifierProvider<WrongNotifier, Map<String, int>>(
  () => WrongNotifier('sentence_wrong'),
);
