import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/ai/ai_analysis_service.dart';
import 'package:kana_trainer/data/ai/ai_quiz_service.dart';
import 'package:kana_trainer/data/ai/claude_client.dart';
import 'package:kana_trainer/data/static/kana_data.dart';
import 'package:kana_trainer/data/static/sentence_data.dart';
import 'package:kana_trainer/data/static/vocab_data.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:kana_trainer/features/settings/settings_page.dart';

/// AI 弱點分析：把錯題本＋統計整理給 Claude，產出弱點模式與練習建議。
/// 結果快取（ai_analysis），可離線回看，隨時重新分析。
class AiAnalysisPage extends ConsumerStatefulWidget {
  const AiAnalysisPage({super.key});

  @override
  ConsumerState<AiAnalysisPage> createState() => _AiAnalysisPageState();
}

class _AiAnalysisPageState extends ConsumerState<AiAnalysisPage> {
  static const _cacheKey = 'ai_analysis';

  WeaknessReport? _report;
  String? _reportDate;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  void _loadCache() {
    final raw = ref.read(keyValueStoreProvider).getString(_cacheKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _report = WeaknessReport.fromJson(json['report'] as Map<String, dynamic>);
      _reportDate = json['date'] as String?;
    } catch (_) {}
  }

  /// 組學習狀況摘要文字（丟給 AI 的原料）。
  String _buildLearnerData() {
    final stats = ref.read(statsProvider);
    final mastery = ref.read(masteryProvider);
    final kanaWrong = ref.read(wrongProvider);
    final vocabWrong = ref.read(vocabWrongProvider);
    final sentenceWrong = ref.read(sentenceWrongProvider);

    String top(Map<String, int> wrong, String Function(String) label) {
      final entries = wrong.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return entries
          .take(10)
          .map((e) => '${label(e.key)}（錯${e.value}次）')
          .join('、');
    }

    final learned = mastery.values.where((v) => v >= 4).length;
    return '總答題 ${stats.total}，總正確率 ${(stats.accuracy * 100).toStringAsFixed(0)}%，'
        '已學會（熟練度≥4）$learned 項。\n'
        '假名錯題：${kanaWrong.isEmpty ? '無' : top(kanaWrong, (k) => '$k(${findKana(k)?.romaji ?? '?'})')}\n'
        '單字錯題：${vocabWrong.isEmpty ? '無' : top(vocabWrong, (k) => findVocab(k)?.jp ?? k)}\n'
        '句子錯題：${sentenceWrong.isEmpty ? '無' : top(sentenceWrong, (k) => findSentence(k)?.jp ?? k)}';
  }

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await ref.read(aiAnalysisServiceProvider).analyze(
            apiKey: ref.read(apiKeyProvider),
            learnerData: _buildLearnerData(),
          );
      final date = StatsNotifier.today();
      await ref.read(keyValueStoreProvider).setString(
            _cacheKey,
            jsonEncode({'date': date, 'report': report.toJson()}),
          );
      if (!mounted) return;
      setState(() {
        _report = report;
        _reportDate = date;
        _loading = false;
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = ref.watch(apiKeyProvider).isNotEmpty;
    final hasData = ref.watch(statsProvider).total >= 20;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: Text('AI 弱點分析')),
      body: ListView(
        padding: EdgeInsets.all(18),
        children: [
          if (_loading)
            Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.indigo),
                    SizedBox(height: 14),
                    Text(
                      '分析中…（約 10–20 秒）',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.indigoFaded,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            if (_error != null) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppColors.red, width: 2),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.red,
                  ),
                ),
              ),
              SizedBox(height: 12),
            ],
            if (_report == null)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppColors.indigo, width: 3),
                  boxShadow: AppShadows.hardSmall,
                ),
                child: Column(
                  children: [
                    Text('🔍', style: TextStyle(fontSize: 36)),
                    SizedBox(height: 8),
                    Text(
                      '讓 AI 找出你的弱點',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.indigo,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      !hasKey
                          ? '需要 Claude API Key（設定頁貼上）'
                          : !hasData
                              ? '先累積至少 20 題作答紀錄再來分析'
                              : '分析錯題本與熟練度，找出弱點模式並給練習建議',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.indigoFaded,
                      ),
                    ),
                    if (!hasKey) ...[
                      SizedBox(height: 12),
                      FilledButton.icon(
                        icon: Icon(Icons.key, size: 18),
                        label: Text('前往設定 API Key'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => SettingsPage()),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else ...[
              Text(
                '分析日期：$_reportDate',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.indigoFaded,
                ),
              ),
              SizedBox(height: 10),
              _section('📝 總評', [_report!.summary]),
              SizedBox(height: 12),
              _section('🎯 弱點模式', _report!.weakPoints,
                  color: AppColors.red),
              SizedBox(height: 12),
              _section('💪 練習建議', _report!.suggestions,
                  color: AppColors.green),
            ],
            SizedBox(height: 16),
            FilledButton.icon(
              icon: Icon(Icons.auto_awesome, size: 18),
              label: Text(_report == null ? '開始分析' : '重新分析'),
              onPressed: hasKey && hasData ? _analyze : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items, {Color? color}) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color ?? AppColors.indigo, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.indigo,
            ),
          ),
          SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                items.length > 1 ? '• $item' : item,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  fontWeight: FontWeight.w700,
                  color: AppColors.indigo,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
