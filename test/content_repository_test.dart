import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/data/static/grammar_data.dart';
import 'package:kana_trainer/data/static/sentence_data.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/models/dynamic_content.dart';
import 'package:kana_trainer/domain/repositories/key_value_store.dart';

void main() {
  late DynamicContentStore store;
  late MergedContentRepository repo;

  setUp(() {
    store = DynamicContentStore(InMemoryKeyValueStore());
    repo = MergedContentRepository(store);
  });

  test('動態池空 → 回靜態全量', () {
    expect(repo.vocab().length, allVocab.length);
    expect(repo.sentences().length, allSentences.length);
    final g1 = allGrammar.first;
    expect(repo.grammarQuiz(g1.id).length, g1.quiz.length);
  });

  test('動態單字合併在後、findVocab 查得到', () async {
    const w = VocabWord(
        jp: '搭乗券', reading: 'とうじょうけん', zh: '登機證', topic: VocabTopic.travel);
    await store.addVocab([w], existingKeys: {});
    expect(repo.vocab().length, allVocab.length + 1);
    expect(repo.findVocab('v_搭乗券')!.zh, '登機證');
    expect(repo.findVocab('v_不存在'), isNull);
    // 靜態的照常查得到
    expect(repo.findVocab('v_駅')!.zh, '車站');
  });

  test('grammarQuiz 合併該課動態題、不混他課', () async {
    final g1 = allGrammar.first;
    const quiz = GrammarQuiz(
        question: '新題＿＿', options: ['は', 'が', 'を', 'に'], correctIndex: 0);
    await store.addGrammarQuiz([
      DynamicGrammarQuiz(lessonId: g1.id, quiz: quiz),
      const DynamicGrammarQuiz(lessonId: 'g99', quiz: quiz),
    ], existingKeys: {});
    expect(repo.grammarQuiz(g1.id).length, g1.quiz.length + 1);
  });
}
