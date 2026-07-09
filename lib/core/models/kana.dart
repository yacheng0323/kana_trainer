/// 假名腳本種類。
enum KanaType { hiragana, katakana }

/// 假名分類。
enum KanaCategory {
  seion, // 清音（含 ん）
  dakuon, // 濁音
  handakuon, // 半濁音
  youon, // 拗音（含濁拗音、半濁拗音）
}

/// 單一假名題目。
///
/// [kana] 本身即唯一 id（平假名與片假名字元不同）。
/// [romaji] 為標準 Hepburn 拼音（小寫），[aliases] 為可接受的替代拼音
/// （訓令式等，小寫），判斷邏輯見 AnswerChecker。
class Kana {
  final String kana;
  final String romaji;
  final List<String> aliases;
  final KanaType type;
  final KanaCategory category;

  const Kana({
    required this.kana,
    required this.romaji,
    this.aliases = const [],
    required this.type,
    required this.category,
  });

  /// 所有可接受答案（canonical + aliases）。
  List<String> get acceptedAnswers => [romaji, ...aliases];

  @override
  String toString() => 'Kana($kana → $romaji)';
}
