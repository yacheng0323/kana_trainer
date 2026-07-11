import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/verb.dart';
import '../../core/theme/app_theme.dart';
import '../practice/widgets/quiz_widgets.dart';
import '../progress/mastery_notifier.dart';
import '../progress/stats_notifier.dart';
import '../settings/settings_notifier.dart';
import 'verb_quiz_builder.dart';

/// 動詞變化訓練器（N5 大魔王）：辭書形 → ます/て/ない/た形，10 題一輪。
class VerbDrillPage extends ConsumerStatefulWidget {
  const VerbDrillPage({super.key});

  @override
  ConsumerState<VerbDrillPage> createState() => _VerbDrillPageState();
}

class _VerbDrillPageState extends ConsumerState<VerbDrillPage> {
  VerbForm? _form; // null = 混合
  List<VerbQuestion>? _questions;
  int _index = 0;
  int _correct = 0;
  int? _chosen;

  void _start() {
    setState(() {
      _questions = VerbQuizBuilder.build(form: _form);
      _index = 0;
      _correct = 0;
      _chosen = null;
    });
  }

  void _choose(int i) {
    if (_chosen != null) return;
    final q = _questions![_index];
    final correct = i == q.correctIndex;
    ref.read(masteryProvider.notifier).record(q.verb.key, correct: correct);
    ref.read(statsProvider.notifier).record(correct: correct);
    if (ref.read(settingsProvider).sound) {
      correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    }
    setState(() {
      _chosen = i;
      if (correct) _correct++;
    });
  }

  void _next() {
    if (_index < _questions!.length - 1) {
      setState(() {
        _index++;
        _chosen = null;
      });
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('完成！答對 $_correct/${_questions!.length}'),
        content: Text(_correct == _questions!.length ? '變化全對，太強了！🎉' : '多練幾輪就熟了！'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _questions = null);
            },
            child: const Text('換題型'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _start();
            },
            child: const Text('再一輪'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('動詞變化訓練')),
      body: _questions == null ? _buildPicker() : _buildQuiz(),
    );
  }

  Widget _buildPicker() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.indigo, width: 3),
            boxShadow: AppShadows.hardSmall,
          ),
          child: const Column(
            children: [
              Text('💪', style: TextStyle(fontSize: 36)),
              SizedBox(height: 8),
              Text(
                'N5 動詞變化 41 個',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.indigo,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '五段・一段・不規則，每輪 10 題\n選出辭書形對應的正確變化',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.indigoFaded,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '選擇題型',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.indigo,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('混合'),
              selected: _form == null,
              selectedColor: AppColors.gold,
              onSelected: (_) => setState(() => _form = null),
            ),
            for (final f in VerbForm.values)
              ChoiceChip(
                label: Text(f.label),
                selected: _form == f,
                selectedColor: AppColors.gold,
                onSelected: (_) => setState(() => _form = f),
              ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _start,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('開始訓練', style: TextStyle(fontSize: 17)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuiz() {
    final q = _questions![_index];
    final answered = _chosen != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '第 ${_index + 1}/${_questions!.length} 題・答對 $_correct',
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
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
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
                  q.verb.dict,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: AppColors.indigo,
                  ),
                ),
                Text(
                  '${q.verb.reading}・${q.verb.zh}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.indigo,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${q.form.label}？',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
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
                  fontSize: 17,
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
                '${q.verb.group.label}｜'
                'ます形 ${q.verb.masu}・て形 ${q.verb.te}・'
                'ない形 ${q.verb.nai}・た形 ${q.verb.ta}',
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
                  _index < _questions!.length - 1 ? '下一題' : '看結果',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  OptionState _optionState(int i, VerbQuestion q) {
    if (_chosen == null) return OptionState.idle;
    if (i == q.correctIndex) return OptionState.correct;
    if (i == _chosen) return OptionState.wrong;
    return OptionState.dimmed;
  }
}
