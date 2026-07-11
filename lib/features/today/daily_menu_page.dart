import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../practice/widgets/quiz_widgets.dart';
import '../progress/mastery_notifier.dart';
import '../progress/srs_notifier.dart';
import '../progress/stats_notifier.dart';
import '../progress/wrong_notifier.dart';
import '../settings/settings_notifier.dart';
import 'daily_menu_builder.dart';
import 'menu_done_notifier.dart';

/// 今日菜單練習頁：SRS 複習 + 錯題 + 新內容，一輪打完打卡。
class DailyMenuPage extends ConsumerStatefulWidget {
  const DailyMenuPage({super.key});

  @override
  ConsumerState<DailyMenuPage> createState() => _DailyMenuPageState();
}

class _DailyMenuPageState extends ConsumerState<DailyMenuPage> {
  late final List<MenuQuestion> _questions;
  int _index = 0;
  int _correct = 0;
  int? _chosen;

  @override
  void initState() {
    super.initState();
    _questions = DailyMenuBuilder.build(
      mastery: ref.read(masteryProvider),
      dueVocabKeys: ref
          .read(srsProvider.notifier)
          .dueKeys(ref.read(masteryProvider).keys),
      kanaWrong: ref.read(wrongProvider),
      vocabWrong: ref.read(vocabWrongProvider),
      sentenceWrong: ref.read(sentenceWrongProvider),
    );
  }

  @visibleForTesting
  List<MenuQuestion> get debugQuestions => _questions;

  @visibleForTesting
  void debugChoose(int i) => _choose(i);

  WrongNotifier _wrongBookFor(String kind) => switch (kind) {
        'kana' => ref.read(wrongProvider.notifier),
        'vocab' => ref.read(vocabWrongProvider.notifier),
        _ => ref.read(sentenceWrongProvider.notifier),
      };

  void _choose(int i) {
    if (_chosen != null) return;
    final q = _questions[_index];
    final correct = i == q.correctIndex;

    ref.read(masteryProvider.notifier).record(q.sourceKey, correct: correct);
    ref.read(statsProvider.notifier).record(correct: correct);
    if (q.kind == 'vocab') {
      final after = ref.read(masteryProvider)[q.sourceKey] ?? 0;
      ref.read(srsProvider.notifier).schedule(q.sourceKey, after, correct: correct);
    }
    if (correct) {
      _wrongBookFor(q.kind).resolve(q.sourceKey); // 不在錯題本則 no-op
    } else {
      _wrongBookFor(q.kind).add(q.sourceKey);
    }

    if (ref.read(settingsProvider).sound) {
      correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    }
    setState(() {
      _chosen = i;
      if (correct) _correct++;
    });
  }

  void _next() {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _chosen = null;
      });
      return;
    }
    ref
        .read(menuDoneProvider.notifier)
        .markDone(score: _correct, total: _questions.length);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 今日任務完成！'),
        content: Text('答對 $_correct/${_questions.length}，明天見！'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      // 理論上不會發生（新內容永遠補得滿），保險
      return Scaffold(
        appBar: AppBar(title: const Text('今日任務')),
        body: const Center(child: Text('今天沒有任務，太棒了！')),
      );
    }
    final q = _questions[_index];
    final answered = _chosen != null;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          PracticeHeader(
            title: '今日任務',
            streak: _correct,
            sessionCorrect: _correct,
            sessionTotal: _index + (answered ? 1 : 0),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '第 ${_index + 1}/${_questions.length} 題・${switch (q.kind) {
                      'kana' => '假名讀音',
                      'vocab' => '單字意思',
                      _ => '句子克漏字',
                    }}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.indigoFaded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        vertical: 28, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(
                        color: !answered
                            ? AppColors.indigo
                            : _chosen == q.correctIndex
                                ? AppColors.green
                                : AppColors.red,
                        width: 4,
                      ),
                      boxShadow: AppShadows.hard,
                    ),
                    child: Column(
                      children: [
                        Text(
                          q.prompt,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: q.prompt.length <= 4
                                ? 56
                                : q.prompt.length <= 8
                                    ? 32
                                    : 22,
                            height: 1.4,
                            fontWeight: FontWeight.w900,
                            color: AppColors.indigo,
                          ),
                        ),
                        if (q.subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              q.subtitle!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.4,
                    children: [
                      for (var i = 0; i < q.options.length; i++)
                        OptionButton(
                          label: q.options[i],
                          fontSize: 16,
                          state: _optionState(i, q),
                          onTap: answered ? null : () => _choose(i),
                        ),
                    ],
                  ),
                  if (answered) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(
                          color: _chosen == q.correctIndex
                              ? AppColors.green
                              : AppColors.red,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        q.note,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          fontWeight: FontWeight.w700,
                          color: AppColors.indigo,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _next,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _index < _questions.length - 1 ? '下一題' : '完成任務',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  OptionState _optionState(int i, MenuQuestion q) {
    if (_chosen == null) return OptionState.idle;
    if (i == q.correctIndex) return OptionState.correct;
    if (i == _chosen) return OptionState.wrong;
    return OptionState.dimmed;
  }
}
