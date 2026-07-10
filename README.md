# kana_trainer — 日文 50 音練習 App

看假名、選（或打）羅馬拼音、即時判斷對錯的初學者練習 App。Flutter + Riverpod + SharedPreferences。

> **v2.0.0：M1~M6 全部完成**（假名 → 單字 → 句子 → 文法 → N5 檢定），詳見 [docs/ROADMAP.md](docs/ROADMAP.md)。
>
> - **單字**：105 詞 ×7 主題、日→中/中→日/讀音輸入三題型、SRS 間隔複習、聽力測驗
> - **句子**：40 句 ×5 旅遊情境、克漏字 + 語塊重組
> - **文法**：N5 12 課、教學卡 + 測驗、線性解鎖
> - **檢定**：20 題 10 分鐘模擬測驗、錯題檢討、成績歷史趨勢
> - **其他**：TTS 日文發音、每日目標連續達標、三本錯題本、學習資料備份匯出/匯入

## 設計風格：2c「深藍夜 x 金黃」

依設計交付稿實作（高保真）：

- **色票**：底色暖米白 `#F4E9DA`、深靛藍 `#22254A`（標題/邊框/主文字）、金黃 `#E8B04B`（強調）、答對綠 `#2E9E7C`、答錯紅 `#D65B5B`
- **造型**：8px 方正圓角、3–4px 實線邊框、`6px 6px 0` 無模糊硬陰影（貼紙感）
- **字體**：Zen Kaku Gothic New（400/500/700/900，bundled assets/fonts）
- **作答方式**：預設 **4 選 1**（點選項即時回饋：對→綠✓、錯→紅✕晃動 + 揭示正解 + 其餘淡化），設定可切回鍵盤輸入模式
- **動畫**：答錯 shake 0.4s、底部反饋橫幅上滑 0.25s、卡片邊框變色 0.2s
- Design tokens 集中在 `lib/core/theme/app_theme.dart`

---

## 1. 產品簡介

給日文初學者的假名讀音練習工具。畫面中央顯示一個假名（如「か」），使用者輸入羅馬拼音（如 `ka`），App 即時判斷正誤、給予回饋，並依熟練度加權出題：越不熟的字越常出現。支援平假名、片假名、濁音、半濁音、拗音，內建錯題本與學習統計。

## 2. 功能清單

| 類別 | 功能 |
|------|------|
| 練習模式 | 平假名（清音46）、片假名（清音46）、濁音・半濁音（50）、拗音（66）、混合（208）、錯題複習 |
| 作答 | trim 空白、預設不分大小寫、別名拼音（shi/si、chi/ti、ja/jya/zya…） |
| 回饋 | 答對/答錯即顯示、正確答案 + 可接受拼音、再試一次、下一題、答對自動下一題（可關） |
| 熟練度 | 每假名 0..5：答對 +1、答錯 -1；出題權重 = 6 − 熟練度 |
| 錯題本 | 錯誤次數排序、單筆移除、全部清除、一鍵重練；複習答對自動遞減消化 |
| 統計 | 今日答題數/正確率（跨日歸零）、總答題、正確率、最佳連對、總熟練進度條 |
| 設定 | 自動下一題、區分大小寫（預設關）、提示按鈕、音效/震動、羅馬拼音提示（初學模式） |

## 3. 畫面流程

```
HomePage（統計卡 + 模式九宮格 + AppBar：錯題本/設定）
 ├─ 點模式卡 ──→ PracticePage(mode)
 │                ├─ 顯示假名 → 輸入 → 確認
 │                ├─ 對：ResultFeedback(綠) → 自動/手動下一題
 │                └─ 錯：ResultFeedback(紅 + 正解) → 再試一次 / 下一題
 ├─ 錯題本 ──→ WrongListPage（列表 + FAB 重練 → PracticePage(wrongReview)）
 └─ 設定 ──→ SettingsPage（5 個開關）
```

## 4. 資料結構

- `Kana { kana, romaji, aliases[], type(hira/kata), category(清/濁/半濁/拗) }`
- **維護方式**：只維護平假名 4 張表 + 別名表（`lib/core/data/kana_data.dart`），片假名由 codepoint +0x60 自動生成，兩腳本永不脫鉤。新增假名改一處即可。
- 持久化（SharedPreferences，皆 JSON）：
  - `mastery`: `{ "か": 3, ... }`（0..5）
  - `wrong`: `{ "シ": 2, ... }`（答錯次數）
  - `stats`: `{ total, correct, bestStreak, currentStreak, todayDate, todayTotal, todayCorrect }`
  - `settings`: `{ autoNext, caseSensitive, showHint, sound, romajiHint }`

