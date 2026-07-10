import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'exam_controller.dart';

/// N5 模擬測驗頁：20 題 / 10 分鐘 / 交卷評分 + 錯題檢討。
class ExamPage extends ConsumerStatefulWidget {
  const ExamPage({super.key});

  @override
  ConsumerState<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends ConsumerState<ExamPage> {
  Timer? _timer;
  int _remaining = ExamController.examSeconds;
  bool _started = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => _started = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer?.cancel();
        ref.read(examProvider.notifier).submit();
      }
    });
  }

  String get _clock {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(examProvider);

    if (!_started) return _buildIntro();
    if (state.submitted) {
      _timer?.cancel();
      return _buildResult(state);
    }
    return _buildQuiz(state);
  }

  Widget _buildIntro() {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('N5 模擬測驗')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppColors.indigo, width: 3),
                  boxShadow: AppShadows.hard,
                ),
                child: const Column(
                  children: [
                    Text('📝', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 12),
                    Text(
                      '20 題・限時 10 分鐘',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.indigo,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '單字 10 題＋假名 5 題＋文法 5 題\n作答中不顯示對錯，交卷後評分與檢討。\n時間到自動交卷。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.7,
                        fontWeight: FontWeight.w700,
                        color: AppColors.indigoFaded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _start,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('開始測驗', style: TextStyle(fontSize: 17)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuiz(ExamState state) {
    final q = state.questions[state.index];
    final chosen = state.answers[state.index];
    final notifier = ref.read(examProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text('第 ${state.index + 1}/${state.questions.length} 題'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '⏱ $_clock',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _remaining <= 60 ? AppColors.red : AppColors.gold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 答題進度點
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (var i = 0; i < state.questions.length; i++)
                  GestureDetector(
                    onTap: () => notifier.goTo(i),
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == state.index
                            ? AppColors.gold
                            : state.answers[i] != null
                                ? AppColors.indigo
                                : const Color(0x3322254A),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              q.sub ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.indigoFaded,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: AppColors.indigo, width: 4),
                boxShadow: AppShadows.hard,
              ),
              child: Text(
                q.prompt,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: q.prompt.length <= 4 ? 44 : 22,
                  height: 1.4,
                  fontWeight: FontWeight.w900,
                  color: AppColors.indigo,
                ),
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
                  _SelectableOption(
                    label: q.options[i],
                    selected: chosen == i,
                    onTap: () => notifier.select(i),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (state.index > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: notifier.previous,
                      child: const Text('上一題'),
                    ),
                  ),
                if (state.index > 0) const SizedBox(width: 10),
                Expanded(
                  child: state.index < state.questions.length - 1
                      ? FilledButton(
                          onPressed: notifier.next,
                          child: const Text('下一題'),
                        )
                      : FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _confirmSubmit(state),
                          child: const Text('交卷'),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSubmit(ExamState state) async {
    final unanswered = state.questions.length - state.answeredCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確定交卷？'),
        content: Text(unanswered > 0 ? '還有 $unanswered 題未作答。' : '已全部作答。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('繼續作答'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('交卷'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(examProvider.notifier).submit();
  }

  Widget _buildResult(ExamState state) {
    final wrongIndices = [
      for (var i = 0; i < state.questions.length; i++)
        if (state.answers[i] != state.questions[i].correctIndex) i,
    ];
    final percent = (state.score / state.questions.length * 100).round();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('測驗結果')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: percent >= 70 ? AppColors.green : AppColors.red,
                width: 4,
              ),
              boxShadow: AppShadows.hard,
            ),
            child: Column(
              children: [
                Text(percent >= 70 ? '🎉 合格！' : '💪 再接再厲',
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  '${state.score}/${state.questions.length}',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppColors.indigo,
                  ),
                ),
                Text(
                  '正確率 $percent%・用時 ${state.durationSec ~/ 60} 分 ${state.durationSec % 60} 秒',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.indigoFaded,
                  ),
                ),
              ],
            ),
          ),
          if (wrongIndices.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              '錯題檢討',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.indigo,
              ),
            ),
            const SizedBox(height: 10),
            for (final i in wrongIndices)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppColors.red, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.questions[i].prompt,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.indigo,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '你的答案：${state.answers[i] == null ? '未作答' : state.questions[i].options[state.answers[i]!]}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.red,
                      ),
                    ),
                    Text(
                      '正解：${state.questions[i].answerNote}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('完成'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 測驗中的選項（僅標記選取，不顯示對錯）。
class _SelectableOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.indigo : Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.indigo, width: 3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.gold : AppColors.indigo,
            ),
          ),
        ),
      ),
    );
  }
}
