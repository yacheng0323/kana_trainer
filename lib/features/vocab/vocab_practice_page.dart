import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/vocab.dart';
import '../../core/theme/app_theme.dart';
import '../practice/widgets/quiz_widgets.dart';
import '../settings/settings_notifier.dart';
import 'vocab_practice_controller.dart';

/// 單字練習頁（M1：日→中 4 選 1），沿用 2c 設計與假名練習互動。
class VocabPracticePage extends ConsumerStatefulWidget {
  final VocabPool pool;

  const VocabPracticePage({super.key, required this.pool});

  @override
  ConsumerState<VocabPracticePage> createState() => _VocabPracticePageState();
}

class _VocabPracticePageState extends ConsumerState<VocabPracticePage> {
  Timer? _autoNextTimer;

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    super.dispose();
  }

  void _next() {
    _autoNextTimer?.cancel();
    ref.read(vocabPracticeProvider(widget.pool).notifier).nextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vocabPracticeProvider(widget.pool));
    final settings = ref.watch(settingsProvider);

    ref.listen(vocabPracticeProvider(widget.pool), (prev, next) {
      final fb = next.feedback;
      if (fb == null || prev?.feedback != null) return;
      if (settings.sound) {
        fb.correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
      }
      if (fb.correct && settings.autoNext) {
        _autoNextTimer = Timer(const Duration(milliseconds: 900), () {
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
    // 長字自動縮小，避免溢出卡片
    final jpSize = state.current.jp.length <= 3
        ? 64.0
        : state.current.jp.length <= 5
            ? 48.0
            : 36.0;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          Column(
            children: [
              PracticeHeader(
                title: '單字・${widget.pool.label}',
                streak: state.streak,
                sessionCorrect: state.sessionCorrect,
                sessionTotal: state.sessionTotal,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
                  child: Column(
                    children: [
                      Text(
                        '${state.current.topic.label}・這個單字是什麼意思？',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.indigoFaded,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 36, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: borderColor, width: 4),
                          boxShadow: AppShadows.hard,
                        ),
                        child: Column(
                          children: [
                            Text(
                              state.current.jp,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: jpSize,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                                color: AppColors.indigo,
                              ),
                            ),
                            if (state.current.reading != state.current.jp)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  state.current.reading,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'N${state.current.jlpt}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.indigoFaded,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.2,
                        children: [
                          for (var i = 0; i < state.options.length; i++)
                            OptionButton(
                              label: state.options[i],
                              fontSize: 16,
                              state: _optionState(i, state),
                              onTap: feedback == null
                                  ? () => ref
                                      .read(vocabPracticeProvider(widget.pool)
                                          .notifier)
                                      .choose(i)
                                  : null,
                            ),
                        ],
                      ),
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
                        subtitle:
                            '${state.current.jp}（${state.current.reading}）= '
                            '${state.current.zh}',
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

  OptionState _optionState(int index, VocabPracticeState state) {
    final fb = state.feedback;
    if (fb == null) return OptionState.idle;
    if (index == state.correctIndex) return OptionState.correct;
    if (index == fb.chosenIndex) return OptionState.wrong;
    return OptionState.dimmed;
  }
}
