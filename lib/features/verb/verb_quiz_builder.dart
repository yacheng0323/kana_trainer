import 'dart:math';

import 'package:kana_trainer/data/static/verb_data.dart';
import 'package:kana_trainer/domain/entities/verb.dart';
import 'package:kana_trainer/domain/models/verb_models.dart';
export 'package:kana_trainer/domain/models/verb_models.dart';

/// 出一輪動詞變化題。
/// 干擾項 = 同動詞的其他變化形（最混淆）+ 其他動詞的同變化形。
class VerbQuizBuilder {
  static List<VerbQuestion> build({
    VerbForm? form, // null = 四種混合
    int count = 10,
    Random? rng,
  }) {
    final random = rng ?? Random();
    final verbs = List.of(allVerbs)..shuffle(random);
    final questions = <VerbQuestion>[];

    for (final verb in verbs.take(count)) {
      final target =
          form ?? VerbForm.values[random.nextInt(VerbForm.values.length)];
      final correct = verb.formOf(target);

      final distractors = <String>{};
      // 同動詞其他形（優先，最容易混淆）
      final otherForms = VerbForm.values.where((f) => f != target).toList()
        ..shuffle(random);
      for (final f in otherForms.take(2)) {
        final v = verb.formOf(f);
        if (v != correct) distractors.add(v);
      }
      // 其他動詞的同形補滿
      final others = allVerbs.where((v) => v.dict != verb.dict).toList()
        ..shuffle(random);
      for (final other in others) {
        if (distractors.length >= 3) break;
        final v = other.formOf(target);
        if (v != correct) distractors.add(v);
      }

      final options = [correct, ...distractors.take(3)]..shuffle(random);
      questions.add(VerbQuestion(
        verb: verb,
        form: target,
        options: options,
        correctIndex: options.indexOf(correct),
      ));
    }
    return questions;
  }
}
