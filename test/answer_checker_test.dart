import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/static/kana_data.dart';
import 'package:kana_trainer/domain/logic/answer_checker.dart';

void main() {
  group('AnswerChecker', () {
    final ka = findKana('か')!;
    final shi = findKana('し')!;
    final ja = findKana('じゃ')!;

    test('正確答案', () {
      expect(AnswerChecker.check(ka, 'ka'), isTrue);
    });

    test('trim 前後空白', () {
      expect(AnswerChecker.check(ka, '  ka  '), isTrue);
      expect(AnswerChecker.check(ka, '\tka\n'), isTrue);
    });

    test('預設不區分大小寫', () {
      expect(AnswerChecker.check(ka, 'Ka'), isTrue);
      expect(AnswerChecker.check(ka, 'KA'), isTrue);
    });

    test('caseSensitive=true 時大寫不算對', () {
      expect(AnswerChecker.check(ka, 'Ka', caseSensitive: true), isFalse);
      expect(AnswerChecker.check(ka, 'ka', caseSensitive: true), isTrue);
    });

    test('別名可接受：し=shi/si、じゃ=ja/jya/zya', () {
      expect(AnswerChecker.check(shi, 'shi'), isTrue);
      expect(AnswerChecker.check(shi, 'si'), isTrue);
      expect(AnswerChecker.check(ja, 'ja'), isTrue);
      expect(AnswerChecker.check(ja, 'jya'), isTrue);
      expect(AnswerChecker.check(ja, 'zya'), isTrue);
    });

    test('常見別名：ち=ti、つ=tu、ふ=hu、じ=zi', () {
      expect(AnswerChecker.check(findKana('ち')!, 'ti'), isTrue);
      expect(AnswerChecker.check(findKana('つ')!, 'tu'), isTrue);
      expect(AnswerChecker.check(findKana('ふ')!, 'hu'), isTrue);
      expect(AnswerChecker.check(findKana('じ')!, 'zi'), isTrue);
    });

    test('錯誤答案、空字串', () {
      expect(AnswerChecker.check(ka, 'ki'), isFalse);
      expect(AnswerChecker.check(ka, ''), isFalse);
      expect(AnswerChecker.check(ka, '   '), isFalse);
    });
  });
}
