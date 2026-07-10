import '../data/kana_data.dart';
import '../models/kana.dart';

/// 平假名讀音 → Hepburn 羅馬拼音。
///
/// 規則：拗音（2 字）優先查表 → 單字查表 → っ 促音（下一音節子音重複）
/// → ー 長音（重複前一個母音）。查表來源 = kana_data（單一事實來源）。
class RomajiConverter {
  RomajiConverter._();

  static final Map<String, String> _map = {
    for (final k in allKana)
      if (k.type == KanaType.hiragana) k.kana: k.romaji,
  };

  static String toRomaji(String hiragana) {
    final buf = StringBuffer();
    var doubleNext = false;
    var i = 0;
    while (i < hiragana.length) {
      // 拗音 2 字優先
      if (i + 1 < hiragana.length) {
        final pair = hiragana.substring(i, i + 2);
        final r = _map[pair];
        if (r != null) {
          buf.write(doubleNext ? r[0] + r : r);
          doubleNext = false;
          i += 2;
          continue;
        }
      }
      final ch = hiragana[i];
      if (ch == 'っ') {
        doubleNext = true;
        i++;
        continue;
      }
      if (ch == 'ー') {
        final s = buf.toString();
        if (s.isNotEmpty && 'aiueo'.contains(s[s.length - 1])) {
          buf.write(s[s.length - 1]);
        }
        i++;
        continue;
      }
      final r = _map[ch];
      if (r != null) {
        buf.write(doubleNext ? r[0] + r : r);
        doubleNext = false;
      } else {
        buf.write(ch); // 未知字元原樣保留
      }
      i++;
    }
    return buf.toString();
  }

  /// 讀音輸入判定：接受 平假名 / 片假名 / Hepburn 羅馬拼音（不分大小寫）。
  static bool matchesReading(String reading, String input) {
    var s = input.trim().toLowerCase();
    if (s.isEmpty) return false;
    if (s == reading) return true;
    // 片假名輸入 → 轉平假名比對
    final asHira = String.fromCharCodes(s.runes.map(
      (c) => c >= 0x30A1 && c <= 0x30F6 ? c - 0x60 : c,
    ));
    if (asHira == reading) return true;
    return s == toRomaji(reading);
  }
}
