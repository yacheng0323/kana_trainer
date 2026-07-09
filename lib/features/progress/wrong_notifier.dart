import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/prefs_provider.dart';

/// 錯題紀錄：key = 假名字元，value = 答錯次數。
class WrongNotifier extends Notifier<Map<String, int>> {
  static const storageKey = 'wrong';

  @override
  Map<String, int> build() {
    final raw = ref.read(prefsProvider).getString(storageKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  void add(String kana) {
    state = {...state, kana: (state[kana] ?? 0) + 1};
    _save();
  }

  /// 錯題複習中答對：錯誤次數 -1，歸零移出錯題本。
  void resolve(String kana) {
    final cur = state[kana];
    if (cur == null) return;
    final next = Map.of(state);
    if (cur <= 1) {
      next.remove(kana);
    } else {
      next[kana] = cur - 1;
    }
    state = next;
    _save();
  }

  void remove(String kana) {
    if (!state.containsKey(kana)) return;
    state = Map.of(state)..remove(kana);
    _save();
  }

  void clear() {
    state = {};
    _save();
  }

  void _save() {
    ref.read(prefsProvider).setString(storageKey, jsonEncode(state));
  }
}

final wrongProvider =
    NotifierProvider<WrongNotifier, Map<String, int>>(WrongNotifier.new);
