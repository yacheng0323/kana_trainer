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
}
