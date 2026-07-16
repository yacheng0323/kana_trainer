import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/domain/entities/kana.dart';
import 'package:kana_trainer/domain/entities/practice_mode.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'practice_view_model.dart';
import 'widgets/quiz_widgets.dart';

class PracticePage extends ConsumerStatefulWidget {
  final PracticeMode mode;

  const PracticePage({super.key, required this.mode});

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _autoNextTimer;
  bool _hintShown = false;

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
    setState(() => _hintShown = false);
    ref.read(practiceProvider(widget.mode).notifier).nextQuestion();
  }

  void _retry() {
    _inputController.clear();
    ref.read(practiceProvider(widget.mode).notifier).retry();
    _focusNode.requestFocus();
  }

  static String _categoryLabel(KanaCategory c) => switch (c) {
        KanaCategory.seion => '清音',
        KanaCategory.dakuon => '濁音',
        KanaCategory.handakuon => '半濁音',
        KanaCategory.youon => '拗音',
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(practiceProvider(widget.mode));
    final settings = ref.watch(settingsProvider);
    final isChoice = settings.answerMode == AnswerMode.choice;

    // 作答後音效/震動/自動下一題
    ref.listen(practiceProvider(widget.mode), (prev, next) {
      final fb = next.feedback;
      if (fb == null || prev?.feedback != null) return;
      if (settings.sound) {
        fb.correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
      }
      if (fb.correct && settings.autoNext) {
        _autoNextTimer = Timer(Duration(milliseconds: 900), () {
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
    final others =
        feedback == null ? <String>[] : feedback.accepted.skip(1).toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          Column(
            children: [
              PracticeHeader(
                title: widget.mode.label,
                streak: state.streak,
                sessionCorrect: state.sessionCorrect,
                sessionTotal: state.sessionTotal,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(18, 20, 18, 110),
                  child: Column(
                    children: [
                      Text(
                        '${_categoryLabel(state.current.category)}・這個假名怎麼念？',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.indigoFaded,
                        ),
                      ),
                      SizedBox(height: 12),
                      // 假名卡片：白底、8px 圓角、4px 狀態邊框、硬陰影
                      AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                            vertical: 32, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: borderColor, width: 4),
                          boxShadow: AppShadows.hard,
                        ),
                        child: Column(
                          children: [
                            Text(
                              state.current.kana,
                              style: TextStyle(
                                fontSize: 92,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                color: AppColors.indigo,
                              ),
                            ),
                            if (!isChoice && (settings.romajiHint || _hintShown))
                              Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  settings.romajiHint
                                      ? state.current.romaji
                                      : '提示：${state.current.romaji[0]}...',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                            SizedBox(height: 14),
                            SpeakButton(text: state.current.kana),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      if (isChoice)
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.2,
                          children: [
                            for (var i = 0; i < state.options.length; i++)
                              OptionButton(
                                label: state.options[i],
                                state: _optionState(i, state),
                                onTap: feedback == null
                                    ? () => ref
                                        .read(practiceProvider(widget.mode)
                                            .notifier)
                                        .choose(i)
                                    : null,
                              ),
                          ],
                        )
                      else
                        _InputArea(
                          controller: _inputController,
                          focusNode: _focusNode,
                          enabled: !answered,
                          showHintButton:
                              settings.showHint && !settings.romajiHint,
                          onHint: () => setState(() => _hintShown = true),
                          onSubmit: () => ref
                              .read(practiceProvider(widget.mode).notifier)
                              .submit(_inputController.text),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 底部反饋橫幅
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: AnimatedSlide(
              offset: answered ? Offset.zero : Offset(0, 0.4),
              duration: Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: answered ? 1 : 0,
                duration: Duration(milliseconds: 250),
                child: answered
                    ? FeedbackBanner(
                        correct: feedback.correct,
                        subtitle: feedback.correct
                            ? '讀音：${feedback.canonical}'
                                '${others.isNotEmpty ? '（也可以 ${others.join('/')}）' : ''}'
                            : '正確答案：${feedback.canonical}',
                        showRetry: !isChoice && !feedback.correct,
                        onRetry: _retry,
                        onNext: _next,
                      )
                    : SizedBox(height: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  OptionState _optionState(int index, PracticeState state) {
    final fb = state.feedback;
    if (fb == null) return OptionState.idle;
    if (index == state.correctIndex) return OptionState.correct;
    if (index == fb.chosenIndex) return OptionState.wrong;
    return OptionState.dimmed;
  }
}

/// 鍵盤輸入模式的輸入區。
class _InputArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool showHintButton;
  final VoidCallback onHint;
  final VoidCallback onSubmit;

  const _InputArea({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.showHintButton,
    required this.onHint,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.indigo, width: 3),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            autofocus: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.indigo,
            ),
            decoration: InputDecoration(
              hintText: '輸入羅馬拼音',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        SizedBox(height: 14),
        Row(
          children: [
            if (showHintButton) ...[
              Container(
                decoration: BoxDecoration(
                  color: AppColors.indigoSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: IconButton(
                  tooltip: '提示',
                  onPressed: onHint,
                  icon: Icon(Icons.lightbulb_outline,
                      color: AppColors.gold),
                ),
              ),
              SizedBox(width: 10),
            ],
            Expanded(
              child: FilledButton(
                onPressed: enabled ? onSubmit : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('確認', style: TextStyle(fontSize: 17)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
