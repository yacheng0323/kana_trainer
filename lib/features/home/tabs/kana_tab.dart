import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/static/kana_data.dart';
import 'package:kana_trainer/domain/entities/kana.dart';
import 'package:kana_trainer/domain/entities/practice_mode.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/practice/practice_page.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:kana_trainer/features/home/widgets/home_cards.dart';

/// Tab 1：50音基礎 — 分類進度 + 六種假名練習。
class KanaTab extends ConsumerWidget {
  const KanaTab({super.key});

  static const _icons = {
    PracticeMode.hiragana: Icons.translate,
    PracticeMode.katakana: Icons.text_fields,
    PracticeMode.dakuon: Icons.blur_on,
    PracticeMode.youon: Icons.join_full,
    PracticeMode.mixed: Icons.shuffle,
    PracticeMode.wrongReview: Icons.replay,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wrong = ref.watch(wrongProvider);
    ref.watch(masteryProvider);
    final masteryNotifier = ref.read(masteryProvider.notifier);

    double catProgress(bool Function(Kana) where) => masteryNotifier
        .progressOf(allKana.where(where).map((k) => k.kana));

    final overall = masteryNotifier.progressOf(allKana.map((k) => k.kana));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        TabHeader(
          title: '50音基礎',
          subtitle: '總熟練度 ${(overall * 100).toStringAsFixed(1)}%',
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('分類進度'),
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
                progress: catProgress((k) => k.category == KanaCategory.youon),
                color: AppColors.gold,
              ),
              const SizedBox(height: 22),
              const SectionTitle('練習模式'),
              const SizedBox(height: 10),
              EntryGrid(
                children: [
                  for (final mode in PracticeMode.values)
                    EntryCard(
                      icon: _icons[mode]!,
                      iconBg: AppColors.indigo,
                      iconColor: AppColors.gold,
                      label: mode.label,
                      enabled: mode != PracticeMode.wrongReview ||
                          wrong.isNotEmpty,
                      badge: mode == PracticeMode.wrongReview &&
                              wrong.isNotEmpty
                          ? '${wrong.length}'
                          : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PracticePage(mode: mode),
                        ),
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

/// 分類進度列：色塊百分比 + 名稱 + 進度條。
class _CategoryRow extends StatelessWidget {
  final String name;
  final String detail;
  final double progress;
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
                color:
                    color == AppColors.gold ? AppColors.indigo : Colors.white,
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
