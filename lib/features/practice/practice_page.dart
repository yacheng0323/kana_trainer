import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/practice_mode.dart';
import '../settings/settings_notifier.dart';
import 'practice_controller.dart';
import 'widgets/result_feedback.dart';

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

  void _submit() {
    ref.read(practiceProvider(widget.mode).notifier).submit(_inputController.text);
  }

  void _next() {
    _autoNextTimer?.cancel();
    _inputController.clear();
    setState(() => _hintShown = false);
    ref.read(practiceProvider(widget.mode).notifier).nextQuestion();
    _focusNode.requestFocus();
  }

  void _retry() {
    _inputController.clear();
    ref.read(practiceProvider(widget.mode).notifier).retry();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(practiceProvider(widget.mode));
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;

    // 作答後音效/自動下一題
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode.label),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '連對 ${state.streak}　正確率 ${(state.accuracy * 100).toStringAsFixed(0)}%'
                '（${state.sessionCorrect}/${state.sessionTotal}）',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // 題目假名
              Text(
                state.current.kana,
                style: TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
              if (settings.romajiHint || _hintShown)
                Text(
                  settings.romajiHint
                      ? state.current.romaji
                      : '提示：${state.current.romaji[0]}...',
                  style: TextStyle(
                    fontSize: 20,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              const SizedBox(height: 24),
              TextField(
                controller: _inputController,
                focusNode: _focusNode,
                enabled: !answered,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24),
                decoration: const InputDecoration(
                  hintText: '輸入羅馬拼音',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              if (!answered)
                Row(
                  children: [
                    if (settings.showHint && !settings.romajiHint)
                      IconButton(
                        tooltip: '提示',
                        onPressed: () => setState(() => _hintShown = true),
                        icon: const Icon(Icons.lightbulb_outline),
                      ),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('確認', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                ResultFeedback(feedback: feedback),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (!feedback.correct) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _retry,
                          child: const Text('再試一次'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: _next,
                        child: const Text('下一題'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
