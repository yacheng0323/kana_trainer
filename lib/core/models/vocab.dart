/// 單字主題（M1：7 主題 × 15 詞，全 N5）。
enum VocabTopic {
  travel('旅遊'),
  transport('交通'),
  food('餐飲'),
  shopping('購物'),
  time('時間'),
  daily('日常'),
  work('職場');

  final String label;
  const VocabTopic(this.label);
}

/// 單一單字。[jp] 全庫唯一，熟練度/錯題 key = `v_<jp>`。
class VocabWord {
  final String jp; // 顯示字（漢字或假名）
  final String reading; // 假名讀音
  final String zh; // 中文意思（繁體）
  final VocabTopic topic;
  final int jlpt;

  const VocabWord({
    required this.jp,
    required this.reading,
    required this.zh,
    required this.topic,
    this.jlpt = 5,
  });

  String get key => 'v_$jp';

  @override
  String toString() => 'VocabWord($jp → $zh)';
}

/// 練習範圍。
enum VocabPool {
  all('全部單字'),
  travel('旅遊'),
  transport('交通'),
  food('餐飲'),
  shopping('購物'),
  time('時間'),
  daily('日常'),
  work('職場'),
  wrongReview('單字錯題複習');

  final String label;
  const VocabPool(this.label);

  VocabTopic? get topic => switch (this) {
        VocabPool.travel => VocabTopic.travel,
        VocabPool.transport => VocabTopic.transport,
        VocabPool.food => VocabTopic.food,
        VocabPool.shopping => VocabTopic.shopping,
        VocabPool.time => VocabTopic.time,
        VocabPool.daily => VocabTopic.daily,
        VocabPool.work => VocabTopic.work,
        _ => null,
      };

  List<VocabWord> buildPool(
    List<VocabWord> allWords, {
    Set<String> wrongKeys = const {},
  }) {
    return switch (this) {
      VocabPool.all => List.of(allWords),
      VocabPool.wrongReview =>
        allWords.where((w) => wrongKeys.contains(w.key)).toList(),
      _ => allWords.where((w) => w.topic == topic).toList(),
    };
  }
}
