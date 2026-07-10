import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/core/data/kana_data.dart';
import 'package:kana_trainer/core/logic/quiz_generator.dart';
import 'package:kana_trainer/core/models/kana.dart';
import 'package:kana_trainer/core/models/practice_mode.dart';

QuizGenerator<Kana> kanaGen([int? seed]) => QuizGenerator(
      keyOf: (k) => k.kana,
      rng: seed == null ? null : Random(seed),
    );

void main() {
  group('QuizGenerator', () {
    test('空題庫丟 StateError', () {
      expect(() => kanaGen().next([], {}), throwsStateError);
    });

    test('單一題庫可重複出同題', () {
      final pool = [findKana('か')!];
      expect(kanaGen(1).next(pool, {}, previous: pool.first).kana, 'か');
    });

    test('連續兩題不重複', () {
      final pool = PracticeMode.hiragana.buildPool(allKana);
      final gen = kanaGen(42);
      var prev = gen.next(pool, {});
      for (var i = 0; i < 200; i++) {
        final cur = gen.next(pool, {}, previous: prev);
        expect(cur.kana, isNot(prev.kana));
        prev = cur;
      }
    });

    test('熟練度低的題目出現機率高', () {
      final ka = findKana('か')!;
      final ki = findKana('き')!;
      final pool = [ka, ki];
      // か 熟練 5（weight 1），き 熟練 0（weight 6）
      final mastery = {'か': 5, 'き': 0};
      final gen = kanaGen(7);
      var kiCount = 0;
      for (var i = 0; i < 1000; i++) {
        if (gen.next(pool, mastery).kana == 'き') kiCount++;
      }
      // 期望值 6/7 ≈ 857，容忍區間
      expect(kiCount, greaterThan(780));
    });

    test('weighted=false 純隨機仍能出所有題', () {
      final pool = PracticeMode.hiragana.buildPool(allKana);
      final gen = kanaGen(3);
      final seen = <String>{};
      for (var i = 0; i < 2000; i++) {
        seen.add(gen.next(pool, {}, weighted: false).kana);
      }
      expect(seen.length, pool.length);
    });

    test('熟練度超界 clamp 到 0..5', () {
      final pool = [findKana('か')!, findKana('き')!];
      // 不丟例外即可
      kanaGen(9).next(pool, {'か': 99, 'き': -3});
    });
  });

  group('QuizGenerator.buildOptions', () {
    test('回傳 4 個不重複選項且含正解', () {
      final pool = PracticeMode.hiragana.buildPool(allKana);
      final gen = kanaGen(5);
      for (var i = 0; i < 50; i++) {
        final kana = gen.next(pool, {});
        final (options, correctIndex) =
            gen.buildOptions(kana, pool, valueOf: (k) => k.romaji);
        expect(options.length, 4);
        expect(options.toSet().length, 4); // 無重複
        expect(options[correctIndex], kana.romaji);
      }
    });

    test('題庫過小時從 fallback 補滿', () {
      final ka = findKana('か')!;
      final (options, correctIndex) = kanaGen(2).buildOptions(
        ka,
        [ka],
        valueOf: (k) => k.romaji,
        fallback: allKana,
      );
      expect(options.length, 4);
      expect(options[correctIndex], 'ka');
    });
  });
}
