import '../models/kana.dart';

/// 答案判斷。
///
/// 規則：
/// 1. 前後空白自動 trim
/// 2. 預設不區分大小寫（Ka / KA / ka 皆對）
/// 3. canonical romaji 或任一 alias 命中即正確
/// 4. 資料表中的答案一律小寫；caseSensitive=true 時輸入必須全小寫才算對
class AnswerChecker {
  const AnswerChecker._();

  static bool check(Kana kana, String input, {bool caseSensitive = false}) {
    var s = input.trim();
    if (s.isEmpty) return false;
    if (!caseSensitive) s = s.toLowerCase();
    return kana.acceptedAnswers.contains(s);
  }
}
