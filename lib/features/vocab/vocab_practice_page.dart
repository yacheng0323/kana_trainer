import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/practice/widgets/quiz_widgets.dart';
import 'package:kana_trainer/features/expansion/expansion_notifier.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'vocab_view_model.dart';

/// 單字練習頁：日→中 / 中→日 4 選 1、讀音輸入（M2），沿用 2c 設計。
class VocabPracticePage extends ConsumerStatefulWidget {
  final VocabPool pool;

  const VocabPracticePage({super.key, required this.pool});

  @override
  ConsumerState<VocabPracticePage> createState() => _VocabPracticePageState();
}

class _VocabPracticePageState extends ConsumerState<VocabPracticePage> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _autoNextTimer;

  @override
  void initState() {
    super.initState();
    // 背景補貨（fire-and-forget）：本輪照用現有池，下輪吃到新題
    final topic = widget.pool.topic;
    if (topic != null) {
      Future.microtask(
          () => ref.read(expansionProvider.notifier).maybeExpandVocab(topic));
    }
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _next() {
    _autoNextTimer?.cancel();
    _inputController.clear();
    ref.read(vocabPracticeProvider(widget.pool).notifier).nextQuestion();
  }

  void _retry() {
    _inputController.clear();
    ref.read(vocabPracticeProvider(widget.pool).notifier).retry();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vocabPracticeProvider(widget.pool));
    final settings = ref.watch(settingsProvider);
    final mode = state.mode;

    ref.listen(expansionProvider, (prev, next) {
      if (next.status == ExpansionStatus.done &&
          next.lastAdded > 0 &&
          prev?.status == ExpansionStatus.generating) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('題庫 +${next.lastAdded} 題')),
        );
      }
    });

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

    // 題目卡主文字與提示。
    // 日→中：漢字對中文使用者等於直接洩題（如「出口」），
    // 答題前一律用假名出題，作答後（對錯都）才揭曉漢字。
    final hideKanji = mode == VocabMode.jpZh &&
        !answered &&
        state.current.jp != state.current.reading;
    final prompt = mode == VocabMode.zhJp
        ? state.current.zh
        : hideKanji
            ? state.current.reading
            : state.current.jp;
    final promptSize = prompt.length <= 3
        ? 64.0
        : prompt.length <= 5
            ? 48.0
            : 34.0;
    final showReading = mode == VocabMode.jpZh &&
        !hideKanji &&
        state.current.reading != state.current.jp;

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
                        '${state.current.topic.label}・${switch (mode) {
                          VocabMode.jpZh => '這個單字是什麼意思？',
                          VocabMode.zhJp => '日文怎麼說？',
                          VocabMode.reading => '這個單字怎麼念？',
                        }}',
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
                              prompt,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: promptSize,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                                color: AppColors.indigo,
                              ),
                            ),
                            if (showReading)
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
                                'N${state.current.jlpt}・${mode.label}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.indigoFaded,
                                ),
                              ),
                            ),
                            // 讀音輸入模式聽發音等於作弊，答題後才顯示
                            if (mode != VocabMode.reading || answered) ...[
                              const SizedBox(height: 12),
                              SpeakButton(text: state.current.jp),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (mode == VocabMode.reading)
                        _ReadingInput(
                          controller: _inputController,
                          focusNode: _focusNode,
                          enabled: !answered,
                          onSubmit: () => ref
                              .read(vocabPracticeProvider(widget.pool).notifier)
                              .submitReading(_inputController.text),
                        )
                      else
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
                        showRetry:
                            mode == VocabMode.reading && !feedback.correct,
                        onRetry: _retry,
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

/// 讀音輸入區（接受假名或羅馬拼音）。
class _ReadingInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSubmit;

  const _ReadingInput({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.indigo, width: 3),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.indigo,
            ),
            decoration: const InputDecoration(
              hintText: '輸入讀音（假名或羅馬拼音）',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: enabled ? onSubmit : null,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('確認', style: TextStyle(fontSize: 17)),
            ),
          ),
        ),
      ],
    );
  }
}
