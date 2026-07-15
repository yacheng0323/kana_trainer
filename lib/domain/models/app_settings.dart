/// 假名作答方式：4 選 1（預設，設計稿 2c）或鍵盤輸入羅馬拼音。
enum AnswerMode { choice, input }

/// 單字題型（M2）。
enum VocabMode {
  jpZh('日 → 中'),
  zhJp('中 → 日'),
  reading('讀音輸入');

  final String label;
  const VocabMode(this.label);
}

/// App 設定。
class Settings {
  final AnswerMode answerMode; // 假名作答方式（預設選擇題）
  final VocabMode vocabMode; // 單字題型（預設日→中）
  final int dailyGoal; // 每日目標題數
  final bool autoNext; // 答對後自動下一題
  final bool caseSensitive; // 區分大小寫（僅輸入模式，預設不區分）
  final bool showHint; // 顯示提示按鈕（僅輸入模式，首字母）
  final bool sound; // 音效/震動回饋
  final bool romajiHint; // 題目下方直接顯示羅馬拼音（僅輸入模式）
  final bool reminderEnabled; // 每日提醒
  final int reminderHour; // 提醒時間（24h）
  final int reminderMinute;
  final bool autoExpand; // AI 自動擴充題庫
  final int jlptLevel; // 目前練習等級（5..1，預設 N5）

  const Settings({
    this.answerMode = AnswerMode.choice,
    this.vocabMode = VocabMode.jpZh,
    this.dailyGoal = 20,
    this.autoNext = true,
    this.caseSensitive = false,
    this.showHint = true,
    this.sound = true,
    this.romajiHint = false,
    this.reminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.autoExpand = true,
    this.jlptLevel = 5,
  });

  Map<String, dynamic> toJson() => {
        'answerMode': answerMode.name,
        'vocabMode': vocabMode.name,
        'dailyGoal': dailyGoal,
        'autoNext': autoNext,
        'caseSensitive': caseSensitive,
        'showHint': showHint,
        'sound': sound,
        'romajiHint': romajiHint,
        'reminderEnabled': reminderEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'autoExpand': autoExpand,
        'jlptLevel': jlptLevel,
      };

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        answerMode: AnswerMode.values.asNameMap()[json['answerMode']] ??
            AnswerMode.choice,
        vocabMode:
            VocabMode.values.asNameMap()[json['vocabMode']] ?? VocabMode.jpZh,
        dailyGoal: json['dailyGoal'] as int? ?? 20,
        autoNext: json['autoNext'] as bool? ?? true,
        caseSensitive: json['caseSensitive'] as bool? ?? false,
        showHint: json['showHint'] as bool? ?? true,
        sound: json['sound'] as bool? ?? true,
        romajiHint: json['romajiHint'] as bool? ?? false,
        reminderEnabled: json['reminderEnabled'] as bool? ?? false,
        reminderHour: json['reminderHour'] as int? ?? 20,
        reminderMinute: json['reminderMinute'] as int? ?? 0,
        autoExpand: json['autoExpand'] as bool? ?? true,
        jlptLevel: (json['jlptLevel'] as int? ?? 5).clamp(1, 5),
      );

  Settings copyWith({
    AnswerMode? answerMode,
    VocabMode? vocabMode,
    int? dailyGoal,
    bool? autoNext,
    bool? caseSensitive,
    bool? showHint,
    bool? sound,
    bool? romajiHint,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? autoExpand,
    int? jlptLevel,
  }) =>
      Settings(
        answerMode: answerMode ?? this.answerMode,
        vocabMode: vocabMode ?? this.vocabMode,
        dailyGoal: dailyGoal ?? this.dailyGoal,
        autoNext: autoNext ?? this.autoNext,
        caseSensitive: caseSensitive ?? this.caseSensitive,
        showHint: showHint ?? this.showHint,
        sound: sound ?? this.sound,
        romajiHint: romajiHint ?? this.romajiHint,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        autoExpand: autoExpand ?? this.autoExpand,
        jlptLevel: jlptLevel ?? this.jlptLevel,
      );
}
