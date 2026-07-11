# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## ⚠️ 重要規則（每次讀取此檔案都必須遵守）

> **每當有任何重大變更（新功能、架構調整、資料新增、測試變動、里程碑完成）：**
>
> 1. **更新 `docs/ROADMAP.md`** — 里程碑狀態、範圍調整、選型理由
> 2. **更新本檔案** — 版本歷程、架構、測試數、已知的坑
> 3. **Commit 文件變更**（不要讓文件落後於程式碼）
>
> **不適用：** 單行 bug fix、typo、格式調整。

---

## 專案簡介

日語學習 App（繁體中文使用者、零基礎～N5）：假名 → 主題單字 → 情境句子 → 基礎文法 → N5 模擬檢定，外加 Claude API 動態出題。Flutter + Riverpod（手寫 provider，無 codegen）+ SharedPreferences，完全離線可用（AI 出題除外）。

## 版本歷程

| 版本 | 內容 |
|------|------|
| v1.0.0 | 基礎版：208 假名練習（4選1/鍵盤輸入）、2c 設計系統、錯題本、統計 |
| v2.0.0 | M1~M6：105 單字×7主題（日中/中日/讀音輸入+SRS+聽力）、40 情境句（克漏字/重組）、N5 文法 12 課（線性解鎖）、模擬測驗+成績歷史、TTS、每日目標、備份匯出/匯入 |
| v2.1.0 | 資訊架構重構：Bottom NavigationBar 四 tab（50音基礎/主題學習/檢定/我的），IndexedStack 保留各 tab 狀態 |
| v2.2.0 | M7 AI 出題：Claude API（`claude-opus-4-8` + structured outputs）依主題生成 N5 題目，快取離線重玩；API Key 僅存本機且排除在備份外 |

> 詳細規劃與範圍調整紀錄：`docs/ROADMAP.md`

## Git 工作流

| 分支 | 用途 |
|------|------|
| `main` | 穩定版，只接受 `dev` merge，每次 release 打 tag（`vX.Y.Z`） |
| `dev` | 主開發分支 |
| `feature/*` | 單一功能，完成後 `merge --no-ff` 回 dev |

**Release checklist（合 main 前）：**
1. `dart analyze lib test` 零 issue
2. `flutter test` 全綠
3. `flutter build web --release` 過（端到端編譯驗證）
4. 版號同步三處：`pubspec.yaml`、`lib/features/home/tabs/profile_tab.dart`（版本字串）、git tag
5. `flutter build apk --release` → 複製到桌面命名 `kana_trainer-vX.Y.Z.apk`

## Common Commands

> Flutter 在 `D:\flutter\bin`，每個新 shell 要先：
> ```powershell
> $env:PATH = "D:\flutter\bin;$env:PATH"
> ```

```powershell
cd C:\Users\a0920\Desktop\kana_trainer
flutter pub get
dart analyze lib test        # zero-issue gate
flutter test                 # 83 tests
flutter build apk --release  # APK: build\app\outputs\flutter-apk\app-release.apk
flutter build web --release
```

## 架構

```
lib/
├── main.dart                    # prefs 注入 + ProviderScope
├── app/
│   ├── app.dart                 # MaterialApp（AppTheme.light，鎖亮色）
│   └── main_shell.dart          # Bottom NavigationBar 四 tab（IndexedStack）
├── core/
│   ├── ai/ai_quiz_service.dart  # Claude API 出題（raw HTTP）+ apiKeyProvider
│   ├── audio/tts_service.dart   # TtsService 抽象（flutter_tts ja-JP，無引擎靜默）
│   ├── data/                    # 全部靜態資料（單一事實來源）
│   │   ├── kana_data.dart       # 208 假名：只維護平假名表，片假名 codepoint +0x60 生成
│   │   ├── vocab_data.dart      # 105 詞（7 主題×15，N5）
│   │   ├── sentence_data.dart   # 40 句（5 情境×8，語塊化）
│   │   └── grammar_data.dart    # 12 課（每課 3 題 quiz，選項顯示時打亂）
│   ├── logic/
│   │   ├── quiz_generator.dart  # 泛型出題引擎：加權隨機（weight=6-熟練度）+ 4選1選項生成
│   │   ├── answer_checker.dart  # trim/大小寫/別名（shi=si 等）
│   │   └── romaji_converter.dart# 平假名→Hepburn（拗音/促音/長音）
│   ├── models/                  # Kana, VocabWord, Sentence, GrammarPoint + Pool enums
│   ├── storage/
│   │   ├── prefs_provider.dart  # SharedPreferences 單例（main override）
│   │   └── backup_service.dart  # 備份匯出/匯入（⚠️ backupKeys 刻意不含 claude_api_key）
│   └── theme/app_theme.dart     # 2c design tokens（見下）
└── features/
    ├── home/tabs/               # kana_tab / topics_tab / exam_tab / profile_tab
    │   └── widgets/home_cards.dart  # TabHeader / EntryCard / EntryGrid（共用）
    ├── practice/                # 假名練習（controller + page + widgets/quiz_widgets.dart 共用元件）
    ├── vocab/                   # 單字（日中/中日/讀音輸入三題型 family by VocabPool）
    ├── sentence/                # 句子（克漏字/重組隨機）
    ├── grammar/                 # 文法課（線性解鎖，全對標完成）
    ├── listening/               # 聽力測驗（TTS 播音 4 選 1）
    ├── exam/                    # 模擬測驗（20題/10分計時）+ 成績歷史
    ├── ai_quiz/                 # AI 出題頁（主題選擇→quiz 流程→快取）
    ├── progress/                # mastery / wrong×3 / stats / srs notifiers + 錯題頁（三 tab）
    └── settings/                # 設定 + API Key + 備份 UI
```

