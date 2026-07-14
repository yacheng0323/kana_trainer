# 動態題庫池（Dynamic Content Pool）設計

> 2026-07-14。使用者需求：單字/句子/文法題目不要固定寫死（50 音維持固定），
> 題庫要能不斷長大，避免「永遠只有那幾題在輪」。

## 1. 目標

- 單字、句子、文法測驗題三類內容可**動態擴充**：AI（Claude API）批次生成 → 驗證 → 去重 → 存入本地動態池
- 練習出題 = 靜態種子（105 詞 / 40 句 / 12 課文法題）+ 動態池，合併後抽題
- 生成一次、終身可用：動態池持久化本地、離線可玩、進備份
- 成本可控：每日生成批數上限、自動補貨可關

## 2. 非目標

- 50 音假名（形式固定，維持現狀）
- 新增單字主題 / 句子情境 / 文法課（**架構固定、內容動態**：7 主題、5 情境、12 課框架不變）
- 文法教學卡片內容（教學維持人審固定，只有測驗題動態）
- N4 以上內容（維持 N5）
- 即時（per-question）AI 出題 — 貴、延遲、離線斷

## 3. 被否決的替代方案

| 方案 | 否決原因 |
|------|---------|
| Tatoeba 免費 API | 只有句對（無單字釋義/文法題）、無 JLPT 程度篩選、繁簡混雜、品質參差；單字文法仍得靠 AI |
| Jisho / JMdict | 僅日英、無繁中（M7 時已評估否決） |
| 每次出題即時呼叫 AI | 每題都花錢、有延遲、離線不可用 |
| 爬蟲 | 來源網站 ToS 風險、格式脆弱、無穩定繁中 N5 來源 |

## 4. 架構（照 MVVM 分層規則）

```
features（ViewModel）
    └─ 取題走 ContentRepository（domain 抽象）
         └─ data 實作：靜態種子 + DynamicContentStore 合併去重
    └─ 練習中觸發 ExpansionPolicy 判斷 → 該補貨 → ContentExpansionService
         └─ AiClient（既有抽象）→ Claude 生成一批 → 驗證 → 去重 → 存入 store
```

| 元件 | 層 | 職責 |
|------|-----|------|
| `ContentRepository`（抽象） | `domain/repositories/` | `List<VocabWord> vocab()`、`List<SentenceItem> sentences()`、`List<GrammarQuizItem> grammarQuiz(lessonId)`；回傳靜態+動態合併池 |
| `DynamicContentStore` | `data/storage/` | 動態內容持久化（`KeyValueStore`，key：`dyn_vocab` / `dyn_sentences` / `dyn_grammar_quiz`，值 = JSON list）；`add(batch)` 內建 dedup by key |
| `ContentExpansionService` | `data/ai/` | 用 `AiClient` + json_schema 生成一批（單字 15 / 句子 8 / 文法題 5）；帶既有 key 清單要求 AI 避開；回傳驗證過的 entities |
| `ExpansionPolicy` | `domain/logic/` | 純函式：`shouldExpand({poolSize, unseenCount, dailyCount})` — 未見過（熟練度 0）項目 < 5 且今日批數 < 上限 → true |
| `ExpansionNotifier` | `features/` | 觸發補貨的狀態機（idle/generating/done/error），fire-and-forget，練習不等待 |

## 5. 資料模型

- 動態單字 = 既有 `VocabWord`（jp/reading/zh/topic/jlpt=5），key 沿用 `v_<jp>`
- 動態句子 = 既有 `SentenceItem`（jp/reading/zh/chunks/blankIndex/scene），key 沿用 `s_<jp>`
- 動態文法題 = 既有文法 quiz 結構（question/options[4]/correctIndex/note + lessonId）
- 序列化：各 entity 加 `toJson`/`fromJson`（或放 domain/models 的對應 codec），store 存 JSON list
- **key 規則不變 → 熟練度 / SRS / 三本錯題本零改動直接吃**

## 6. AI 生成規格

- 走既有 `AiClient.completeJson`（structured outputs，模型沿用 `claude-opus-4-8`）
- System prompt 鎖：N5 程度、繁體中文釋義、指定主題/情境/文法課、避開清單內既有項目
- 批次大小：單字 15、句子 8、文法題 5（一批一次 API 呼叫）
- 驗證（本地二次把關，AI 回傳不可信）：
  - 欄位非空、選項恰 4 個不重複、correctIndex 0..3
  - 句子 chunks 重組後 = jp、blankIndex 合法
  - key 不與既有池（靜態+動態）重複 — 重複者丟棄，其餘保留
  - 整批全滅 → 視為失敗（不計入每日批數？**計入**，避免壞回應無限重試）
- 錯誤處理：沿用 `AiException` 中文映射；失敗靜默（練習不中斷），設定頁可見最後錯誤

## 7. 觸發與成本控制

- **自動補貨（預設開）**：進入某主題/情境/課的練習時，`ExpansionPolicy` 判斷該範圍未見過項目 < 5 → 背景生成一批補該範圍
- 每日上限 **5 批**（計數存 prefs `expansion_daily`，格式 `{"date":"YYYY-MM-DD","count":N}`，跨日重置）
- 設定頁新增：自動擴充開關、今日已生成 N/5 批、手動「立即擴充」不做（YAGNI，自動夠用）
- 無 API Key / 斷網 / 上限到 → 不觸發，靜態+既有動態池照常出題

## 8. 備份

- `dyn_vocab` / `dyn_sentences` / `dyn_grammar_quiz` 加入 `BackupService.backupKeys`
- `expansion_daily` 不備份（日計數無跨機意義）

## 9. UI 改動（最小）

- 設定頁：「AI 自動擴充題庫」開關 + 今日批數
- 練習頁不加 loading —— 補貨是背景事，本輪用現有池
- （可選）補貨成功後 SnackBar「題庫 +N 題」— 做，給使用者「池子在長大」的感知

## 10. 測試策略（全離線）

| 測試 | 驗什麼 |
|------|--------|
| ExpansionPolicy 純函式 | 門檻/上限/開關組合 |
| DynamicContentStore | 序列化 round-trip、dedup、InMemoryKeyValueStore 驅動 |
| ContentExpansionService + FakeAiClient | 驗證規則（壞選項/壞 chunks/重複 key 丟棄）、避開清單有進 prompt |
| ContentRepository | 靜態+動態合併、動態蓋不掉靜態（key 衝突以靜態為準） |
| 每日計數 | 累加、跨日重置（`StatsNotifier.today` 注入慣例） |
| ViewModel 整合 | 動態單字進題、答錯進錯題本（key 規則相容） |
| 備份 | backupKeys 含三個 dyn key |

## 11. 驗收標準

- [ ] 動態池有內容時，單字/句子/文法測驗會出現靜態表以外的題目
- [ ] 無 API Key：一切照舊（靜態池），零錯誤彈窗
- [ ] 每日超過 5 批不再呼叫 API
- [ ] 匯出備份 → 清空 → 匯入，動態題庫回來
- [ ] `dart analyze` 零 issue、全測試綠
