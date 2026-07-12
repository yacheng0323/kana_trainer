import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/services/tts_service.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/practice/widgets/quiz_widgets.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'listening_view_model.dart';

/// 聽力測驗（M5）：自動播放發音 → 4 選 1 選出聽到的單字。
class ListeningPage extends ConsumerStatefulWidget {
  const ListeningPage({super.key});

  @override
  ConsumerState<ListeningPage> createState() => _ListeningPageState();
}

class _ListeningPageState extends ConsumerState<ListeningPage> {
  Timer? _autoNextTimer;

  @override
  void initState() {
    super.initState();
    // 第一題自動播音
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    super.dispose();
  }

  void _speak() {
    final state = ref.read(listeningProvider);
    ref.read(ttsProvider).speak(state.current.jp);
  }

  void _next() {
    _autoNextTimer?.cancel();
    ref.read(listeningProvider.notifier).nextQuestion();
    _speak();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(listeningProvider);
    final settings = ref.watch(settingsProvider);

    ref.listen(listeningProvider, (prev, next) {
      final fb = next.feedback;
      if (fb == null || prev?.feedback != null) return;
      if (settings.sound) {
        fb.correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
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

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          Column(
            children: [
              PracticeHeader(
                title: '聽力測驗',
                streak: state.streak,
                sessionCorrect: state.sessionCorrect,
                sessionTotal: state.sessionTotal,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
                  child: Column(
                    children: [
                      const Text(
                        '聽發音，選出正確的單字',
                        style: TextStyle(
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
                            vertical: 40, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: borderColor, width: 4),
                          boxShadow: AppShadows.hard,
                        ),
                        child: Column(
                          children: [
                            // 大播放按鈕（題目本體）
                            Material(
                              color: AppColors.indigo,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: _speak,
                                borderRadius: BorderRadius.circular(16),
                                child: const SizedBox(
                                  width: 96,
                                  height: 96,
                                  child: Icon(Icons.volume_up,
                                      color: AppColors.gold, size: 48),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '點喇叭重聽',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.indigoFaded,
                              ),
                            ),
                            if (answered)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  '${state.current.jp}（${state.current.reading}）',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.indigo,
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
                              fontSize: 17,
                              state: _optionState(i, state),
                              onTap: feedback == null
                                  ? () => ref
                                      .read(listeningProvider.notifier)
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

  OptionState _optionState(int index, ListeningState state) {
    final fb = state.feedback;
    if (fb == null) return OptionState.idle;
    if (index == state.correctIndex) return OptionState.correct;
    if (index == fb.chosenIndex) return OptionState.wrong;
    return OptionState.dimmed;
  }
}
