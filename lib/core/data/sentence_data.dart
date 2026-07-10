import '../models/sentence.dart';

/// 旅遊情境句子庫（M3：5 情境 × 8 句 = 40 句，N5 程度）。
///
/// 維護方式：chunks = 正確語塊順序，blankIndex = 克漏字挖空位置；
/// jp 由 chunks 串接而成、全庫唯一（測試保證）。
Sentence _s(List<String> chunks, int blank, String zh, Scene scene) =>
    Sentence(chunks: chunks, blankIndex: blank, zh: zh, scene: scene);

final List<Sentence> allSentences = List.unmodifiable([
  // ── 機場 ──
  _s(['パスポート', 'を', '見せて', 'ください'], 0, '請出示護照。', Scene.airport),
  _s(['搭乗口', 'は', 'どこ', 'ですか'], 2, '登機門在哪裡？', Scene.airport),
  _s(['荷物', 'を', '預けたい', 'です'], 0, '我想寄放行李。', Scene.airport),
  _s(['チェックイン', 'を', 'お願いします'], 0, '麻煩辦理報到。', Scene.airport),
  _s(['窓側', 'の', '席', 'が', 'いい', 'です'], 0, '我想要靠窗的位子。', Scene.airport),
  _s(['飛行機', 'は', '何時', 'に', '出発しますか'], 2, '飛機幾點出發？', Scene.airport),
  _s(['両替', 'は', 'どこで', 'できますか'], 0, '哪裡可以換錢？', Scene.airport),
  _s(['免税店', 'で', '買い物', 'を', 'します'], 0, '在免稅店購物。', Scene.airport),

  // ── 電車 ──
  _s(['切符', 'を', '一枚', 'ください'], 2, '請給我一張票。', Scene.train),
  _s(['東京駅', 'まで', 'いくら', 'ですか'], 2, '到東京車站多少錢？', Scene.train),
  _s(['次', 'の', '電車', 'は', '何時', 'ですか'], 4, '下一班電車是幾點？', Scene.train),
  _s(['ここ', 'で', '乗り換えて', 'ください'], 2, '請在這裡轉乘。', Scene.train),
  _s(['この', '電車', 'は', '新宿', 'に', '止まりますか'], 5, '這班電車停新宿嗎？',
      Scene.train),
  _s(['改札', 'は', 'あちら', 'です'], 0, '剪票口在那邊。', Scene.train),
  _s(['終電', 'は', 'もう', '出ました'], 0, '末班車已經開走了。', Scene.train),
  _s(['駅', 'まで', '歩いて', '十分', 'です'], 3, '走到車站十分鐘。', Scene.train),

  // ── 飯店 ──
  _s(['予約','を', 'して', 'います'], 0, '我有預約。', Scene.hotel),
  _s(['チェックアウト', 'は', '何時', 'ですか'], 2, '退房是幾點？', Scene.hotel),
  _s(['部屋', 'の', '鍵', 'を', 'なくしました'], 2, '我把房間鑰匙弄丟了。', Scene.hotel),
  _s(['朝ごはん', 'は', 'どこで', '食べますか'], 2, '早餐在哪裡吃？', Scene.hotel),
  _s(['一泊', 'いくら', 'ですか'], 1, '住一晚多少錢？', Scene.hotel),
  _s(['タオル', 'を', 'もう一枚', 'ください'], 2, '請再給我一條毛巾。', Scene.hotel),
  _s(['パスワード', 'を', '教えて', 'ください'], 2, '請告訴我密碼。', Scene.hotel),
  _s(['静かな', '部屋', 'を', 'お願いします'], 0, '麻煩給我安靜的房間。', Scene.hotel),

  // ── 餐廳 ──
  _s(['メニュー', 'を', 'ください'], 0, '請給我菜單。', Scene.restaurant),
  _s(['おすすめ', 'は', '何', 'ですか'], 0, '推薦餐點是什麼？', Scene.restaurant),
  _s(['これ', 'を', '二つ', 'お願いします'], 2, '這個請給我兩份。', Scene.restaurant),
  _s(['お水', 'を', 'ください'], 0, '請給我水。', Scene.restaurant),
  _s(['お会計', 'を', 'お願いします'], 0, '麻煩結帳。', Scene.restaurant),
  _s(['とても', 'おいしかった', 'です'], 1, '非常好吃。', Scene.restaurant),
  _s(['予約', 'なしで', '大丈夫', 'ですか'], 2, '沒有預約也可以嗎？', Scene.restaurant),
  _s(['辛い', 'もの', 'が', '苦手', 'です'], 0, '我不太能吃辣。', Scene.restaurant),

  // ── 購物 ──
  _s(['これ', 'は', 'いくら', 'ですか'], 2, '這個多少錢？', Scene.shopping),
  _s(['試着', 'しても', 'いいですか'], 0, '可以試穿嗎？', Scene.shopping),
  _s(['もっと', '安い', 'の', 'は', 'ありますか'], 1, '有更便宜的嗎？', Scene.shopping),
  _s(['カード', 'で', '払えますか'], 0, '可以刷卡嗎？', Scene.shopping),
  _s(['袋', 'を', 'もらえますか'], 0, '可以給我袋子嗎？', Scene.shopping),
  _s(['別々', 'に', '包んで', 'ください'], 2, '請分開包裝。', Scene.shopping),
  _s(['免税', 'に', 'できますか'], 0, '可以免稅嗎？', Scene.shopping),
  _s(['プレゼント', '用', 'に', 'お願いします'], 0, '麻煩包裝成禮物用。', Scene.shopping),
]);

/// 以 key（`s_<jp>`）查句子，找不到回傳 null。
Sentence? findSentence(String key) {
  for (final s in allSentences) {
    if (s.key == key) return s;
  }
  return null;
}
