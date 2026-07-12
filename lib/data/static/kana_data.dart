import 'package:kana_trainer/domain/entities/kana.dart';

/// 假名資料表。
///
/// 維護方式：只維護「平假名」四張表 + 別名表，片假名由平假名
/// codepoint 位移（+0x60，U+3041..U+3096 → U+30A1..U+30F6）自動生成，
/// 保證兩套腳本永遠同步，新增假名只需改平假名表一處。

// ── 清音（含 ん）──
const Map<String, String> _seion = {
  'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o',
  'か': 'ka', 'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko',
  'さ': 'sa', 'し': 'shi', 'す': 'su', 'せ': 'se', 'そ': 'so',
  'た': 'ta', 'ち': 'chi', 'つ': 'tsu', 'て': 'te', 'と': 'to',
  'な': 'na', 'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no',
  'は': 'ha', 'ひ': 'hi', 'ふ': 'fu', 'へ': 'he', 'ほ': 'ho',
  'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo',
  'や': 'ya', 'ゆ': 'yu', 'よ': 'yo',
  'ら': 'ra', 'り': 'ri', 'る': 'ru', 'れ': 're', 'ろ': 'ro',
  'わ': 'wa', 'を': 'wo', 'ん': 'n',
};

// ── 濁音 ──
const Map<String, String> _dakuon = {
  'が': 'ga', 'ぎ': 'gi', 'ぐ': 'gu', 'げ': 'ge', 'ご': 'go',
  'ざ': 'za', 'じ': 'ji', 'ず': 'zu', 'ぜ': 'ze', 'ぞ': 'zo',
  'だ': 'da', 'ぢ': 'ji', 'づ': 'zu', 'で': 'de', 'ど': 'do',
  'ば': 'ba', 'び': 'bi', 'ぶ': 'bu', 'べ': 'be', 'ぼ': 'bo',
};

// ── 半濁音 ──
const Map<String, String> _handakuon = {
  'ぱ': 'pa', 'ぴ': 'pi', 'ぷ': 'pu', 'ぺ': 'pe', 'ぽ': 'po',
};

// ── 拗音（含濁拗音、半濁拗音）──
const Map<String, String> _youon = {
  'きゃ': 'kya', 'きゅ': 'kyu', 'きょ': 'kyo',
  'しゃ': 'sha', 'しゅ': 'shu', 'しょ': 'sho',
  'ちゃ': 'cha', 'ちゅ': 'chu', 'ちょ': 'cho',
  'にゃ': 'nya', 'にゅ': 'nyu', 'にょ': 'nyo',
  'ひゃ': 'hya', 'ひゅ': 'hyu', 'ひょ': 'hyo',
  'みゃ': 'mya', 'みゅ': 'myu', 'みょ': 'myo',
  'りゃ': 'rya', 'りゅ': 'ryu', 'りょ': 'ryo',
  'ぎゃ': 'gya', 'ぎゅ': 'gyu', 'ぎょ': 'gyo',
  'じゃ': 'ja', 'じゅ': 'ju', 'じょ': 'jo',
  'びゃ': 'bya', 'びゅ': 'byu', 'びょ': 'byo',
  'ぴゃ': 'pya', 'ぴゅ': 'pyu', 'ぴょ': 'pyo',
};

// ── 別名表（訓令式 / 常見替代拼音），以平假名為 key ──
const Map<String, List<String>> _aliases = {
  'し': ['si'], 'ち': ['ti'], 'つ': ['tu'], 'ふ': ['hu'],
  'じ': ['zi'], 'ぢ': ['di'], 'づ': ['du'],
  'を': ['o'], 'ん': ['nn'],
  'しゃ': ['sya'], 'しゅ': ['syu'], 'しょ': ['syo'],
  'ちゃ': ['tya'], 'ちゅ': ['tyu'], 'ちょ': ['tyo'],
  'じゃ': ['jya', 'zya'], 'じゅ': ['jyu', 'zyu'], 'じょ': ['jyo', 'zyo'],
};

/// 平假名字串 → 片假名字串（codepoint +0x60）。
String hiraganaToKatakana(String hira) {
  return String.fromCharCodes(hira.runes.map(
    (c) => c >= 0x3041 && c <= 0x3096 ? c + 0x60 : c,
  ));
}

List<Kana> _expand(Map<String, String> table, KanaCategory category) {
  final result = <Kana>[];
  table.forEach((hira, romaji) {
    final aliases = _aliases[hira] ?? const <String>[];
    result.add(Kana(
      kana: hira,
      romaji: romaji,
      aliases: aliases,
      type: KanaType.hiragana,
      category: category,
    ));
    result.add(Kana(
      kana: hiraganaToKatakana(hira),
      romaji: romaji,
      aliases: aliases,
      type: KanaType.katakana,
      category: category,
    ));
  });
  return result;
}

/// 全部假名（平/片 × 清/濁/半濁/拗）。
final List<Kana> allKana = List.unmodifiable([
  ..._expand(_seion, KanaCategory.seion),
  ..._expand(_dakuon, KanaCategory.dakuon),
  ..._expand(_handakuon, KanaCategory.handakuon),
  ..._expand(_youon, KanaCategory.youon),
]);

/// 以假名字元查 Kana，找不到回傳 null。
Kana? findKana(String kana) {
  for (final k in allKana) {
    if (k.kana == kana) return k;
  }
  return null;
}
