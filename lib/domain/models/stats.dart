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
