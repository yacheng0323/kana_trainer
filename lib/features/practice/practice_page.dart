import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/kana.dart';
import '../../core/models/practice_mode.dart';
import '../../core/theme/app_theme.dart';
import '../settings/settings_notifier.dart';
import 'practice_controller.dart';
import 'widgets/shake.dart';

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

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          Column(
            children: [
              _Header(mode: widget.mode, state: state),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
                  child: Column(
                    children: [
                      Text(
                        '${_categoryLabel(state.current.category)}・這個假名怎麼念？',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.indigoFaded,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 假名卡片：白底、8px 圓角、4px 狀態邊框、硬陰影
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 32, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: borderColor, width: 4),
                          boxShadow: AppShadows.hard,
                        ),
                        child: Column(
                          children: [
                            Text(
                              state.current.kana,
                              style: const TextStyle(
                                fontSize: 92,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                color: AppColors.indigo,
                              ),
                            ),
                            if (!isChoice && (settings.romajiHint || _hintShown))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  settings.romajiHint
                                      ? state.current.romaji
                                      : '提示：${state.current.romaji[0]}...',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (isChoice)
                        _OptionsGrid(mode: widget.mode, state: state)
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
              offset: answered ? Offset.zero : const Offset(0, 0.4),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: answered ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: answered
                    ? _FeedbackBanner(
                        feedback: feedback,
                        showRetry: !isChoice && !feedback.correct,
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
}

/// 深靛藍頂部：返回、模式、連對火焰、5 段進度。
class _Header extends StatelessWidget {
  final PracticeMode mode;
  final PracticeState state;

  const _Header({required this.mode, required this.state});

  @override
  Widget build(BuildContext context) {
    final filled = state.sessionTotal % 5;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.indigo,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 0, 18, 22),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20),
                ),
                Expanded(
                  child: Text(
                    mode.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '🔥 ${state.streak}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${state.sessionCorrect}/${state.sessionTotal}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  for (var i = 0; i < 5; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i < (filled == 0 && state.sessionTotal > 0
                                  ? 5
                                  : filled)
                              ? AppColors.gold
                              : Colors.white24,
                        ),
                      ),
                    ),
                    if (i < 4) const SizedBox(width: 5),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2×2 四選一按鈕格。
class _OptionsGrid extends ConsumerWidget {
  final PracticeMode mode;
  final PracticeState state;

  const _OptionsGrid({required this.mode, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fb = state.feedback;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        for (var i = 0; i < state.options.length; i++)
          _OptionButton(
            label: state.options[i],
            state: _stateFor(i, fb),
            onTap: fb == null
                ? () => ref.read(practiceProvider(mode).notifier).choose(i)
                : null,
          ),
      ],
    );
  }

  _OptionState _stateFor(int index, AnswerFeedback? fb) {
    if (fb == null) return _OptionState.idle;
    if (index == state.correctIndex) return _OptionState.correct;
    if (index == fb.chosenIndex) return _OptionState.wrong;
    return _OptionState.dimmed;
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _OptionButton extends StatelessWidget {
  final String label;
  final _OptionState state;
  final VoidCallback? onTap;

  const _OptionButton({
    required this.label,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border, icon) = switch (state) {
      _OptionState.idle => (
          Colors.white,
          AppColors.indigo,
          AppColors.indigo,
          null
        ),
      _OptionState.correct => (
          AppColors.green,
          Colors.white,
          AppColors.green,
          '✓'
        ),
      _OptionState.wrong => (AppColors.red, Colors.white, AppColors.red, '✕'),
      _OptionState.dimmed => (
          Colors.white,
          AppColors.indigo,
          AppColors.indigo,
          null
        ),
    };

    return Shake(
      active: state == _OptionState.wrong,
      child: AnimatedOpacity(
        opacity: state == _OptionState.dimmed ? 0.35 : 1,
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: border, width: 3),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                  if (icon != null)
                    Positioned(
                      top: 4,
                      right: 8,
                      child: Text(
                        icon,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: fg,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.indigo,
            ),
            decoration: const InputDecoration(
              hintText: '輸入羅馬拼音',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (showHintButton) ...[
              Container(
                decoration: BoxDecoration(
                  color: AppColors.indigo,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: IconButton(
                  tooltip: '提示',
                  onPressed: onHint,
                  icon: const Icon(Icons.lightbulb_outline,
                      color: AppColors.gold),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: FilledButton(
                onPressed: enabled ? onSubmit : null,
                child: const Padding(
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

/// 底部反饋橫幅：綠答對 / 紅答錯 + 下一題。
class _FeedbackBanner extends StatelessWidget {
  final AnswerFeedback feedback;
  final bool showRetry;
  final VoidCallback onRetry;
  final VoidCallback onNext;

  const _FeedbackBanner({
    required this.feedback,
    required this.showRetry,
    required this.onRetry,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final correct = feedback.correct;
    final others = feedback.accepted.skip(1).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        color: correct ? AppColors.green : AppColors.red,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: const [
          BoxShadow(color: Color(0x4022254A), offset: Offset(6, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  correct ? '答對了！' : '再試一次，你可以的！',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  correct
                      ? '讀音：${feedback.canonical}'
                          '${others.isNotEmpty ? '（也可以 ${others.join('/')}）' : ''}'
                      : '正確答案：${feedback.canonical}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (showRetry) ...[
            _BannerButton(label: '再試一次', onTap: onRetry),
            const SizedBox(width: 8),
          ],
          _BannerButton(label: '下一題', onTap: onNext),
        ],
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BannerButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
