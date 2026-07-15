import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/static/grammar_data.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/ai_analysis/ai_analysis_page.dart';
import 'package:kana_trainer/features/ai_chat/ai_chat_page.dart';
import 'package:kana_trainer/features/ai_quiz/ai_quiz_page.dart';
import 'package:kana_trainer/features/grammar/grammar_list_page.dart';
import 'package:kana_trainer/features/verb/verb_drill_page.dart';
import 'package:kana_trainer/features/grammar/grammar_progress_notifier.dart';
import 'package:kana_trainer/features/listening/listening_page.dart';
import 'package:kana_trainer/features/progress/srs_notifier.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:kana_trainer/features/sentence/sentence_practice_page.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'package:kana_trainer/features/vocab/vocab_practice_page.dart';
import 'package:kana_trainer/features/home/widgets/home_cards.dart';

/// Tab 2：主題學習 — 單字（含 SRS 複習、聽力）、情境句子、文法課。
class TopicsTab extends ConsumerWidget {
  const TopicsTab({super.key});

  static const _vocabIcons = {
    VocabPool.all: Icons.style,
    VocabPool.travel: Icons.luggage,
    VocabPool.transport: Icons.train,
    VocabPool.food: Icons.ramen_dining,
    VocabPool.shopping: Icons.shopping_bag,
    VocabPool.time: Icons.schedule,
    VocabPool.daily: Icons.home,
    VocabPool.work: Icons.work,
    VocabPool.wrongReview: Icons.replay,
    VocabPool.dueReview: Icons.event_repeat,
  };

  static const _sceneIcons = {
    ScenePool.all: Icons.forum,
    ScenePool.airport: Icons.flight,
    ScenePool.train: Icons.directions_subway,
    ScenePool.hotel: Icons.hotel,
    ScenePool.restaurant: Icons.restaurant,
    ScenePool.shopping: Icons.storefront,
    ScenePool.wrongReview: Icons.replay,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabWrong = ref.watch(vocabWrongProvider);
    final sentenceWrong = ref.watch(sentenceWrongProvider);
    ref.watch(srsProvider);
    final dueCount = ref
        .read(srsProvider.notifier)
        .dueKeys(allVocab.map((w) => w.key))
        .length;
    final grammarDone = ref.watch(grammarProgressProvider).length;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        TabHeader(
          title: '主題學習',
          subtitle: dueCount > 0 ? '今日待複習 $dueCount 個單字 🔔' : '單字・句子・文法',
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('練習等級'),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 5, label: Text('N5')),
                    ButtonSegment(value: 4, label: Text('N4')),
                    ButtonSegment(value: 3, label: Text('N3')),
                    ButtonSegment(value: 2, label: Text('N2')),
                    ButtonSegment(value: 1, label: Text('N1')),
                  ],
                  selected: {ref.watch(settingsProvider).jlptLevel},
                  onSelectionChanged: (sel) => ref
                      .read(settingsProvider.notifier)
                      .update((s) => s.copyWith(jlptLevel: sel.first)),
                ),
              ),
              const SizedBox(height: 20),
              SectionTitle('單字（N${ref.watch(settingsProvider).jlptLevel}）'),
              const SizedBox(height: 10),
              EntryGrid(
                children: [
                  EntryCard(
                    icon: Icons.headphones,
                    iconBg: AppColors.indigo,
                    iconColor: AppColors.gold,
                    label: '聽力測驗',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ListeningPage()),
                    ),
                  ),
                  for (final pool in VocabPool.values)
                    if ((pool != VocabPool.wrongReview ||
                            vocabWrong.isNotEmpty) &&
                        (pool != VocabPool.dueReview || dueCount > 0))
                      EntryCard(
                        icon: _vocabIcons[pool]!,
                        iconBg: AppColors.gold,
                        iconColor: AppColors.indigo,
                        label: pool.label,
                        badge: pool == VocabPool.wrongReview
                            ? '${vocabWrong.length}'
                            : pool == VocabPool.dueReview
                                ? '$dueCount'
                                : null,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VocabPracticePage(pool: pool),
                          ),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 22),
              const SectionTitle('情境句子（40 句）'),
              const SizedBox(height: 10),
              EntryGrid(
                children: [
                  for (final pool in ScenePool.values)
                    if (pool != ScenePool.wrongReview ||
                        sentenceWrong.isNotEmpty)
                      EntryCard(
                        icon: _sceneIcons[pool]!,
                        iconBg: AppColors.green,
                        label: pool.label,
                        badge: pool == ScenePool.wrongReview
                            ? '${sentenceWrong.length}'
                            : null,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SentencePracticePage(pool: pool),
                          ),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 22),
              const SectionTitle('文法'),
              const SizedBox(height: 10),
              _GrammarEntryCard(
                doneCount: grammarDone,
                total: allGrammar.length,
              ),
              const SizedBox(height: 10),
              EntryGrid(
                children: [
                  EntryCard(
                    icon: Icons.fitness_center,
                    iconBg: AppColors.red,
                    label: '動詞變化訓練',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VerbDrillPage()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const SectionTitle('AI 功能'),
              const SizedBox(height: 10),
              EntryGrid(
                children: [
                  EntryCard(
                    icon: Icons.auto_awesome,
                    iconBg: AppColors.gold,
                    iconColor: AppColors.indigo,
                    label: 'AI 全新題目',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiQuizPage()),
                    ),
                  ),
                  EntryCard(
                    icon: Icons.forum,
                    iconBg: AppColors.indigo,
                    iconColor: AppColors.gold,
                    label: 'AI 情境對話',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiChatPage()),
                    ),
                  ),
                  EntryCard(
                    icon: Icons.psychology,
                    iconBg: AppColors.green,
                    label: 'AI 弱點分析',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiAnalysisPage()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 文法課入口卡（完成進度條）。
class _GrammarEntryCard extends StatelessWidget {
  final int doneCount;
  final int total;

  const _GrammarEntryCard({required this.doneCount, required this.total});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GrammarListPage()),
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.indigo, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.menu_book,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '文法課程',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.indigo,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : doneCount / total,
                        minHeight: 6,
                        backgroundColor: const Color(0x1422254A),
                        color: AppColors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$doneCount/$total',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.indigo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
