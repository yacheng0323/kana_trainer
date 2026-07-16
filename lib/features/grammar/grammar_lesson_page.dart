import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/expansion/expansion_notifier.dart';
import 'package:kana_trainer/features/practice/widgets/quiz_widgets.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'grammar_progress_notifier.dart';

/// 文法課頁：說明卡 + 例句 → 3 題練習 → 全對標記完成。
class GrammarLessonPage extends ConsumerStatefulWidget {
  final GrammarPoint point;

  const GrammarLessonPage({super.key, required this.point});

  @override
  ConsumerState<GrammarLessonPage> createState() => _GrammarLessonPageState();
}

class _GrammarLessonPageState extends ConsumerState<GrammarLessonPage> {
  static const _quizCount = 3;

  bool _quizStarted = false;
  int _quizIndex = 0;
  int _correctCount = 0;
  int? _chosen; // 本題已選選項（顯示順序索引）
  late List<GrammarQuiz> _quizzes; // 靜態 + 動態合併池打亂取 3
  late List<List<int>> _optionOrders; // 每題選項顯示順序（打亂）

  @override
  void initState() {
    super.initState();
    final rng = Random();
    final merged =
        ref.read(contentRepositoryProvider).grammarQuiz(widget.point.id);
    _quizzes = (List.of(merged)..shuffle(rng)).take(_quizCount).toList();
    _optionOrders = [
      for (final q in _quizzes)
        List.generate(q.options.length, (i) => i)..shuffle(rng),
    ];
    // 背景補貨（fire-and-forget）：本課動態題不足時生成
    Future.microtask(() =>
        ref.read(expansionProvider.notifier).maybeExpandGrammar(widget.point));
  }

  @visibleForTesting
  List<GrammarQuiz> get debugQuizzes => _quizzes;

  GrammarQuiz get _quiz => _quizzes[_quizIndex];
  List<int> get _order => _optionOrders[_quizIndex];
  bool get _answered => _chosen != null;
  bool get _lastQuestion => _quizIndex == _quizzes.length - 1;

  void _choose(int displayIndex) {
    if (_answered) return;
    final correct = _order[displayIndex] == _quiz.correctIndex;
    ref.read(statsProvider.notifier).record(correct: correct);
    setState(() {
      _chosen = displayIndex;
      if (correct) _correctCount++;
    });
  }

  void _nextOrFinish() {
    if (!_lastQuestion) {
      setState(() {
        _quizIndex++;
        _chosen = null;
      });
      return;
    }
    // 結束：全對 → 完成
    final allCorrect = _correctCount == _quizzes.length;
    if (allCorrect) {
      ref.read(grammarProgressProvider.notifier).markDone(widget.point.id);
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(allCorrect ? '🎉 全對，本課完成！' : '答對 $_correctCount/3'),
        content: Text(allCorrect ? '下一課已解鎖。' : '全對才能解鎖下一課，再試一次吧！'),
        actions: [
          if (!allCorrect)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _quizStarted = true;
                  _quizIndex = 0;
                  _correctCount = 0;
                  _chosen = null;
                });
              },
              child: Text('重新測驗'),
            ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: Text('回課程列表'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: Text(widget.point.title)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(18),
        child: _quizStarted ? _buildQuiz() : _buildLesson(),
      ),
    );
  }

  Widget _buildLesson() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.indigo, width: 3),
            boxShadow: AppShadows.hardSmall,
          ),
          child: Text(
            widget.point.explanation,
            style: TextStyle(
              fontSize: 15,
              height: 1.7,
              fontWeight: FontWeight.w700,
              color: AppColors.indigo,
            ),
          ),
        ),
        SizedBox(height: 16),
        Text(
          '例句',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.indigo,
          ),
        ),
        SizedBox(height: 8),
        for (final ex in widget.point.examples)
          Container(
            margin: EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppColors.indigo, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.jp,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.indigo,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  ex.zh,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.indigoFaded,
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: 12),
        FilledButton(
          onPressed: () => setState(() => _quizStarted = true),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('開始練習（3 題）', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuiz() {
    final q = _quiz;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '第 ${_quizIndex + 1}/3 題・選出正確的答案',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.indigoFaded,
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.symmetric(vertical: 30, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: !_answered
                  ? AppColors.indigo
                  : _order[_chosen!] == q.correctIndex
                      ? AppColors.green
                      : AppColors.red,
              width: 4,
            ),
            boxShadow: AppShadows.hard,
          ),
          child: Text(
            q.question,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              height: 1.5,
              fontWeight: FontWeight.w900,
              color: AppColors.indigo,
            ),
          ),
        ),
        SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: [
            for (var d = 0; d < _order.length; d++)
              OptionButton(
                label: q.options[_order[d]],
                fontSize: 17,
                state: _optionState(d),
                onTap: _answered ? null : () => _choose(d),
              ),
          ],
        ),
        if (_answered) ...[
          SizedBox(height: 16),
          FilledButton(
            onPressed: _nextOrFinish,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(_lastQuestion ? '看結果' : '下一題',
                  style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ],
    );
  }

  OptionState _optionState(int displayIndex) {
    if (!_answered) return OptionState.idle;
    if (_order[displayIndex] == _quiz.correctIndex) return OptionState.correct;
    if (displayIndex == _chosen) return OptionState.wrong;
    return OptionState.dimmed;
  }
}
