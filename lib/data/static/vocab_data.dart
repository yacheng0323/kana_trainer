import 'package:kana_trainer/domain/entities/vocab.dart';

/// N5 主題單字庫（M1：7 主題 × 15 = 105 詞）。
///
/// 維護方式：每主題一個區塊，(jp, reading, zh) 三元組；
/// jp 全庫唯一（測試保證），新增詞只需在對應主題加一行。
VocabWord _w(String jp, String reading, String zh, VocabTopic t) =>
    VocabWord(jp: jp, reading: reading, zh: zh, topic: t);

final List<VocabWord> allVocab = List.unmodifiable([
  // ── 旅遊 ──
  _w('旅行', 'りょこう', '旅行', VocabTopic.travel),
  _w('ホテル', 'ほてる', '飯店', VocabTopic.travel),
  _w('観光', 'かんこう', '觀光', VocabTopic.travel),
  _w('地図', 'ちず', '地圖', VocabTopic.travel),
  _w('写真', 'しゃしん', '照片', VocabTopic.travel),
  _w('温泉', 'おんせん', '溫泉', VocabTopic.travel),
  _w('神社', 'じんじゃ', '神社', VocabTopic.travel),
  _w('お寺', 'おてら', '寺廟', VocabTopic.travel),
  _w('お土産', 'おみやげ', '伴手禮', VocabTopic.travel),
  _w('予約', 'よやく', '預約', VocabTopic.travel),
  _w('部屋', 'へや', '房間', VocabTopic.travel),
  _w('鍵', 'かぎ', '鑰匙', VocabTopic.travel),
  _w('パスポート', 'ぱすぽーと', '護照', VocabTopic.travel),
  _w('両替', 'りょうがえ', '換匯', VocabTopic.travel),
  _w('案内', 'あんない', '導覽、指引', VocabTopic.travel),

  // ── 交通 ──
  _w('駅', 'えき', '車站', VocabTopic.transport),
  _w('電車', 'でんしゃ', '電車', VocabTopic.transport),
  _w('地下鉄', 'ちかてつ', '地下鐵', VocabTopic.transport),
  _w('バス', 'ばす', '公車', VocabTopic.transport),
  _w('タクシー', 'たくしー', '計程車', VocabTopic.transport),
  _w('飛行機', 'ひこうき', '飛機', VocabTopic.transport),
  _w('空港', 'くうこう', '機場', VocabTopic.transport),
  _w('切符', 'きっぷ', '車票', VocabTopic.transport),
  _w('新幹線', 'しんかんせん', '新幹線', VocabTopic.transport),
  _w('自転車', 'じてんしゃ', '腳踏車', VocabTopic.transport),
  _w('出口', 'でぐち', '出口', VocabTopic.transport),
  _w('入口', 'いりぐち', '入口', VocabTopic.transport),
  _w('改札', 'かいさつ', '剪票口', VocabTopic.transport),
  _w('乗り換え', 'のりかえ', '轉乘', VocabTopic.transport),
  _w('荷物', 'にもつ', '行李', VocabTopic.transport),

  // ── 餐飲 ──
  _w('レストラン', 'れすとらん', '餐廳', VocabTopic.food),
  _w('水', 'みず', '水', VocabTopic.food),
  _w('お茶', 'おちゃ', '茶', VocabTopic.food),
  _w('ご飯', 'ごはん', '飯', VocabTopic.food),
  _w('肉', 'にく', '肉', VocabTopic.food),
  _w('魚', 'さかな', '魚', VocabTopic.food),
  _w('野菜', 'やさい', '蔬菜', VocabTopic.food),
  _w('果物', 'くだもの', '水果', VocabTopic.food),
  _w('卵', 'たまご', '蛋', VocabTopic.food),
  _w('牛乳', 'ぎゅうにゅう', '牛奶', VocabTopic.food),
  _w('パン', 'ぱん', '麵包', VocabTopic.food),
  _w('寿司', 'すし', '壽司', VocabTopic.food),
  _w('メニュー', 'めにゅー', '菜單', VocabTopic.food),
  _w('注文', 'ちゅうもん', '點餐', VocabTopic.food),
  _w('会計', 'かいけい', '結帳', VocabTopic.food),

  // ── 購物 ──
  _w('店', 'みせ', '商店', VocabTopic.shopping),
  _w('買い物', 'かいもの', '購物', VocabTopic.shopping),
  _w('お金', 'おかね', '錢', VocabTopic.shopping),
  _w('値段', 'ねだん', '價格', VocabTopic.shopping),
  _w('安い', 'やすい', '便宜的', VocabTopic.shopping),
  _w('高い', 'たかい', '貴的、高的', VocabTopic.shopping),
  _w('財布', 'さいふ', '錢包', VocabTopic.shopping),
  _w('コンビニ', 'こんびに', '便利商店', VocabTopic.shopping),
  _w('デパート', 'でぱーと', '百貨公司', VocabTopic.shopping),
  _w('服', 'ふく', '衣服', VocabTopic.shopping),
  _w('靴', 'くつ', '鞋子', VocabTopic.shopping),
  _w('帽子', 'ぼうし', '帽子', VocabTopic.shopping),
  _w('傘', 'かさ', '雨傘', VocabTopic.shopping),
  _w('袋', 'ふくろ', '袋子', VocabTopic.shopping),
  _w('免税', 'めんぜい', '免稅', VocabTopic.shopping),

  // ── 時間 ──
  _w('今日', 'きょう', '今天', VocabTopic.time),
  _w('明日', 'あした', '明天', VocabTopic.time),
  _w('昨日', 'きのう', '昨天', VocabTopic.time),
  _w('今', 'いま', '現在', VocabTopic.time),
  _w('時間', 'じかん', '時間', VocabTopic.time),
  _w('午前', 'ごぜん', '上午', VocabTopic.time),
  _w('午後', 'ごご', '下午', VocabTopic.time),
  _w('朝', 'あさ', '早上', VocabTopic.time),
  _w('昼', 'ひる', '中午、白天', VocabTopic.time),
  _w('夜', 'よる', '晚上', VocabTopic.time),
  _w('週末', 'しゅうまつ', '週末', VocabTopic.time),
  _w('毎日', 'まいにち', '每天', VocabTopic.time),
  _w('何時', 'なんじ', '幾點', VocabTopic.time),
  _w('曜日', 'ようび', '星期', VocabTopic.time),
  _w('休み', 'やすみ', '休息、休假', VocabTopic.time),

  // ── 日常 ──
  _w('人', 'ひと', '人', VocabTopic.daily),
  _w('友達', 'ともだち', '朋友', VocabTopic.daily),
  _w('家族', 'かぞく', '家人', VocabTopic.daily),
  _w('家', 'いえ', '家', VocabTopic.daily),
  _w('学校', 'がっこう', '學校', VocabTopic.daily),
  _w('先生', 'せんせい', '老師', VocabTopic.daily),
  _w('学生', 'がくせい', '學生', VocabTopic.daily),
  _w('名前', 'なまえ', '名字', VocabTopic.daily),
  _w('電話', 'でんわ', '電話', VocabTopic.daily),
  _w('天気', 'てんき', '天氣', VocabTopic.daily),
  _w('雨', 'あめ', '雨', VocabTopic.daily),
  _w('犬', 'いぬ', '狗', VocabTopic.daily),
  _w('猫', 'ねこ', '貓', VocabTopic.daily),
  _w('本', 'ほん', '書', VocabTopic.daily),
  _w('映画', 'えいが', '電影', VocabTopic.daily),

  // ── 職場 ──
  _w('会社', 'かいしゃ', '公司', VocabTopic.work),
  _w('仕事', 'しごと', '工作', VocabTopic.work),
  _w('会議', 'かいぎ', '會議', VocabTopic.work),
  _w('名刺', 'めいし', '名片', VocabTopic.work),
  _w('給料', 'きゅうりょう', '薪水', VocabTopic.work),
  _w('忙しい', 'いそがしい', '忙碌的', VocabTopic.work),
  _w('メール', 'めーる', '電子郵件', VocabTopic.work),
  _w('資料', 'しりょう', '資料', VocabTopic.work),
  _w('残業', 'ざんぎょう', '加班', VocabTopic.work),
  _w('出張', 'しゅっちょう', '出差', VocabTopic.work),
  _w('同僚', 'どうりょう', '同事', VocabTopic.work),
  _w('遅刻', 'ちこく', '遲到', VocabTopic.work),
  _w('約束', 'やくそく', '約定', VocabTopic.work),
  _w('頑張る', 'がんばる', '努力、加油', VocabTopic.work),
  _w('電話番号', 'でんわばんごう', '電話號碼', VocabTopic.work),
]);

/// 以 key（`v_<jp>`）查單字，找不到回傳 null。
VocabWord? findVocab(String key) {
  for (final w in allVocab) {
    if (w.key == key) return w;
  }
  return null;
}
