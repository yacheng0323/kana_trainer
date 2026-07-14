# 題庫瀏覽器 + 爛題管理 / 句子機制補齊 設計

> 2026-07-15。使用者核准方向：①AI 生成內容無人審，需要瀏覽/刪除/防再生成；
> ②句子練習補齊 v2.6.2 單字already有的成長機制。

## 1. 目標

- 「我的題庫」頁：瀏覽全部單字/句子/文法題（靜態+動態），動態項可刪除
- 刪除 = 移出池 + 進黑名單（AI 再生成同 key 會被擋）
- 黑名單進備份（使用者的整理成果不可丟）
- 句子練習：freshWeight 12（新句優先）+ refreshPool（擴充即時併入）

## 2. 非目標

- 編輯內容（只刪不改；改 = 刪掉讓 AI 重生成）
- 刪除靜態內容（const 資料，UI 不提供刪除）
- 文法課 3 題 session 中途 refresh（session 太短沒意義）
- 手動新增單字

## 3. 設計

### DynamicContentStore 擴充

- 新 prefs key `dyn_blacklist`：JSON list of keys（`v_<jp>` / `s_<jp>` / `<lessonId>|<question>`）
- `_add`：黑名單內的 key 一律跳過（AI 重生成防線）
- `Future<void> remove(String key)`：從對應池移除 + 加黑名單 + 兩者持久化
- `BackupService.backupKeys` 加 `dyn_blacklist`

### LibraryPage（我的題庫）

- 入口：我的 tab「學習管理」區第三張 EntryCard「我的題庫」
- 三 tab（單字/句子/文法題），沿用錯題本頁 UI 模式
- 每列：主文字 + 副文字；動態項顯示「AI」badge + 刪除鈕（確認 dialog）
- 單字 tab 頂部搜尋框（比對 jp/reading/zh contains）
- 刪除後列表即時更新（watch repo 經 store 變動 → 用 StateProvider 計數觸發？
  簡化：LibraryPage 為 StatefulWidget，刪除後 setState 重讀 repo）

### 句子補齊

- `SentenceViewModel`：QuizGenerator freshWeight 12、`refreshPool()`（同單字模式）
- `sentence_practice_page` expansion listener：done → refreshPool + SnackBar 文案同單字

## 4. 測試

- store remove/blacklist：移除後池不含、reload 後黑名單仍在、同 key re-add 被擋（added=0）
- backupKeys 含 dyn_blacklist
- sentence VM：refreshPool 保留 session、freshWeight 已設（建構參數驗證困難 → 行為測試同單字模式）
- LibraryPage widget：顯示靜態+動態、動態才有刪除鈕、刪除 → repo 查不到 + 黑名單擋 re-add
