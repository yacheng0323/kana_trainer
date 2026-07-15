# 全等級一致性收尾 設計

> 2026-07-16。v2.9.0 開了等級選擇，四個角落仍寫死 N5：模擬測驗、AI 出題、
> AI 對話、今日菜單新內容。本階段收齊。

## 1. 目標

- **各等級模擬測驗**：檢定 tab 依 `settings.jlptLevel` 組卷
  - N5：維持現行靜態組卷（檢定基準不變、成績歷史相容）
  - N4~N1：單字 10 題（該等級池）+ 假名 5 題（等級無關）+ 文法 5 題
    （該等級動態課 quiz 池）；題庫不足 → 開始鈕停用 + 顯示缺口
- **AI 全新題目**：prompt 等級化（現寫死 N5）
- **AI 情境對話**：日語回覆難度跟等級（N2/N1 敬語、進階句型）
- **今日菜單**：新內容補滿段按目前等級抽（SRS/錯題複習維持跨等級）

## 2. 非目標

- N4~N1 計時/題數規格調整（沿用 20 題 10 分）
- AI 弱點分析等級化（吃錯題本，跨等級本來就對）
- 各等級成績歷史分頁 UI（列表加等級 chip 即可）

## 3. 設計

### 模擬測驗等級化

- `ExamViewModel.buildQuestions` 加參數 `{int level = 5,
  List<VocabWord>? vocabPool, List<GrammarQuiz>? grammarPool}`
  - level==5 / pool 未傳：現行 allVocab/allGrammar 路徑（零行為變更）
  - level<5：單字 10 從 vocabPool 抽（干擾同池、不足由全池補選項）、
    假名 5 照舊、文法 5 從 grammarPool（動態課 quiz 攤平）抽
- 可考性 gate（domain/logic `ExamReadiness`）：`minVocab = 20`、
  `minGrammar = 5`；`check(level, vocabCount, grammarCount)` → ready +
  缺口數；N5 恆 ready
- `ExamRecord` 加 `level`（codec，舊紀錄缺 → 5）；歷史列表加「N4」chip
- ExamTab CTA + ExamPage 標題帶 N$level；未 ready → 按鈕 disabled + 缺口文案

### AI 出題/對話等級化

- `AiQuizService.generate` 加 `level`（prompt N$level）；
  快取 key `ai_cache_n<level>_<主題>`（舊 N5 快取不遷移，重生即可）
- `AiChatService.send` 加 `level`：5/4 簡短句、3 一般、2/1 敬語+進階句型

### 今日菜單

- `DailyMenuBuilder.build` 加 `lookupPool`（due/wrong 查字面，預設 =
  vocabPool）；呼叫端：vocabPool = 等級池（<15 傳全池）、lookupPool = 全池

## 4. 測試

- ExamReadiness 純函式；buildQuestions level<5 配比/來源/選項合法
- ExamRecord level round-trip、舊 JSON → 5
- ExamPage widget：N4 題庫不足 → 停用+缺口；足夠 → 考完紀錄帶 level
- AiQuiz/AiChat prompt 含 N$level、快取 key 帶 level
- DailyMenu：fresh 全為等級池、跨等級錯題仍查得到字面
