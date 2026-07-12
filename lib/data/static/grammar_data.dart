import 'package:kana_trainer/domain/entities/grammar.dart';

/// N5 文法課程（M4：12 課，線性解鎖）。
/// 維護方式：每課 id 唯一（g01..g12），quiz 固定 3 題 4 選 1。
const List<GrammarPoint> allGrammar = [
  GrammarPoint(
    id: 'g01',
    title: '〜です（名詞句）',
    explanation: '名詞句基本形「AはBです」＝A是B。\n'
        '否定形是「Bでは（じゃ）ありません」。\n'
        '「です」讓句子變禮貌體。',
    examples: [
      GrammarExample('わたしは学生です。', '我是學生。'),
      GrammarExample('田中さんは先生では ありません。', '田中先生不是老師。'),
    ],
    quiz: [
      GrammarQuiz(
        question: 'わたし＿＿学生です。',
        options: ['は', 'を', 'に', 'で'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: 'これはペン＿＿。',
        options: ['です', 'ます', 'か', 'に'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: '田中さんは先生＿＿ありません。',
        options: ['では', 'です', 'には', 'をば'],
        correctIndex: 0,
      ),
    ],
  ),
  GrammarPoint(
    id: 'g02',
    title: '〜も（也）',
    explanation: '「も」＝也，表示同樣的事，放在主題後面取代「は」。',
    examples: [
      GrammarExample('わたしも学生です。', '我也是學生。'),
      GrammarExample('これも百円です。', '這個也是一百日圓。'),
    ],
    quiz: [
      GrammarQuiz(
        question: '田中さんは学生です。山田さん＿＿学生です。',
        options: ['も', 'は', 'が', 'を'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: 'これ＿＿百円です。',
        options: ['も', 'を', 'に', 'で'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: 'わたし＿＿行きます。',
        options: ['も', 'を', 'の', 'で'],
        correctIndex: 0,
      ),
    ],
  ),
  GrammarPoint(
    id: 'g03',
    title: '〜の（的）',
    explanation: '「AのB」＝A的B，表示所有、所屬或內容。',
    examples: [
      GrammarExample('これはわたしの本です。', '這是我的書。'),
      GrammarExample('日本の車は有名です。', '日本的車很有名。'),
    ],
    quiz: [
      GrammarQuiz(
        question: 'これはわたし＿＿傘です。',
        options: ['の', 'は', 'を', 'も'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: '日本＿＿食べ物が好きです。',
        options: ['の', 'に', 'で', 'へ'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: 'あれは先生＿＿車です。',
        options: ['の', 'が', 'は', 'か'],
        correctIndex: 0,
      ),
    ],
  ),
  GrammarPoint(
    id: 'g04',
    title: '〜を＋動詞ます',
    explanation: '他動詞的受詞用「を」標示。\n'
        '動詞禮貌形「〜ます」、否定「〜ません」。',
    examples: [
      GrammarExample('水を飲みます。', '喝水。'),
      GrammarExample('本を読みません。', '不讀書。'),
    ],
    quiz: [
      GrammarQuiz(
        question: 'パン＿＿食べます。',
        options: ['を', 'は', 'に', 'の'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: '映画＿＿見ます。',
        options: ['を', 'が', 'で', 'へ'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: 'お酒を飲み＿＿。',
        options: ['ません', 'ないです', 'ではない', 'くない'],
        correctIndex: 0,
      ),
    ],
  ),
  GrammarPoint(
    id: 'g05',
    title: '〜に／へ（方向・時間）',
    explanation: '移動的目的地用「に」或「へ」。\n'
        '時間點（幾點、星期幾）用「に」。',
    examples: [
      GrammarExample('学校に行きます。', '去學校。'),
      GrammarExample('七時に起きます。', '七點起床。'),
    ],
    quiz: [
      GrammarQuiz(
        question: '日本＿＿行きます。',
        options: ['に', 'を', 'で', 'の'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: '六時＿＿起きます。',
        options: ['に', 'で', 'を', 'は'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: '友達の家＿＿行きます。',
        options: ['へ', 'を', 'が', 'も'],
        correctIndex: 0,
      ),
    ],
  ),
  GrammarPoint(
    id: 'g06',
    title: '〜で（場所・手段）',
    explanation: '動作發生的場所用「で」。\n'
        '手段、方法、工具也用「で」。',
    examples: [
      GrammarExample('レストランで食べます。', '在餐廳吃。'),
      GrammarExample('バスで行きます。', '搭公車去。'),
    ],
    quiz: [
      GrammarQuiz(
        question: '図書館＿＿勉強します。',
        options: ['で', 'に', 'を', 'の'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: '電車＿＿会社へ行きます。',
        options: ['で', 'を', 'が', 'は'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: 'はし＿＿食べます。',
        options: ['で', 'に', 'へ', 'も'],
        correctIndex: 0,
      ),
    ],
  ),
  GrammarPoint(
    id: 'g07',
    title: 'あります／います（存在）',
    explanation: '無生命（東西）的存在用「あります」，\n'
        '有生命（人、動物）用「います」。\n'
        '存在的主語用「が」。',
    examples: [
      GrammarExample('机の上に本があります。', '桌上有書。'),
      GrammarExample('公園に犬がいます。', '公園裡有狗。'),
    ],
    quiz: [
      GrammarQuiz(
        question: '部屋に猫＿＿います。',
        options: ['が', 'を', 'で', 'の'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: '駅の前にコンビニが＿＿。',
        options: ['あります', 'います', 'です', 'します'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: '教室に学生が＿＿。',
        options: ['います', 'あります', 'です', 'ます'],
        correctIndex: 0,
      ),
    ],
  ),
  GrammarPoint(
    id: 'g08',
    title: '〜か（疑問句）',
    explanation: '句尾加「か」變成疑問句。\n'
        '常用疑問詞：何（什麼）、どこ（哪裡）、誰（誰）、いつ（何時）。',
    examples: [
      GrammarExample('これは何ですか。', '這是什麼？'),
      GrammarExample('トイレはどこですか。', '廁所在哪裡？'),
    ],
    quiz: [
      GrammarQuiz(
        question: 'あなたは学生です＿＿。',
        options: ['か', 'よ', 'を', 'の'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: 'これは＿＿ですか。',
        options: ['何', 'どこ', '誰か', 'いつも'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: '駅は＿＿ですか。',
        options: ['どこ', '何', 'どれも', 'なぜか'],
        correctIndex: 0,
      ),
    ],
  ),
  GrammarPoint(
    id: 'g09',
    title: 'い形容詞',
    explanation: 'い形容詞直接修飾名詞（高い山）。\n'
        '否定「〜くない」、過去「〜かった」。',
    examples: [
      GrammarExample('この本は高くないです。', '這本書不貴。'),
      GrammarExample('昨日は寒かったです。', '昨天很冷。'),
    ],
    quiz: [
      GrammarQuiz(
        question: 'この店は＿＿です。',
        options: ['安い', '安いの', '安いだ', '安いに'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: '昨日は＿＿です。',
        options: ['寒かった', '寒いた', '寒くた', '寒いでした'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: 'この映画は面白＿＿です。',
        options: ['くない', 'じゃない', 'ではない', 'ないく'],
        correctIndex: 0,
      ),
    ],
  ),
  GrammarPoint(
    id: 'g10',
    title: 'な形容詞',
    explanation: 'な形容詞修飾名詞時加「な」（きれいな部屋）。\n'
        '否定「では（じゃ）ありません」。',
    examples: [
      GrammarExample('きれいな部屋ですね。', '好漂亮的房間啊。'),
      GrammarExample('この町は静かです。', '這個城鎮很安靜。'),
    ],
    quiz: [
      GrammarQuiz(
        question: '＿＿部屋ですね。',
        options: ['きれいな', 'きれいの', 'きれいい', 'きれいで'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: 'この公園は＿＿です。',
        options: ['静か', '静かな', '静かの', '静かに'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: '日本語は簡単＿＿ありません。',
        options: ['では', 'くは', 'には', 'とは'],
        correctIndex: 0,
      ),
    ],
  ),
  GrammarPoint(
    id: 'g11',
    title: 'て形（〜てください／〜ています）',
    explanation: '「〜てください」＝請（做）〜。\n'
        '「〜ています」＝正在〜（進行中）。',
    examples: [
      GrammarExample('ここに名前を書いてください。', '請在這裡寫名字。'),
      GrammarExample('今、ご飯を食べています。', '現在正在吃飯。'),
    ],
    quiz: [
      GrammarQuiz(
        question: 'ちょっと待って＿＿。',
        options: ['ください', 'います', 'ました', 'ませんか'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: '雨が降って＿＿。',
        options: ['います', 'あります', 'です', 'ください'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: '写真を＿＿ください。',
        options: ['撮って', '撮りて', '撮るて', '撮て'],
        correctIndex: 0,
      ),
    ],
  ),
  GrammarPoint(
    id: 'g12',
    title: '過去形（〜ました／〜ませんでした）',
    explanation: '動詞過去「〜ました」。\n'
        '否定「〜ません」、過去否定「〜ませんでした」。',
    examples: [
      GrammarExample('昨日、映画を見ました。', '昨天看了電影。'),
      GrammarExample('朝ごはんを食べませんでした。', '沒吃早餐。'),
    ],
    quiz: [
      GrammarQuiz(
        question: '昨日、日本語を勉強し＿＿。',
        options: ['ました', 'ます', 'ません', 'ましょう'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: 'お酒は飲み＿＿。',
        options: ['ません', 'ないです', 'なかった', 'ずです'],
        correctIndex: 0,
      ),
      GrammarQuiz(
        question: '先週、どこも行き＿＿でした。',
        options: ['ません', 'ました', 'まして', 'ます'],
        correctIndex: 0,
      ),
    ],
  ),
];

GrammarPoint? findGrammar(String id) {
  for (final g in allGrammar) {
    if (g.id == id) return g;
  }
  return null;
}