### 2c 設計系統（依設計交付稿，高保真）

- 色票：暖米白 `#F4E9DA`、深靛藍 `#22254A`、金黃 `#E8B04B`、答對綠 `#2E9E7C`、答錯紅 `#D65B5B`
- 造型：8px 方正圓角、2–4px 實線邊框、`6px 6px 0` 無模糊硬陰影（貼紙感）
- 字體：Zen Kaku Gothic New 400/500/700/900（bundled `assets/fonts/`，Google Fonts 下載）
- 單一亮色設計（無深色模式）
- 共用互動元件在 `features/practice/widgets/quiz_widgets.dart`：`PracticeHeader`（靛藍頂欄+連對+5段進度）、`OptionButton`（對✓綠/錯✕紅晃動/其餘淡化）、`FeedbackBanner`（底部上滑橫幅）、`SpeakButton`

### 學習引擎共通規則

- 熟練度 0..5：答對 +1、答錯 -1；出題權重 = 6 − 熟練度；連續兩題不重複
- 錯題本三本獨立（`wrong`/`vocab_wrong`/`sentence_wrong`），複習答對遞減、歸零移出
- SRS（單字限定）：熟練度 → 0/1/3/7/14/30 天後到期，答錯立即到期
- 每日目標：跨日連續達標天數（`StatsNotifier` 內含 yesterday 判定）

### SharedPreferences keys

| Key | 內容 | 備份？ |
|-----|------|--------|
| `settings` / `mastery` / `wrong` / `vocab_wrong` / `sentence_wrong` / `srs` / `stats` / `grammar_done` / `exam_history` | 學習資料（JSON） | ✅ `BackupService.backupKeys` |
| `claude_api_key` | Claude API Key | ❌ **刻意排除**（測試有斷言） |
| `ai_cache_<主題>` | AI 題組快取 | ❌ |

### AI 出題（`core/ai/ai_quiz_service.dart`)

- Raw HTTP `POST /v1/messages`（Dart 無官方 SDK），model `claude-opus-4-8`
- `output_config.format` json_schema → 回傳保證合法 JSON；仍有二次驗證（4 選項不重複、index 0..3）
- 錯誤映射：401=Key 無效、429=稍後再試、5xx=服務異常、其他=網路失敗，全部轉 `AiQuizException` 中文訊息

## Testing — 83 tests（`test/`）

| 檔案 | 涵蓋 |
|------|------|
| `kana_data_test` / `answer_checker_test` / `quiz_generator_test` | 資料完整性、判定規則、加權與選項生成 |
| `practice_page_test` | 假名 4 選 1 + 鍵盤輸入雙流程 |
| `vocab_test` / `m2_test` | 單字三題型、romaji converter、SRS、每日目標 |
| `m3_test` | 句子資料 + 克漏字/重組流程 |
| `m4_test` | 文法資料 + 課程完成/解鎖 |
| `m5_test` | FakeTts、聽力流程、發音按鈕 |
| `m6_test` | 出卷組成、測驗流程、備份 round-trip |
| `m7_ai_test` | AI service（MockClient）、Key 安全、頁面流程 |
| `home_smoke_test` / `settings_test` / `progress_test` | 四 tab 導航、設定持久化、notifiers |

所有測試離線（HTTP 用 `MockClient`、TTS 用 `FakeTts`、prefs 用 mock）。

## 已知的坑（改動前必讀）

1. **PowerShell 5.1 commit 訊息不能含雙引號** — here-string 傳給 git 時引號會裂開導致 commit 失敗、變更被帶到別的分支。訊息一律避免 `"`。
2. **測試 MockClient 回應含中文必須帶 `content-type: application/json; charset=utf-8`** — 否則 http 套件用 latin-1 編碼直接炸。
3. **widget 測試頁面比視窗長** — tap 選項前先 `tester.ensureVisible(...)`；題目文字可能與選項同字（如「出口」jp=zh），用 `find.descendant(of: find.byType(OptionButton), ...)` 鎖定。
4. **grammar_data 的 quiz `correctIndex` 全是 0** — 這是刻意的（資料好維護），顯示時由 `GrammarLessonPage`/`ExamController` 打亂順序。新增資料照做即可。
5. **flutter_tts 有 KGP 棄用警告** — 未來 Flutter 版本才會 break，等套件更新。
6. **APK 是 debug key 簽名** — 自用 OK；上 Google Play 前要建正式 keystore。
7. **假名/單字/句子資料維護**：假名只改平假名表（片假名自動生成）；句子只改 chunks + blankIndex；jp/key 全庫唯一由測試把關。

## 未落地（需使用者決策）

- Supabase 雲端同步（要帳號 + 費用決策；目前用本機備份匯出/匯入替代）
- Google Play 上架（正式 keystore、隱私權政策、商店素材）
- iOS（無 Mac 環境）
