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
| v2.3.0 | M8 習慣養成：今日菜單（SRS+錯題+新內容 15 題一鍵 session，「今日」tab，五 tab）、每日提醒（flutter_local_notifications，inexact 排程）、學習熱力圖（`daily_history`） |
| v2.3.1 | fix：Android release build 需 core library desugaring（flutter_local_notifications） |
| v2.4.0 | M9 學習深度：動詞變化訓練（41 個 N5 動詞四變化 drill）、AI 情境對話（5 情境角色扮演＋糾錯）、AI 弱點分析（錯題→建議，快取 `ai_analysis`）；抽共用 ClaudeClient |
| v2.5.0 | MVVM 架構重構：domain/data/features 分層、model 類別全數移出 ViewModel/service、抽象介面 KeyValueStore + AiClient、controller 更名 ViewModel、全面 package imports。零行為變更，103 tests |
| v2.5.1 | 防禦性強化：GitHub Actions CI（analyze+test）、API Key 移入 flutter_secure_storage（Keystore 加密，啟動時自動搬移舊明文並刪除）、備份匯入版本檢查（過新拒絕）。109 tests |
| v2.6.0 | 動態題庫池：單字/句子/文法題 AI 批次生成擴充（`ContentRepository` 合併靜態+動態、`DynamicContentStore` 持久化、`ExpansionNotifier` 自動補貨、每日 5 批上限、動態池進備份）。50 音維持固定。140 tests |

> 詳細規劃與範圍調整紀錄：`docs/ROADMAP.md`

## Git 工作流

| 分支 | 用途 |
|------|------|
| `main` | 穩定版，只接受 `dev` merge，每次 release 打 tag（`vX.Y.Z`） |
| `dev` | 主開發分支 |
| `feature/*` | 單一功能，完成後 `merge --no-ff` 回 dev |

> Push 後 GitHub Actions CI 自動跑 analyze + test（`.github/workflows/ci.yml`，main/dev/feature/** 均觸發）。

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
flutter test                 # 140 tests
flutter build apk --release  # APK: build\app\outputs\flutter-apk\app-release.apk
flutter build web --release
```

## 架構（MVVM，v2.5.0 起）

**分層規則（新增程式碼必守）：**
- **Model 類別一律放 `domain/`** — 不准把 state/feedback/report class 寫在 ViewModel 或 service 檔內
- **ViewModel 只依賴抽象**：儲存走 `KeyValueStore`（不直接碰 SharedPreferences）、AI 走 `AiClient`（不直接碰 HTTP）
- 依賴方向：`features → domain ← data`（domain 不 import data/features；data 實作 domain 介面）
- ViewModel 檔名 `*_view_model.dart`、類名 `XxxViewModel`；View 檔名 `*_page.dart`

```
lib/
├── main.dart                     # prefs + SecureStore 注入 + ProviderScope
├── app/                          # MaterialApp + MainShell（五 tab IndexedStack）
├── core/theme/app_theme.dart     # 2c design tokens（跨層 UI 常數）
├── domain/                       # ═ Model 層 ═
│   ├── entities/                 # Kana / VocabWord / Sentence / GrammarPoint / Verb + Pool enums
│   ├── models/                   # 狀態與值物件：practice/vocab/sentence/listening/exam/menu/verb/ai
│   │                             #   models、Stats、Settings（app_settings）、MenuDone
│   ├── logic/                    # QuizGenerator（泛型）/ AnswerChecker / RomajiConverter
│   └── repositories/             # 抽象介面：KeyValueStore（+InMemory 測試版）、AiClient、AiException
├── data/                         # ═ Model 實作層 ═
│   ├── static/                   # 靜態資料源：kana/vocab/sentence/grammar/verb_data
│   ├── storage/                  # prefs_provider（SharedPreferences 單例）、
│   │                             #   prefs_store（SharedPrefsStore 實作 + keyValueStoreProvider）、
│   │                             #   secure_store（SecureStore 實作，API Key 走 Keystore 加密）、
│   │                             #   dynamic_content_store（AI 生成內容持久化池，dedup）、
│   │                             #   backup_service（⚠️ backupKeys 刻意不含 claude_api_key）
│   ├── content/                  # MergedContentRepository（靜態種子+動態池合併，
│   │                             #   contentRepositoryProvider — 練習取題唯一入口）
│   ├── ai/                       # ClaudeClient（實作 AiClient）+ quiz/chat/analysis services
│   └── services/                 # TtsService、NotificationService（平台服務，皆有抽象+fake）
└── features/                     # ═ View + ViewModel ═
    ├── home/tabs/                # today/kana/topics/exam/profile_tab + widgets/home_cards
    ├── practice/                 # practice_view_model + practice_page + widgets/quiz_widgets（共用）
    ├── vocab/                    # vocab_view_model（三題型 family by VocabPool）
    ├── sentence/                 # sentence_view_model（克漏字/重組）
    ├── listening/                # listening_view_model
    ├── exam/                     # exam_view_model + 成績歷史
    ├── grammar/ today/ verb/ ai_quiz/ ai_chat/ ai_analysis/
    ├── progress/                 # mastery/wrong×3/stats/srs/daily_history notifiers + 錯題頁
    └── settings/                 # settings_notifier + 設定/API Key/備份/提醒 UI
```

**測試注入方式**：override `keyValueStoreProvider`（InMemoryKeyValueStore）或維持舊路徑 override `prefsProvider`（兩者相容，keyValueStore 預設由 prefs 組出）；AI service 建構子注入 `aiClient:`（FakeAiClient）或 `client:`（http MockClient）。範例見 `test/architecture_test.dart`。

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
| `settings` / `mastery` / `wrong` / `vocab_wrong` / `sentence_wrong` / `srs` / `stats` / `grammar_done` / `exam_history` / `daily_history` / `menu_done` | 學習資料（JSON） | ✅ `BackupService.backupKeys` |
| `claude_api_key` | ~~Claude API Key~~ **v2.5.1 起移入 flutter_secure_storage（Keystore）**，不在 prefs；啟動時舊明文自動搬移＋刪除 | ❌ **刻意排除**（測試有斷言） |
| `ai_cache_<主題>` | AI 題組快取 | ❌ |
| `dyn_vocab` / `dyn_sentences` / `dyn_grammar_quiz` | 動態題庫池（AI 生成，v2.6.0） | ✅ |
| `expansion_daily` | 每日生成批數 `{"date","count"}` | ❌（日計數無跨機意義） |

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
5b. **release APK 需 core library desugaring**（`android/app/build.gradle.kts`：`isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs`）— flutter_local_notifications 要求；拿掉會在 CheckAarMetadata 炸掉。另注意：build 失敗時 `build\...\app-release.apk` 仍是**上一次成功的舊檔**，複製前先確認 build 成功。
6. **APK 是 debug key 簽名** — 自用 OK；上 Google Play 前要建正式 keystore。
7. **假名/單字/句子資料維護**：假名只改平假名表（片假名自動生成）；句子只改 chunks + blankIndex；jp/key 全庫唯一由測試把關。

## 未落地（需使用者決策）

- Supabase 雲端同步（要帳號 + 費用決策；目前用本機備份匯出/匯入替代）
- Google Play 上架（正式 keystore、隱私權政策、商店素材）
- iOS（無 Mac 環境）
