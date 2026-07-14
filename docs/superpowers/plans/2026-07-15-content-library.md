# 題庫瀏覽器 + 句子機制補齊 Implementation Plan

> Spec: `docs/superpowers/specs/2026-07-15-content-library-design.md`
> 版本 v2.7.0。TDD、每 task commit、gates 全過才合 main。

### Task 1: DynamicContentStore 黑名單 + remove
- Modify: `lib/data/storage/dynamic_content_store.dart`
  - `blacklistKey = 'dyn_blacklist'`、載入 `Set<String> _blacklist`
  - `_add` 跳過黑名單 key
  - `remove(String key)`：三池都試移除、加黑名單、持久化（池 JSON + 黑名單 JSON）
- Test: `test/dynamic_content_store_test.dart` 加 remove/blacklist/reload 案例

### Task 2: 備份
- Modify: `lib/data/storage/backup_service.dart` backupKeys 加 `dyn_blacklist`
- Test: `test/expansion_notifier_test.dart` 備份斷言加一行

### Task 3: 句子補齊 v2.6.2 機制
- Modify: `lib/features/sentence/sentence_view_model.dart`
  - generator `freshWeight: 12`、抽 `_rebuildPool()`、加 `refreshPool()`
- Modify: `lib/features/sentence/sentence_practice_page.dart`
  - expansion listener：done → `refreshPool()` + SnackBar 文案「題庫 +N 題，馬上就會出現新句子」
- Test: `test/dynamic_wiring_test.dart` 加句子 refreshPool 案例

### Task 4: LibraryPage + 入口
- Create: `lib/features/library/library_page.dart`
  - StatefulWidget（ConsumerStatefulWidget），三 tab：單字/句子/文法題
  - 單字 tab：搜尋框 + 列表（jp・reading・zh，動態項 AI badge + 刪除鈕）
  - 句子 tab：jp + zh；文法題 tab：question + 課名；同樣動態才可刪
  - 刪除：AlertDialog 確認 → `store.remove(key)` → setState
- Modify: `lib/features/home/tabs/profile_tab.dart` 學習管理區加 EntryCard「我的題庫」
- Test: `test/library_page_test.dart`

### Task 5: 文件 + Release v2.7.0
- CLAUDE.md 版本表 + prefs keys 表（dyn_blacklist ✅ 備份）+ 測試數
- ROADMAP v2.7.0 條目、pubspec 2.7.0+13、profile_tab 版字串
- gates：analyze / test / web / apk → merge dev/main → tag → push → APK 桌面
