import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'daily_history_notifier.dart';
import 'package:kana_trainer/domain/models/stats.dart';
export 'package:kana_trainer/domain/models/stats.dart';

class StatsNotifier extends Notifier<Stats> {
  static const storageKey = 'stats';

  /// 測試可注入固定日期。
  static String Function() today = _todayImpl;

  static String _todayImpl() => _fmt(DateTime.now());

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static bool _isYesterday(String prev, String cur) {
    if (prev.isEmpty) return false;
    final p = DateTime.tryParse(prev);
    final c = DateTime.tryParse(cur);
    if (p == null || c == null) return false;
    return c.difference(p).inDays == 1;
  }

  @override
  Stats build() {
    final raw = ref.read(keyValueStoreProvider).getString(storageKey);
    var stats = raw == null
        ? const Stats()
        : Stats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _rollover(stats);
  }

  Stats _rollover(Stats stats) {
    final t = today();
    if (stats.todayDate != t) {
      stats = stats.copyWith(todayDate: t, todayTotal: 0, todayCorrect: 0);
    }
    return stats;
  }

  void record({required bool correct}) {
    var s = _rollover(state);
    final streak = correct ? s.currentStreak + 1 : 0;
    s = s.copyWith(
      total: s.total + 1,
      correct: s.correct + (correct ? 1 : 0),
      currentStreak: streak,
      bestStreak: streak > s.bestStreak ? streak : s.bestStreak,
      todayTotal: s.todayTotal + 1,
      todayCorrect: s.todayCorrect + (correct ? 1 : 0),
    );
    // 每日目標達標判定（首次跨越門檻時計連續天數）
    final goal = ref.read(settingsProvider).dailyGoal;
    if (s.todayTotal >= goal && s.lastGoalDate != s.todayDate) {
      final streakDays = _isYesterday(s.lastGoalDate, s.todayDate)
          ? s.goalStreakDays + 1
          : 1;
      s = s.copyWith(goalStreakDays: streakDays, lastGoalDate: s.todayDate);
    }
    state = s;
    ref.read(keyValueStoreProvider).setString(storageKey, jsonEncode(s.toJson()));
    // 熱力圖歷史（單一寫入點）
    ref.read(dailyHistoryProvider.notifier).increment(s.todayDate);
  }
}

final statsProvider = NotifierProvider<StatsNotifier, Stats>(StatsNotifier.new);
