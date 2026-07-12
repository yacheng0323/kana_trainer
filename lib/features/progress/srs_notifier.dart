import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/storage/prefs_store.dart';

/// SRS 間隔複習：key（`v_<jp>` 等）→ 下次到期時間 epoch millis。
/// 間隔依熟練度：0=立即、1=1天、2=3天、3=7天、4=14天、5=30天；答錯歸零立即到期。
class SrsNotifier extends Notifier<Map<String, int>> {
  static const storageKey = 'srs';

  /// 測試可注入固定時間。
  static DateTime Function() now = DateTime.now;

  static const _intervalDays = [0, 1, 3, 7, 14, 30];

  @override
  Map<String, int> build() {
    final raw = ref.read(keyValueStoreProvider).getString(storageKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  /// 作答後排程：依作答後熟練度（0..5）排下次到期。
  void schedule(String key, int masteryAfter, {required bool correct}) {
    final days = correct ? _intervalDays[masteryAfter.clamp(0, 5)] : 0;
    final due = now().add(Duration(days: days)).millisecondsSinceEpoch;
    state = {...state, key: due};
    ref.read(keyValueStoreProvider).setString(storageKey, jsonEncode(state));
  }

  /// 目前到期（待複習）的 key，僅限出現在 [candidates] 的。
  Set<String> dueKeys(Iterable<String> candidates) {
    final t = now().millisecondsSinceEpoch;
    final set = <String>{};
    for (final k in candidates) {
      final due = state[k];
      if (due != null && due <= t) set.add(k);
    }
    return set;
  }
}

final srsProvider =
    NotifierProvider<SrsNotifier, Map<String, int>>(SrsNotifier.new);
