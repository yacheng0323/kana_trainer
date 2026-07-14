import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 學習資料備份：匯出/匯入所有進度為 JSON 字串（M6，取代雲端同步）。
class BackupService {
  const BackupService._();

  static const version = 1;

  /// 需要備份的 prefs key（全部為 JSON 字串值）。
  static const backupKeys = [
    'settings',
    'mastery',
    'wrong',
    'vocab_wrong',
    'sentence_wrong',
    'srs',
    'stats',
    'grammar_done',
    'exam_history',
    'daily_history',
    'menu_done',
    // 動態題庫池（AI 生成內容，換機不該丟）
    'dyn_vocab',
    'dyn_sentences',
    'dyn_grammar_quiz',
    'dyn_blacklist', // 使用者刪題紀錄（整理成果，換機不該丟）
  ];

  static String export(SharedPreferences prefs) {
    final data = <String, String>{};
    for (final key in backupKeys) {
      final v = prefs.getString(key);
      if (v != null) data[key] = v;
    }
    return jsonEncode({
      'app': 'kana_trainer',
      'version': version,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  /// 匯入。格式錯誤丟 [FormatException]。回傳匯入的 key 數。
  static Future<int> import(SharedPreferences prefs, String json) async {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('不是有效的 JSON');
    }
    if (decoded['app'] != 'kana_trainer' || decoded['data'] is! Map) {
      throw const FormatException('不是 kana_trainer 的備份檔');
    }
    // 舊備份檔（無 version 欄位）視為 v1。
    final raw = decoded['version'];
    final fileVersion = raw is int ? raw : 1;
    if (fileVersion > version) {
      throw FormatException('備份檔版本過新（v$fileVersion），請先更新 App 再匯入');
    }
    // fileVersion < version 時在此加入逐版 migration；目前僅有 v1。
    final data = decoded['data'] as Map<String, dynamic>;
    var count = 0;
    for (final key in backupKeys) {
      final v = data[key];
      if (v is String) {
        await prefs.setString(key, v);
        count++;
      }
    }
    return count;
  }
}
