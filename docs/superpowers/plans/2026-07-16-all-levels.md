# N1~N5 全等級擴充 Implementation Plan

> Spec: `docs/superpowers/specs/2026-07-16-all-levels-design.md`
> 版本 v2.9.0。TDD、每 task commit、gates 全過才合 main。

### Task 1: Settings.jlptLevel + 資料模型等級化
- `app_settings.dart`：`jlptLevel`（int，預設 5）三處照模式
- `sentence.dart`：`Sentence` 加 `final int jlpt;`（建構子預設 5）
- `dynamic_content.dart`：vocab codec 補存/讀 `jlpt`（缺 → 5）；
  sentence codec 補存/讀 `jlpt`（缺 → 5）
- Tests：codec round-trip 含 jlpt、舊格式預設 5、settings round-trip

### Task 2: DynamicGrammarLesson（entity + codec + store）
- `dynamic_content.dart`：`DynamicGrammarLesson{id, level, title,
  explanation, examples, quiz}` + `toGrammarPoint()` + codec（quiz 3 題驗證）
- `dynamic_content_store.dart`：`grammarLessonsKey='dyn_grammar_lessons'`、
  `grammarLessons()`、`addGrammarLessons()`（dedup by id + 黑名單）、
  `remove()` 支援 lesson
- `backup_service.dart`：backupKeys 加 `dyn_grammar_lessons`
- Tests：codec/persist/dedup/remove+黑名單/備份 key

### Task 3: ContentExpansionService 等級化 + generateGrammarLesson
- `generateVocab`/`generateSentences` 加 `required int level`，prompt 用
  N$level；呼叫端（expansion_notifier）傳 settings.jlptLevel
- `generateGrammarLesson({apiKey, level, existingTitles})`：schema
  {title, explanation, examples[{jp,zh}], quiz[{question,options,correctIndex}]}，
  驗證：examples ≥2、quiz 恰 3 題各 4 選項不重複含＿＿、title 不在避開清單
- Tests：prompt 含 N4 字樣、壞 lesson 回 null、title 重複回 null

### Task 4: 等級接線（VM/菜單/儀表板/擴充）
- vocab/sentence VM：`_rebuildPool` 先 `where((x) => x.jlpt == level)`
- listening VM：同過濾
- expansion_notifier：maybeExpandVocab/Sentences 讀 settings.jlptLevel，
  unseen/poolSize 以「等級內」計；新 `expandGrammarLesson(int level)`
  （手動、無 unseen 判斷、只檢查 enabled+每日上限）
- daily_menu_builder 呼叫端：傳入等級過濾後的池
- VocabStatsPage：過濾目前等級、AppBar 標題帶 N$level
- Tests：切等級後池分離（N4 空池 fallback 行為）、expandGrammarLesson 入池

### Task 5: 文法 UI（等級化 GrammarListPage）
- TopicsTab 頂部等級 SegmentedButton（寫 settings.jlptLevel）
- GrammarListPage：level==5 → 靜態 12 課線性解鎖（現狀）；
  level<5 → repo/store 動態課列表（AI badge、點入 GrammarLessonPage
  用 toGrammarPoint()）+「AI 生成下一課」FilledButton（生成中 spinner、
  無 Key/上限到 → SnackBar 提示）
- LibraryPage 文法 tab：動態課也列出（可刪）
- Tests：N5 靜態現狀、N4 空列表 + 按鈕生成（FakeAiClient）→ 課卡出現

### Task 6: 文件 + Release v2.9.0
- CLAUDE.md（版本表、keys 表加 dyn_grammar_lessons、測試數）、ROADMAP、
  pubspec 2.9.0+16、profile_tab 版字串
- gates → merge dev/main → tag → push → APK 桌面
