import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';

/// 一天一筆的詞彙量快照。
class VocabSnapshot {
  final int learned; // 熟練度 ≥4 的單字數
  final int total; // 池內總單字數（靜態+動態）

  const VocabSnapshot({required this.learned, required this.total});
}

/// 詞彙量歷史（成長曲線資料源）。
/// prefs `vocab_history`：{"yyyy-MM-dd": [learned, total], ...}，進備份。
/// 觸發點：MainShell 啟動 + 詞彙量頁開啟（App 有開就有點，缺日不補）。
class VocabHistoryNotifier extends Notifier<Map<String, VocabSnapshot>> {
  static const storageKey = 'vocab_history';

  @override
  Map<String, VocabSnapshot> build() {
    final raw = ref.read(keyValueStoreProvider).getString(storageKey);
    if (raw == null) return {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in json.entries)
          if (e.value is List && (e.value as List).length == 2)
            e.key: VocabSnapshot(
              learned: (e.value as List)[0] as int,
              total: (e.value as List)[1] as int,
            ),
      };
    } catch (_) {
      return {};
    }
  }

  /// 記錄今日快照（同日覆寫）。
  void snapshot() {
    final mastery = ref.read(masteryProvider);
    final learned = mastery.entries
        .where((e) => e.key.startsWith('v_') && e.value >= 4)
        .length;
    final total = ref.read(contentRepositoryProvider).vocab().length;
    state = {
      ...state,
      StatsNotifier.today(): VocabSnapshot(learned: learned, total: total),
    };
    ref.read(keyValueStoreProvider).setString(
          storageKey,
          jsonEncode({
            for (final e in state.entries) e.key: [e.value.learned, e.value.total],
          }),
        );
  }

  /// 本週新學：今日已學會 − 7 天前（往前找最近一筆）已學會。無基準點回 0。
  int weeklyGained() {
    final today = StatsNotifier.today();
    final current = state[today];
    if (current == null) return 0;
    final cutoff = _addDays(today, -7);
    // 取 ≤ cutoff 的最近日期；沒有就取最早一筆（安裝未滿一週）
    final past = state.keys.where((d) => d != today).toList()..sort();
    if (past.isEmpty) return 0;
    final base = past.lastWhere((d) => d.compareTo(cutoff) <= 0,
        orElse: () => past.first);
    return (current.learned - state[base]!.learned).clamp(0, 1 << 31);
  }

  static String _addDays(String date, int days) {
    final d = DateTime.parse(date).add(Duration(days: days));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

final vocabHistoryProvider =
    NotifierProvider<VocabHistoryNotifier, Map<String, VocabSnapshot>>(
        VocabHistoryNotifier.new);
