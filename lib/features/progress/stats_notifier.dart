import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/prefs_provider.dart';

/// 累計統計。今日計數以日期字串滾動，跨日自動歸零。
class Stats {
  final int total;
  final int correct;
  final int bestStreak;
  final int currentStreak;
  final String todayDate; // yyyy-MM-dd
  final int todayTotal;
  final int todayCorrect;

  const Stats({
    this.total = 0,
    this.correct = 0,
    this.bestStreak = 0,
    this.currentStreak = 0,
    this.todayDate = '',
    this.todayTotal = 0,
    this.todayCorrect = 0,
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
      };

  factory Stats.fromJson(Map<String, dynamic> json) => Stats(
        total: json['total'] as int? ?? 0,
        correct: json['correct'] as int? ?? 0,
        bestStreak: json['bestStreak'] as int? ?? 0,
        currentStreak: json['currentStreak'] as int? ?? 0,
        todayDate: json['todayDate'] as String? ?? '',
        todayTotal: json['todayTotal'] as int? ?? 0,
        todayCorrect: json['todayCorrect'] as int? ?? 0,
      );

  Stats copyWith({
    int? total,
    int? correct,
    int? bestStreak,
    int? currentStreak,
    String? todayDate,
    int? todayTotal,
    int? todayCorrect,
  }) =>
      Stats(
        total: total ?? this.total,
        correct: correct ?? this.correct,
        bestStreak: bestStreak ?? this.bestStreak,
        currentStreak: currentStreak ?? this.currentStreak,
        todayDate: todayDate ?? this.todayDate,
        todayTotal: todayTotal ?? this.todayTotal,
        todayCorrect: todayCorrect ?? this.todayCorrect,
      );
}

class StatsNotifier extends Notifier<Stats> {
  static const storageKey = 'stats';

  /// 測試可注入固定日期。
  static String Function() today = _todayImpl;

  static String _todayImpl() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Stats build() {
    final raw = ref.read(prefsProvider).getString(storageKey);
    var stats =
        raw == null ? const Stats() : Stats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
    state = s;
    ref.read(prefsProvider).setString(storageKey, jsonEncode(s.toJson()));
  }
}

final statsProvider = NotifierProvider<StatsNotifier, Stats>(StatsNotifier.new);
