import 'dart:math';

import '../models/kana.dart';

/// 出題演算法。
///
/// 加權隨機：weight = 6 - 熟練度（0..5），熟練度越低越常出現。
/// weighted=false 時為純隨機（基本模式）。
/// 連續兩題不出同一字（題庫多於一題時排除上一題）。
class QuizGenerator {
  final Random _rng;

  QuizGenerator([Random? rng]) : _rng = rng ?? Random();

  Kana next(
    List<Kana> pool,
    Map<String, int> mastery, {
    Kana? previous,
    bool weighted = true,
  }) {
    if (pool.isEmpty) {
      throw StateError('題庫為空，無法出題');
    }
    var candidates = pool;
    if (previous != null && pool.length > 1) {
      candidates = pool.where((k) => k.kana != previous.kana).toList();
    }
    if (!weighted) {
      return candidates[_rng.nextInt(candidates.length)];
    }
    final weights = candidates
        .map((k) => 6 - (mastery[k.kana] ?? 0).clamp(0, 5))
        .toList();
    final total = weights.fold<int>(0, (a, b) => a + b);
    var roll = _rng.nextInt(total);
    for (var i = 0; i < candidates.length; i++) {
      roll -= weights[i];
      if (roll < 0) return candidates[i];
    }
    return candidates.last; // 理論上不會到這（防浮點/邊界）
  }

  /// 4 選 1 選項：正解 + 3 個干擾項（romaji 不重複）。
  /// 干擾項優先取同題庫（同類型混淆度高），不足時從 [fallback] 補。
  /// 回傳 (options, correctIndex)。
  (List<String>, int) buildOptions(
    Kana current,
    List<Kana> pool, {
    List<Kana> fallback = const [],
  }) {
    final used = <String>{current.romaji};
    final distractors = <String>[];

    void take(List<Kana> source) {
      final shuffled = List.of(source)..shuffle(_rng);
      for (final k in shuffled) {
        if (distractors.length >= 3) return;
        if (used.add(k.romaji)) distractors.add(k.romaji);
      }
    }

    take(pool);
    if (distractors.length < 3) take(fallback);

    final options = [current.romaji, ...distractors]..shuffle(_rng);
    return (options, options.indexOf(current.romaji));
  }
}
