import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/storage/prefs_store.dart';

/// 每日答題數歷史：{'2026-07-10': 42, ...}，熱力圖資料來源。
/// 由 StatsNotifier.record 呼叫 increment（單一寫入點）。
class DailyHistoryNotifier extends Notifier<Map<String, int>> {
  static const storageKey = 'daily_history';

  @override
  Map<String, int> build() {
    final raw = ref.read(keyValueStoreProvider).getString(storageKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  void increment(String date) {
    state = {...state, date: (state[date] ?? 0) + 1};
    ref.read(keyValueStoreProvider).setString(storageKey, jsonEncode(state));
  }
}

final dailyHistoryProvider =
    NotifierProvider<DailyHistoryNotifier, Map<String, int>>(
  DailyHistoryNotifier.new,
);
