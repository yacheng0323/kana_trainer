import 'package:flutter/material.dart';

import '../practice_controller.dart';

/// 作答結果回饋：答對綠、答錯紅 + 正確答案與可接受拼音。
class ResultFeedback extends StatelessWidget {
  final AnswerFeedback feedback;

  const ResultFeedback({super.key, required this.feedback});

  @override
  Widget build(BuildContext context) {
    final correct = feedback.correct;
    final color = correct ? Colors.green : Colors.red;
    final others = feedback.accepted.skip(1).toList();

    return Container(
      key: ValueKey(correct),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(correct ? Icons.check_circle : Icons.cancel, color: color),
              const SizedBox(width: 8),
              Text(
                correct ? '答對了！' : '答錯了',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            correct ? '讀音：${feedback.canonical}' : '正確答案：${feedback.canonical}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (others.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '也可以：${others.join(' / ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
