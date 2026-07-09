import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/prefs_provider.dart';

/// 每個假名的熟練度（0..5），key = 假名字元。
/// 答對 +1、答錯 -1，出題權重 = 6 - 熟練度。
class MasteryNotifier extends Notifier<Map<String, int>> {
  static const storageKey = 'mastery';

  @override
  Map<String, int> build() {
    final raw = ref.read(prefsProvider).getString(storageKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  void record(String kana, {required bool correct}) {
    final next = ((state[kana] ?? 0) + (correct ? 1 : -1)).clamp(0, 5);
    state = {...state, kana: next};
    ref.read(prefsProvider).setString(storageKey, jsonEncode(state));
  }

  /// 平均熟練度 0..1（首頁進度用）。
  double progressOf(Iterable<String> kanaKeys) {
    if (kanaKeys.isEmpty) return 0;
    var sum = 0;
    var n = 0;
    for (final k in kanaKeys) {
      sum += state[k] ?? 0;
      n++;
    }
    return sum / (n * 5);
  }
}

final masteryProvider =
    NotifierProvider<MasteryNotifier, Map<String, int>>(MasteryNotifier.new);
