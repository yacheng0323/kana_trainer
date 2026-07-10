import 'dart:math';

/// 出題演算法（泛型：假名 Kana / 單字 VocabWord 共用）。
///
/// [keyOf] 取熟練度 map 的 key；[valueOf]（buildOptions）取選項顯示文字。
/// 加權隨機：weight = 6 - 熟練度（0..5），熟練度越低越常出現。
/// weighted=false 時為純隨機（基本模式）。
/// 連續兩題不出同一題（題庫多於一題時排除上一題）。
class QuizGenerator<T> {
  final Random _rng;
  final String Function(T) keyOf;

  QuizGenerator({required this.keyOf, Random? rng}) : _rng = rng ?? Random();

  T next(
    List<T> pool,
    Map<String, int> mastery, {
    T? previous,
    bool weighted = true,
  }) {
    if (pool.isEmpty) {
      throw StateError('題庫為空，無法出題');
    }
    var candidates = pool;
    if (previous != null && pool.length > 1) {
      final prevKey = keyOf(previous);
      candidates = pool.where((k) => keyOf(k) != prevKey).toList();
    }
    if (!weighted) {
      return candidates[_rng.nextInt(candidates.length)];
    }
    final weights = candidates
        .map((k) => 6 - (mastery[keyOf(k)] ?? 0).clamp(0, 5))
        .toList();
    final total = weights.fold<int>(0, (a, b) => a + b);
    var roll = _rng.nextInt(total);
    for (var i = 0; i < candidates.length; i++) {
      roll -= weights[i];
      if (roll < 0) return candidates[i];
    }
    return candidates.last; // 理論上不會到這（防浮點/邊界）
  }

  /// 4 選 1 選項：正解 + 3 個干擾項（顯示文字不重複）。
  /// 干擾項優先取同題庫（同類型混淆度高），不足時從 [fallback] 補。
  /// 回傳 (options, correctIndex)。
  (List<String>, int) buildOptions(
    T current,
    List<T> pool, {
    required String Function(T) valueOf,
    List<T> fallback = const [],
  }) {
    final used = <String>{valueOf(current)};
    final distractors = <String>[];

    void take(List<T> source) {
      final shuffled = List.of(source)..shuffle(_rng);
      for (final k in shuffled) {
        if (distractors.length >= 3) return;
        final v = valueOf(k);
        if (used.add(v)) distractors.add(v);
      }
    }

    take(pool);
    if (distractors.length < 3) take(fallback);

    final options = [valueOf(current), ...distractors]..shuffle(_rng);
    return (options, options.indexOf(valueOf(current)));
  }
}
