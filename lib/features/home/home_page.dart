import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/kana_data.dart';
import '../../core/models/kana.dart';
import '../../core/models/practice_mode.dart';
import '../../core/data/grammar_data.dart';
import '../../core/models/sentence.dart';
import '../../core/models/vocab.dart';
import '../../core/theme/app_theme.dart';
import '../grammar/grammar_list_page.dart';
import '../grammar/grammar_progress_notifier.dart';
import '../practice/practice_page.dart';
import '../sentence/sentence_practice_page.dart';
import '../vocab/vocab_practice_page.dart';
import '../../core/data/vocab_data.dart';
import '../progress/mastery_notifier.dart';
import '../progress/srs_notifier.dart';
import '../progress/stats_notifier.dart';
import '../progress/wrong_list_page.dart';
import '../progress/wrong_notifier.dart';
import '../settings/settings_notifier.dart';
import '../settings/settings_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wrongCount = ref.watch(wrongProvider).length +
        ref.watch(vocabWrongProvider).length +
        ref.watch(sentenceWrongProvider).length;
    final stats = ref.watch(statsProvider);
    final mastery = ref.watch(masteryProvider);
    final masteryNotifier = ref.read(masteryProvider.notifier);
    final learned = mastery.values.where((v) => v >= 4).length;

    double catProgress(bool Function(Kana) where) => masteryNotifier
        .progressOf(allKana.where(where).map((k) => k.kana));

    ref.watch(srsProvider);
    final dueCount = ref
        .read(srsProvider.notifier)
        .dueKeys(allVocab.map((w) => w.key))
        .length;
    final dailyGoal = ref.watch(settingsProvider).dailyGoal;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(stats: stats, wrongCount: wrongCount),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        value: stats.total == 0
                            ? '—'
                            : '${(stats.accuracy * 100).toStringAsFixed(0)}%',
                        label: '正確率',
                        color: AppColors.red,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        value: '$learned',
                        label: '已學會',
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        value: '${stats.todayTotal}',
                        label: '今日答題',
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _GoalCard(stats: stats, goal: dailyGoal),
                const SizedBox(height: 22),
                const _SectionTitle('分類進度'),
                const SizedBox(height: 10),
                _CategoryRow(
                  name: '清音',
                  detail: 'あ〜ん・92 字',
                  progress: catProgress((k) => k.category == KanaCategory.seion),
                  color: AppColors.red,
                ),
                const SizedBox(height: 10),
                _CategoryRow(
                  name: '濁音／半濁音',
                  detail: 'が〜ぽ・50 字',
                  progress: catProgress((k) =>
                      k.category == KanaCategory.dakuon ||
                      k.category == KanaCategory.handakuon),
                  color: AppColors.green,
                ),
                const SizedBox(height: 10),
                _CategoryRow(
                  name: '拗音',
                  detail: 'きゃ〜ぴょ・66 字',
                  progress:
                      catProgress((k) => k.category == KanaCategory.youon),
                  color: AppColors.gold,
                ),
                const SizedBox(height: 22),
                const _SectionTitle('假名練習'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.9,
                  children: [
                    for (final mode in PracticeMode.values)
                      _ModeCard(
                        mode: mode,
                        enabled: mode != PracticeMode.wrongReview ||
                            ref.watch(wrongProvider).isNotEmpty,
                        badge: mode == PracticeMode.wrongReview &&
                                ref.watch(wrongProvider).isNotEmpty
                            ? '${ref.watch(wrongProvider).length}'
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                const _SectionTitle('單字練習（N5）'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.9,
                  children: [
                    for (final pool in VocabPool.values)
                      if ((pool != VocabPool.wrongReview ||
                              ref.watch(vocabWrongProvider).isNotEmpty) &&
                          (pool != VocabPool.dueReview || dueCount > 0))
                        _VocabCard(
                          pool: pool,
                          badge: pool == VocabPool.wrongReview
                              ? '${ref.watch(vocabWrongProvider).length}'
                              : pool == VocabPool.dueReview
                                  ? '$dueCount'
                                  : null,
                        ),
                  ],
                ),
                const SizedBox(height: 22),
                const _SectionTitle('情境句子'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.9,
                  children: [
                    for (final pool in ScenePool.values)
                      if (pool != ScenePool.wrongReview ||
                          ref.watch(sentenceWrongProvider).isNotEmpty)
                        _SceneCard(
                          pool: pool,
                          badge: pool == ScenePool.wrongReview
                              ? '${ref.watch(sentenceWrongProvider).length}'
                              : null,
                        ),
                  ],
                ),
                const SizedBox(height: 22),
                const _SectionTitle('文法'),
                const SizedBox(height: 10),
                _GrammarEntryCard(
                  doneCount: ref.watch(grammarProgressProvider).length,
                  total: allGrammar.length,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 文法課入口卡（顯示完成進度）。
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
                      'N5 文法課程',
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

class _SceneCard extends StatelessWidget {
  final ScenePool pool;
  final String? badge;

  const _SceneCard({required this.pool, this.badge});

  static const _icons = {
    ScenePool.all: Icons.forum,
    ScenePool.airport: Icons.flight,
    ScenePool.train: Icons.directions_subway,
    ScenePool.hotel: Icons.hotel,
    ScenePool.restaurant: Icons.restaurant,
    ScenePool.shopping: Icons.storefront,
    ScenePool.wrongReview: Icons.replay,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SentencePracticePage(pool: pool)),
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.indigo, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(_icons[pool], color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pool.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.indigo,
                  ),
                ),
              ),
              if (badge != null)
                Badge(
                  label: Text(badge!),
                  backgroundColor: AppColors.gold,
                  textColor: AppColors.indigo,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 每日目標進度 + 連續達標天數。
class _GoalCard extends StatelessWidget {
  final Stats stats;
  final int goal;

  const _GoalCard({required this.stats, required this.goal});

  @override
  Widget build(BuildContext context) {
    final progress = goal == 0 ? 1.0 : (stats.todayTotal / goal).clamp(0.0, 1.0);
    final done = stats.todayTotal >= goal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: done ? AppColors.green : AppColors.indigo,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Text(done ? '🎉' : '🎯', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done
                      ? '今日目標達成！連續 ${stats.goalStreakDays} 天'
                      : '今日目標 ${stats.todayTotal}/$goal 題',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: done ? AppColors.green : AppColors.indigo,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0x1422254A),
                    color: done ? AppColors.green : AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VocabCard extends StatelessWidget {
  final VocabPool pool;
  final String? badge;

  const _VocabCard({required this.pool, this.badge});

  static const _icons = {
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VocabPracticePage(pool: pool)),
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.indigo, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child:
                    Icon(_icons[pool], color: AppColors.indigo, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pool.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.indigo,
                  ),
                ),
              ),
              if (badge != null)
                Badge(
                  label: Text(badge!),
                  backgroundColor: AppColors.gold,
                  textColor: AppColors.indigo,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 深靛藍頭部：問候、最佳連對、錯題本/設定入口。
class _Header extends StatelessWidget {
  final Stats stats;
  final int wrongCount;

  const _Header({required this.stats, required this.wrongCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.indigo,
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 24),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'おかえり！',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '🔥 最佳連對 ${stats.bestStreak}・今日 ${stats.todayTotal} 題',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '錯題本',
              icon: Badge(
                isLabelVisible: wrongCount > 0,
                label: Text('$wrongCount'),
                backgroundColor: AppColors.gold,
                textColor: AppColors.indigo,
                child: const Icon(Icons.menu_book_outlined,
                    color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WrongListPage()),
              ),
            ),
            IconButton(
              tooltip: '設定',
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: AppColors.indigo,
      ),
    );
  }
}

/// 白底統計卡：8px 圓角、3px 靛藍邊框。
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.indigo, width: 3),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.indigoFaded,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分類進度列：色塊百分比 + 名稱 + 進度條。
class _CategoryRow extends StatelessWidget {
  final String name;
  final String detail;
  final double progress; // 0..1
  final Color color;

  const _CategoryRow({
    required this.name,
    required this.detail,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
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
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$pct',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color == AppColors.gold ? AppColors.indigo : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.indigo,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.indigoFaded,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0x1422254A),
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final PracticeMode mode;
  final bool enabled;
  final String? badge;

  const _ModeCard({required this.mode, this.enabled = true, this.badge});

  static const _icons = {
    PracticeMode.hiragana: Icons.translate,
    PracticeMode.katakana: Icons.text_fields,
    PracticeMode.dakuon: Icons.blur_on,
    PracticeMode.youon: Icons.join_full,
    PracticeMode.mixed: Icons.shuffle,
    PracticeMode.wrongReview: Icons.replay,
  };

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: enabled
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PracticePage(mode: mode),
                    ),
                  )
              : null,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppColors.indigo, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.indigo,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(_icons[mode], color: AppColors.gold, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    mode.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.indigo,
                    ),
                  ),
                ),
                if (badge != null)
                  Badge(
                    label: Text(badge!),
                    backgroundColor: AppColors.gold,
                    textColor: AppColors.indigo,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
