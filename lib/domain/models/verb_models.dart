import 'package:kana_trainer/domain/entities/verb.dart';

/// 動詞變化題：辭書形 → 目標變化形，4 選 1。
class VerbQuestion {
  final Verb verb;
  final VerbForm form;
  final List<String> options;
  final int correctIndex;

  const VerbQuestion({
    required this.verb,
    required this.form,
    required this.options,
    required this.correctIndex,
  });
}
