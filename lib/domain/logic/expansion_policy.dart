/// 題庫補貨決策（純函式，成本控制的單一事實來源）。
class ExpansionPolicy {
  const ExpansionPolicy._();

  /// 範圍內「未見過」（熟練度 0）項目低於此值時觸發補貨。
  static const unseenThreshold = 5;

  /// 每日 AI 生成批數上限（一批一次 API 呼叫）。
  static const dailyLimit = 5;

  static bool shouldExpand({
    required bool enabled,
    required int unseenCount,
    required int dailyCount,
  }) =>
      enabled && unseenCount < unseenThreshold && dailyCount < dailyLimit;
}
