/// 題庫補貨決策（純函式，成本控制的單一事實來源）。
class ExpansionPolicy {
  const ExpansionPolicy._();

  /// 範圍內「未見過」（熟練度 0）項目低於此值時觸發補貨。
  /// v2.6.2 調高：使用者要持續長詞彙量，池子要永遠領先練習進度。
  static const unseenThreshold = 10;

  /// 每日 AI 生成批數上限（一批一次 API 呼叫）。
  /// 20 批 ≈ 最多 $0.4/天（實際觸發遠低於此）。
  static const dailyLimit = 20;

  /// 範圍池最低題量：低於此值就補（v2.8.1 修：全新主題 15 字全是未見過
  /// → 舊條件永不觸發，使用者一直輪原始靜態題）。
  static const minPoolSize = 30;

  static bool shouldExpand({
    required bool enabled,
    required int unseenCount,
    required int dailyCount,
    int poolSize = minPoolSize,
  }) =>
      enabled &&
      dailyCount < dailyLimit &&
      (unseenCount < unseenThreshold || poolSize < minPoolSize);
}
