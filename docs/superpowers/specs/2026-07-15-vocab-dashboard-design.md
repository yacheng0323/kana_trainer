# 詞彙量成長儀表板 設計

> 2026-07-15。使用者核准：池子在長但看不到成長曲線。熱力圖管「有沒有練」，
> 這頁管「有沒有變強」。

## 1. 目標

- 「我的」tab 新入口「詞彙量」→ `VocabStatsPage`
- 頂部大數字：池內總詞彙、已學會（熟練度≥4）、學習中（1-3）、未見過（0）
- 30 天雙線成長曲線：已學會數 vs 池內總數（需時間序列 → 每日快照）
- 7 主題進度條：已學會 X / 池內 Y
- 本週新學 N 字（今日已學會 − 7 天前快照已學會）

## 2. 非目標

- 句子/文法的成長頁（先做單字，模式可複製）
- 快照回填（曲線從安裝本版起累積）
- 圖表套件（自繪 CustomPaint，同熱力圖做法，零依賴）

## 3. 設計

### VocabHistoryNotifier（features/progress/）

- prefs key `vocab_history`：`{"yyyy-MM-dd": [learned, total], ...}`
- `snapshot()`：learned = mastery 中 `v_` 開頭且值 ≥4 的數量；
  total = `ContentRepository.vocab().length`；寫入今日（同日覆寫）
- 觸發：MainShell initState（App 每次開啟記一點）+ VocabStatsPage 開啟
- 日期用 `StatsNotifier.today()`（測試可注入慣例）
- 進備份（`vocab_history`）

### GrowthChart（features/stats/widgets/）

- CustomPaint 折線：輸入 `List<(String date, int learned, int total)>`
  （近 30 天、按日期排序）
- 兩條線：total（金）、learned（綠）；右端標當前值；資料 <2 點顯示佔位文案

### VocabStatsPage（features/stats/）

- 開頁先 `snapshot()`
- 區塊：大數字 4 格 → 成長曲線卡 → 本週新學 → 主題進度條（LinearProgress 風格，
  2c 邊框卡片）

## 4. 測試

- notifier：snapshot 寫入/同日覆寫/只算 `v_` key/persist；backupKeys 含 vocab_history
- 曲線資料選取 helper：近 30 天排序、缺日不補
- page widget：大數字正確（含動態字）、主題列 7 行、本週新學計算
