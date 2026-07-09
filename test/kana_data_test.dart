import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/core/data/kana_data.dart';
import 'package:kana_trainer/core/models/kana.dart';
import 'package:kana_trainer/core/models/practice_mode.dart';

void main() {
  group('kana_data', () {
    test('數量正確：清音46 濁音20 半濁音5 拗音33，各 ×2 腳本', () {
      int count(KanaCategory c, KanaType t) =>
          allKana.where((k) => k.category == c && k.type == t).length;
      expect(count(KanaCategory.seion, KanaType.hiragana), 46);
      expect(count(KanaCategory.seion, KanaType.katakana), 46);
      expect(count(KanaCategory.dakuon, KanaType.hiragana), 20);
      expect(count(KanaCategory.handakuon, KanaType.hiragana), 5);
      expect(count(KanaCategory.youon, KanaType.hiragana), 33);
      expect(allKana.length, (46 + 20 + 5 + 33) * 2);
    });

    test('kana 字元不重複（可當唯一 id）', () {
      final keys = allKana.map((k) => k.kana).toSet();
      expect(keys.length, allKana.length);
    });

    test('片假名由平假名位移生成', () {
      expect(hiraganaToKatakana('か'), 'カ');
      expect(hiraganaToKatakana('きゃ'), 'キャ');
      expect(findKana('カ')!.romaji, 'ka');
      expect(findKana('シ')!.aliases, contains('si'));
    });

    test('別名掛載正確', () {
      expect(findKana('し')!.aliases, ['si']);
      expect(findKana('じゃ')!.aliases, containsAll(['jya', 'zya']));
      expect(findKana('ん')!.aliases, contains('nn'));
    });
  });

  group('PracticeMode.buildPool', () {
    test('平假名模式只含平假名清音', () {
      final pool = PracticeMode.hiragana.buildPool(allKana);
      expect(pool.length, 46);
      expect(
        pool.every((k) =>
            k.type == KanaType.hiragana && k.category == KanaCategory.seion),
        isTrue,
      );
    });

    test('濁音模式含濁音+半濁音兩腳本', () {
      final pool = PracticeMode.dakuon.buildPool(allKana);
      expect(pool.length, (20 + 5) * 2);
    });

    test('拗音模式 66 筆', () {
      expect(PracticeMode.youon.buildPool(allKana).length, 66);
    });

    test('混合模式 = 全部', () {
      expect(PracticeMode.mixed.buildPool(allKana).length, allKana.length);
    });

    test('錯題模式只含錯題', () {
      final pool =
          PracticeMode.wrongReview.buildPool(allKana, wrongKanaKeys: {'か', 'シ'});
      expect(pool.map((k) => k.kana).toSet(), {'か', 'シ'});
    });
  });
}
