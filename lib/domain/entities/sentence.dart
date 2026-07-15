/// 情境場景。
enum Scene {
  airport('機場'),
  train('電車'),
  hotel('飯店'),
  restaurant('餐廳'),
  shopping('購物');

  final String label;
  const Scene(this.label);
}

/// 情境句子。以 [chunks]（語塊）維護：
/// - 克漏字：挖掉 [blankIndex] 的語塊，4 選 1
/// - 重組：打亂全部語塊，按順序點回
class Sentence {
  final List<String> chunks; // 正確順序的語塊
  final int blankIndex; // 克漏字挖空位置
  final String zh; // 中文意思
  final Scene scene;
  final int jlpt; // JLPT 等級（5..1，靜態種子全 5）

  const Sentence({
    required this.chunks,
    required this.blankIndex,
    required this.zh,
    required this.scene,
    this.jlpt = 5,
  });

  String get jp => chunks.join();
  String get key => 's_$jp';
  String get blank => chunks[blankIndex];

  /// 克漏字題面（挖空處以 ＿＿ 顯示）。
  String get clozeText => [
        for (var i = 0; i < chunks.length; i++)
          i == blankIndex ? '＿＿' : chunks[i],
      ].join();
}

/// 句子練習範圍。
enum ScenePool {
  all('全部情境'),
  airport('機場'),
  train('電車'),
  hotel('飯店'),
  restaurant('餐廳'),
  shopping('購物'),
  wrongReview('句子錯題複習');

  final String label;
  const ScenePool(this.label);

  Scene? get scene => switch (this) {
        ScenePool.airport => Scene.airport,
        ScenePool.train => Scene.train,
        ScenePool.hotel => Scene.hotel,
        ScenePool.restaurant => Scene.restaurant,
        ScenePool.shopping => Scene.shopping,
        _ => null,
      };

  List<Sentence> buildPool(
    List<Sentence> all, {
    Set<String> wrongKeys = const {},
  }) {
    return switch (this) {
      ScenePool.all => List.of(all),
      ScenePool.wrongReview =>
        all.where((s) => wrongKeys.contains(s.key)).toList(),
      _ => all.where((s) => s.scene == scene).toList(),
    };
  }
}

/// 句子題型。
enum SentenceQuizType { cloze, reorder }
