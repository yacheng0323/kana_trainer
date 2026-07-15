# N1~N5 全等級擴充 設計

> 2026-07-16。使用者需求：不要等 N5 刷完，N1~N5 全開、自由選擇今天練哪個等級
> （單字/句子/文法都要）。已拍板：N4~N1 文法教學課 = AI 生成 + 標示未人審，
> 教錯可從題庫刪除（黑名單）重生成。

## 1. 目標

- 等級選擇器（N5~N1，存 settings，主題學習 tab 頂部切換）
- 單字/句子：各等級獨立池。N5 有靜態種子；N4~N1 從零開始，靠既有
  「池 <30 就補」機制 AI 自動長出來（prompt 鎖對應 JLPT 等級）
- 文法：N5 維持人審 12 課；N4~N1 課程由 AI 生成（教學卡+例句+3 題），
  課卡標「AI」badge，手動「生成下一課」按鈕（計入每日 20 批）
- 學習引擎零改動：mastery/SRS/錯題 key 全域唯一（v_<jp>），跨等級共用
- 詞彙量儀表板顯示「目前等級」的統計

## 2. 非目標

- N4~N1 靜態種子資料（動態池就是種子）
- 各等級獨立模擬測驗（exam 維持 N5 靜態，檢定基準）
- 動態文法課線性解鎖（生成即可玩，自由選；N5 靜態課維持線性）
- 等級自動判定/分級測驗

## 3. 設計

### 等級模型

- `Settings.jlptLevel`（int 5..1，預設 5），toJson/fromJson/copyWith 照模式
- 等級選擇 UI：TopicsTab 頂部 SegmentedButton N5…N1 → 寫 settings

### 資料模型

- `VocabWord.jlpt` 已存在 → codec 補存 `jlpt` 欄位（舊資料缺 → 5）
- `Sentence` 加 `final int jlpt`（預設 5）+ codec（舊資料缺 → 5）
- 新 `DynamicGrammarLesson`：`{id, level, title, explanation,
  examples[(jp,zh)], quiz[GrammarQuiz×3]}`；id = `gdyn_n{level}_{title}`；
  可轉 `GrammarPoint` 直接餵既有 GrammarLessonPage（零 UI 重工）
- 儲存：`dyn_grammar_lessons`（進備份）；刪除 → 黑名單（key = id）

### 池過濾

- Vocab/Sentence VM：`_all` 先按 `settings.jlptLevel` 過濾再 buildPool
- 跨等級同字防撞：生成 dedup 用全域 key（字屬於先生成它的等級）
- 今日菜單：新內容補滿段按目前等級過濾；SRS/錯題複習跨等級（key 本位）

### AI 生成（ContentExpansionService）

- `generateVocab`/`generateSentences` 加 `level` 參數，prompt 鎖
  「JLPT N{level} 程度」；N1~N3 提示可含進階語彙/敬語等
- 新 `generateGrammarLesson({apiKey, level, existingTitles})`：
  一次一課（title/explanation/examples×3/quiz×3），本地驗證
  （quiz 4 選項不重複、題面含＿＿、examples 非空）、title 避開清單
- 自動補貨（單字/句子）沿用 ExpansionPolicy；文法課**手動**生成
  （教學內容使用者主動觸發較合理），計入每日批數

### 文法 UI

- GrammarListPage：等級跟 settings；N5 = 靜態 12 課（線性解鎖照舊）；
  N4~N1 = 動態課列表（AI badge、無線性鎖）+「AI 生成下一課」按鈕
  （無 Key/達每日上限時停用+提示）
- 動態課完成標記沿用 grammar_progress（id 唯一）
- 我的題庫：文法題 tab 已涵蓋動態課的 quiz；動態課刪除入口在課列表長按？
  → 簡化：題庫頁文法 tab 列動態課（可刪）

### 儀表板

- VocabStatsPage 過濾目前等級；標題顯示「詞彙量（N4）」
- vocab_history 快照維持全等級總量（歷史相容，不拆檔）

## 4. 被否決的替代方案

- 各等級預先人審靜態內容：工作量爆炸，違背動態池的意義
- 文法課全自動生成：教學內容自動觸發不透明，改手動按鈕

## 5. 測試

- Settings.jlptLevel round-trip；等級切換影響 vocab/sentence 池
- codec：jlpt 欄位 round-trip、舊資料預設 5
- DynamicGrammarLesson codec/store/刪除黑名單/備份 key
- generateGrammarLesson 驗證規則（壞 quiz 丟課、title 重複丟棄）
- GrammarListPage：N5 靜態、N4 空列表+生成按鈕、生成後出現課卡（FakeAiClient）
