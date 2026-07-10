import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/prefs_provider.dart';
import '../settings/settings_notifier.dart';

/// 累計統計。今日計數以日期字串滾動，跨日自動歸零。
/// M2 新增：每日目標達標連續天數（goalStreakDays）。
class Stats {
  final int total;
  final int correct;
  final int bestStreak;
  final int currentStreak;
  final String todayDate; // yyyy-MM-dd
  final int todayTotal;
  final int todayCorrect;
  final int goalStreakDays; // 連續達成每日目標天數
  final String lastGoalDate; // 最後一次達標日期

  const Stats({
    this.total = 0,
    this.correct = 0,
    this.bestStreak = 0,
    this.currentStreak = 0,
    this.todayDate = '',
    this.todayTotal = 0,
    this.todayCorrect = 0,
    this.goalStreakDays = 0,
    this.lastGoalDate = '',
  });

  int get wrong => total - correct;
  double get accuracy => total == 0 ? 0 : correct / total;
  double get todayAccuracy => todayTotal == 0 ? 0 : todayCorrect / todayTotal;

  Map<String, dynamic> toJson() => {
        'total': total,
        'correct': correct,
        'bestStreak': bestStreak,
        'currentStreak': currentStreak,
        'todayDate': todayDate,
        'todayTotal': todayTotal,
        'todayCorrect': todayCorrect,
        'goalStreakDays': goalStreakDays,
        'lastGoalDate': lastGoalDate,
      };

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
        total: json['total'] as int? ?? 0,
        correct: json['correct'] as int? ?? 0,
        bestStreak: json['bestStreak'] as int? ?? 0,
        currentStreak: json['currentStreak'] as int? ?? 0,
        todayDate: json['todayDate'] as String? ?? '',
        todayTotal: json['todayTotal'] as int? ?? 0,
        todayCorrect: json['todayCorrect'] as int? ?? 0,
        goalStreakDays: json['goalStreakDays'] as int? ?? 0,
        lastGoalDate: json['lastGoalDate'] as String? ?? '',
      );

  Stats copyWith({
    int? total,
    int? correct,
    int? bestStreak,
    int? currentStreak,
    String? todayDate,
    int? todayTotal,
    int? todayCorrect,
    int? goalStreakDays,
    String? lastGoalDate,
  }) =>
      Stats(
        total: total ?? this.total,
        correct: correct ?? this.correct,
        bestStreak: bestStreak ?? this.bestStreak,
        currentStreak: currentStreak ?? this.currentStreak,
        todayDate: todayDate ?? this.todayDate,
        todayTotal: todayTotal ?? this.todayTotal,
        todayCorrect: todayCorrect ?? this.todayCorrect,
        goalStreakDays: goalStreakDays ?? this.goalStreakDays,
        lastGoalDate: lastGoalDate ?? this.lastGoalDate,
      );
}

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
    final raw = ref.read(prefsProvider).getString(storageKey);
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
    ref.read(prefsProvider).setString(storageKey, jsonEncode(s.toJson()));
  }
}

final statsProvider = NotifierProvider<StatsNotifier, Stats>(StatsNotifier.new);
