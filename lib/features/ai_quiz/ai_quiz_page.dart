import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/ai/ai_quiz_service.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/practice/widgets/quiz_widgets.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/settings/settings_page.dart';

const aiQuizTopics = ['旅遊', '交通', '餐飲', '購物', '時間', '日常', '職場', '綜合'];

/// AI 出題（Claude 動態生成 N5 題目）。
/// 有網路 + API Key → 全新題目；已出過的主題快取在本機可離線重玩。
class AiQuizPage extends ConsumerStatefulWidget {
  const AiQuizPage({super.key});

  @override
  ConsumerState<AiQuizPage> createState() => _AiQuizPageState();
}

enum _Phase { pickTopic, loading, quiz }

class _AiQuizPageState extends ConsumerState<AiQuizPage> {
  _Phase _phase = _Phase.pickTopic;
  String _topic = aiQuizTopics.first;
  List<AiQuestion> _questions = [];
  int _index = 0;
  int _correct = 0;
  int? _chosen;
  String? _error;
  bool _fromCache = false;

  String get _cacheKey => 'ai_cache_$_topic';

  Future<void> _generate({bool forceRefresh = false}) async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });

    final prefs = ref.read(keyValueStoreProvider);

    // 先看快取（除非要求重新出題）
    if (!forceRefresh) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        try {
          final questions = (jsonDecode(cached) as List)
              .map((q) => AiQuestion.fromJson(q as Map<String, dynamic>))
              .toList();
          _startQuiz(questions, fromCache: true);
          return;
        } catch (_) {
          // 快取壞掉就重抓
        }
      }
    }

    try {
      final questions = await ref.read(aiQuizServiceProvider).generate(
            apiKey: ref.read(apiKeyProvider),
            topic: _topic,
          );
      await prefs.setString(
        _cacheKey,
        jsonEncode(questions.map((q) => q.toJson()).toList()),
      );
      _startQuiz(questions, fromCache: false);
    } on AiQuizException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.pickTopic;
        _error = e.message;
      });
    }
  }

  void _startQuiz(List<AiQuestion> questions, {required bool fromCache}) {
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _index = 0;
      _correct = 0;
      _chosen = null;
      _fromCache = fromCache;
      _phase = _Phase.quiz;
    });
  }

  void _choose(int i) {
    if (_chosen != null) return;
    final correct = i == _questions[_index].correctIndex;
    ref.read(statsProvider.notifier).record(correct: correct);
    HapticFeedback.lightImpact();
    setState(() {
      _chosen = i;
      if (correct) _correct++;
    });
  }

  void _next() {
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _chosen = null;
      });
      return;
    }
    // 結束
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('完成！答對 $_correct/${_questions.length}'),
        content: Text(_correct == _questions.length ? '全對，太強了！🎉' : '再挑戰一次或換個主題吧！'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _phase = _Phase.pickTopic);
            },
            child: const Text('換主題'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startQuiz(_questions, fromCache: _fromCache);
            },
            child: const Text('再玩一次'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('AI 出題')),
      body: switch (_phase) {
        _Phase.pickTopic => _buildPicker(),
        _Phase.loading => _buildLoading(),
        _Phase.quiz => _buildQuiz(),
      },
    );
  }

  Widget _buildPicker() {
    final hasKey = ref.watch(apiKeyProvider).isNotEmpty;
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
          child: Column(
            children: [
              const Text('✨', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              const Text(
                'AI 每次出全新 N5 題目',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.indigo,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasKey
                    ? '單字意思・克漏字・讀音混合出題，出過的主題可離線重玩'
                    : '需要 Claude API Key 才能出題（僅存在本機，不會被備份匯出）',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.indigoFaded,
                ),
              ),
              if (!hasKey) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.key, size: 18),
                  label: const Text('前往設定 API Key'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: AppColors.red, width: 2),
            ),
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.red,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          '選擇主題',
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
            for (final t in aiQuizTopics)
              ChoiceChip(
                label: Text(t),
                selected: _topic == t,
                selectedColor: AppColors.gold,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _topic == t ? AppColors.indigo : AppColors.indigoFaded,
                ),
                onSelected: (_) => setState(() => _topic = t),
              ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: hasKey ? () => _generate() : null,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('開始出題', style: TextStyle(fontSize: 17)),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('忽略快取，重新出全新題目'),
          onPressed: hasKey ? () => _generate(forceRefresh: true) : null,
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.indigo),
          SizedBox(height: 16),
          Text(
            'AI 出題中…（約 10–30 秒）',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.indigoFaded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuiz() {
    final q = _questions[_index];
    final answered = _chosen != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$_topic・第 ${_index + 1}/${_questions.length} 題'
            '${_fromCache ? '（快取題組）' : ''}・答對 $_correct',
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
            child: Text(
              q.question,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: q.question.length <= 8 ? 32 : 20,
                height: 1.5,
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
                OptionButton(
                  label: q.options[i],
                  fontSize: 15,
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
                q.note,
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
                  _index < _questions.length - 1 ? '下一題' : '看結果',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  OptionState _optionState(int i, AiQuestion q) {
    if (_chosen == null) return OptionState.idle;
    if (i == q.correctIndex) return OptionState.correct;
    if (i == _chosen) return OptionState.wrong;
    return OptionState.dimmed;
  }
}
