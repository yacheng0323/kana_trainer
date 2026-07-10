import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/sentence.dart';
import '../../core/theme/app_theme.dart';
import '../practice/widgets/quiz_widgets.dart';
import '../settings/settings_notifier.dart';
import 'sentence_practice_controller.dart';

/// 句子練習頁：克漏字 4 選 1 / 語塊重組（M3），沿用 2c 設計。
class SentencePracticePage extends ConsumerStatefulWidget {
  final ScenePool pool;

  const SentencePracticePage({super.key, required this.pool});

  @override
  ConsumerState<SentencePracticePage> createState() =>
      _SentencePracticePageState();
}

class _SentencePracticePageState extends ConsumerState<SentencePracticePage> {
  Timer? _autoNextTimer;

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    super.dispose();
  }

  void _next() {
    _autoNextTimer?.cancel();
    ref.read(sentencePracticeProvider(widget.pool).notifier).nextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sentencePracticeProvider(widget.pool));
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(sentencePracticeProvider(widget.pool).notifier);

    ref.listen(sentencePracticeProvider(widget.pool), (prev, next) {
      final fb = next.feedback;
      if (fb == null || prev?.feedback != null) return;
      if (settings.sound) {
        fb.correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
      }
      if (fb.correct && settings.autoNext) {
        _autoNextTimer = Timer(const Duration(milliseconds: 1100), () {
          if (mounted) _next();
        });
      }
    });

    final feedback = state.feedback;
    final answered = feedback != null;
    final borderColor = !answered
        ? AppColors.indigo
        : feedback.correct
            ? AppColors.green
            : AppColors.red;
    final isCloze = state.type == SentenceQuizType.cloze;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          Column(
            children: [
              PracticeHeader(
                title: '句子・${widget.pool.label}',
                streak: state.streak,
                sessionCorrect: state.sessionCorrect,
                sessionTotal: state.sessionTotal,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
                  child: Column(
                    children: [
                      Text(
                        '${state.current.scene.label}・${isCloze ? '選出空格的詞' : '把語塊排成正確的句子'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.indigoFaded,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 題目卡
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 28, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: borderColor, width: 4),
                          boxShadow: AppShadows.hard,
                        ),
                        child: Column(
                          children: [
                            if (isCloze)
                              Text(
                                state.current.clozeText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  height: 1.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.indigo,
                                ),
                              )
                            else
                              _ReorderSlots(state: state, notifier: notifier),
                            const SizedBox(height: 10),
                            Text(
                              state.current.zh,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.indigoFaded,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (isCloze)
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.6,
                          children: [
                            for (var i = 0; i < state.options.length; i++)
                              OptionButton(
                                label: state.options[i],
                                fontSize: 16,
                                state: _optionState(i, state),
                                onTap: feedback == null
                                    ? () => notifier.choose(i)
                                    : null,
                              ),
                          ],
                        )
                      else
                        _ChunkPool(state: state, notifier: notifier),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: AnimatedSlide(
              offset: answered ? Offset.zero : const Offset(0, 0.4),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: answered ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: answered
                    ? FeedbackBanner(
                        correct: feedback.correct,
                        subtitle: '${state.current.jp}｜${state.current.zh}',
                        showRetry: !feedback.correct && !isCloze,
                        onRetry: notifier.retryReorder,
                        onNext: _next,
                      )
                    : const SizedBox(height: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  OptionState _optionState(int index, SentencePracticeState state) {
    final fb = state.feedback;
    if (fb == null) return OptionState.idle;
    if (index == state.correctIndex) return OptionState.correct;
    if (index == fb.chosenIndex) return OptionState.wrong;
    return OptionState.dimmed;
  }
}

/// 重組：已排入的語塊列（點擊移除）。
class _ReorderSlots extends StatelessWidget {
  final SentencePracticeState state;
  final SentencePracticeController notifier;

  const _ReorderSlots({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        if (state.picked.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '點下方語塊組句…',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.indigoFaded,
              ),
            ),
          ),
        for (var p = 0; p < state.picked.length; p++)
          Material(
            color: AppColors.indigo,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: state.feedback == null
                  ? () => notifier.unpickChunk(p)
                  : null,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  state.shuffled[state.picked[p]],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 重組：可選語塊池（已選的變淡不可點）。
class _ChunkPool extends StatelessWidget {
  final SentencePracticeState state;
  final SentencePracticeController notifier;

  const _ChunkPool({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < state.shuffled.length; i++)
          Opacity(
            opacity: state.picked.contains(i) ? 0.3 : 1,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: InkWell(
                onTap: state.feedback == null && !state.picked.contains(i)
                    ? () => notifier.pickChunk(i)
                    : null,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: AppColors.indigo, width: 3),
                  ),
                  child: Text(
                    state.shuffled[i],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.indigo,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