### 為何選 shared_preferences？

| 選項 | 評估 |
|------|------|
| **shared_preferences ✅** | 資料量小（<10KB JSON）、無查詢需求、零設定、跨平台 |
| hive | 快，但多一個 codegen/box 生命週期成本，此規模無感 |
| sqlite | 關聯查詢才划算；本 App 無關聯資料，殺雞用牛刀 |

## 5. 出題邏輯

`QuizGenerator`（`lib/core/logic/quiz_generator.dart`）：

- 加權隨機：`weight = 6 − clamp(mastery, 0, 5)`，熟練 0 → 權重 6，熟練 5 → 權重 1（加強模式內建，錯越多出越多）
- `weighted=false` → 純隨機（基本模式）
- 連續兩題不出同字（題庫 >1 時排除上一題）
- 錯題模式：題庫 = 錯題本 keys；混合模式：全部 208 字

## 6. 答案判斷邏輯

`AnswerChecker.check(kana, input, caseSensitive)`：

1. `input.trim()`，空字串直接 false
2. `caseSensitive=false`（預設）→ 轉小寫比對
3. 命中 `romaji` 或任一 `aliases` 即正確

別名表（可擴充，改 `kana_data.dart` 的 `_aliases` 一處）：
し=si、ち=ti、つ=tu、ふ=hu、じ=zi、ぢ=di、づ=du、を=o、ん=nn、
しゃ行=sya/syu/syo、ちゃ行=tya/tyu/tyo、じゃ行=jya+zya（三行）。

## 7. Flutter 架構

- **State**：Riverpod（手寫 provider，無 codegen）
  - `prefsProvider`（main() override 注入 SharedPreferences）
  - `settingsProvider` / `masteryProvider` / `wrongProvider` / `statsProvider`（全域，持久化）
  - `practiceProvider(mode)`（autoDispose family，session 狀態：當前題、feedback、連對、session 正確率）
- **頁面職責**
  - `HomePage`：讀 stats/mastery/wrong，模式導航
  - `PracticePage`：作答流程、自動下一題 timer、提示、音效
  - `ResultFeedback`：純顯示 widget
  - `WrongListPage`：錯題 CRUD + 重練入口
  - `SettingsPage`：開關 → `SettingsNotifier.update`

## 8. 資料夾結構

```
lib/
├── main.dart                 # prefs 注入 + ProviderScope
├── app/app.dart              # MaterialApp，light/dark 跟隨系統
├── core/
│   ├── models/               # Kana、PracticeMode（含 buildPool）
│   ├── data/kana_data.dart    # 資料表（單一事實來源）
│   ├── logic/                # AnswerChecker、QuizGenerator（純 Dart，可單測）
│   └── storage/prefs_provider.dart
└── features/
    ├── home/home_page.dart
    ├── practice/             # controller + page + widgets/
    ├── progress/             # mastery/wrong/stats notifiers + wrong_list_page
    └── settings/             # notifier + page
```

## 9. MVP 開發順序（已完成，各 Phase 一條 feature 分支合回 dev）

| Phase | 分支 | 內容 | 測試 |
|-------|------|------|------|
| 1 | `feature/phase1-data-logic` | 208 字資料表、AnswerChecker、QuizGenerator | 22 |
| 2 | `feature/phase2-practice-ui` | PracticeController、練習頁、回饋、首頁模式格 | +3 |
| 3 | `feature/phase3-wrong-stats` | 錯題頁、統計卡、熟練度進度 | +7 |
| 4 | `feature/phase4-settings` | 設定頁五開關 | +3 |
| 5 | `feature/phase5-polish-docs` | README、smoke test | +1 |

```powershell
flutter pub get
flutter test          # 36 tests
dart analyze lib test # zero issues
flutter run
```

## 10. 後續可擴充

- 發音音檔（TTS 或錄音）＋聽音辨字反向模式
- 手寫辨識（畫假名）
- 選擇題模式（4 選 1，降低初學門檻）
- 每日目標與連續學習天數（streak calendar）
- 熟練度衰減（久未練習自動 -1，間隔重複 SRS）
- 促音/長音/外來語拗音（ファ、ヴィ…）
- 雲端同步（帳號 + Supabase/Firebase）
- 排行榜 / 成就徽章
