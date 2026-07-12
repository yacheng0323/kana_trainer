import 'package:kana_trainer/domain/entities/kana.dart';

/// 練習模式。
enum PracticeMode {
  hiragana('平假名練習'),
  katakana('片假名練習'),
  dakuon('濁音・半濁音練習'),
  youon('拗音練習'),
  mixed('混合練習'),
  wrongReview('錯題複習');

  final String label;
  const PracticeMode(this.label);

  /// 依模式從 [all] 篩出題庫。[wrongKanaKeys] 只在 wrongReview 使用。
  List<Kana> buildPool(List<Kana> all, {Set<String> wrongKanaKeys = const {}}) {
    switch (this) {
      case PracticeMode.hiragana:
        return all
            .where((k) =>
                k.type == KanaType.hiragana && k.category == KanaCategory.seion)
            .toList();
      case PracticeMode.katakana:
        return all
            .where((k) =>
                k.type == KanaType.katakana && k.category == KanaCategory.seion)
            .toList();
      case PracticeMode.dakuon:
        return all
            .where((k) =>
                k.category == KanaCategory.dakuon ||
                k.category == KanaCategory.handakuon)
            .toList();
      case PracticeMode.youon:
        return all.where((k) => k.category == KanaCategory.youon).toList();
      case PracticeMode.mixed:
        return List.of(all);
      case PracticeMode.wrongReview:
        return all.where((k) => wrongKanaKeys.contains(k.kana)).toList();
    }
  }
}
