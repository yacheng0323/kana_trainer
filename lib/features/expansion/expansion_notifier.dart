import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/ai/ai_quiz_service.dart';
import 'package:kana_trainer/data/ai/content_expansion_service.dart';
import 'package:kana_trainer/data/content/merged_content_repository.dart';
import 'package:kana_trainer/data/storage/dynamic_content_store.dart';
import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/domain/entities/grammar.dart';
import 'package:kana_trainer/domain/entities/sentence.dart';
import 'package:kana_trainer/domain/entities/vocab.dart';
import 'package:kana_trainer/domain/logic/expansion_policy.dart';
import 'package:kana_trainer/domain/repositories/ai_client.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';

enum ExpansionStatus { idle, generating, done, error }

class ExpansionState {
  final ExpansionStatus status;
  final int todayCount; // 今日已生成批數
  final int lastAdded; // 最近一批入池題數（SnackBar 用）
  final String? error;

  const ExpansionState({
    this.status = ExpansionStatus.idle,
    this.todayCount = 0,
    this.lastAdded = 0,
    this.error,
  });

  ExpansionState copyWith({
    ExpansionStatus? status,
    int? todayCount,
    int? lastAdded,
    String? error,
  }) =>
      ExpansionState(
        status: status ?? this.status,
        todayCount: todayCount ?? this.todayCount,
        lastAdded: lastAdded ?? this.lastAdded,
        error: error,
      );
}

/// 題庫自動補貨。fire-and-forget：練習頁 initState 呼叫，不 await 不擋 UI。
/// 失敗靜默（練習照常用現有池），僅設定頁可見狀態。
class ExpansionNotifier extends Notifier<ExpansionState> {
  static const dailyKey = 'expansion_daily';

  @override
  ExpansionState build() => ExpansionState(todayCount: _readDailyCount());

  int _readDailyCount() {
    final raw = ref.read(keyValueStoreProvider).getString(dailyKey);
    if (raw == null) return 0;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['date'] != StatsNotifier.today()) return 0; // 跨日重置
      return json['count'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _bumpDailyCount() async {
    final count = _readDailyCount() + 1;
    await ref.read(keyValueStoreProvider).setString(
        dailyKey, jsonEncode({'date': StatsNotifier.today(), 'count': count}));
    state = state.copyWith(todayCount: count);
  }

  /// 共用補貨流程。先計數再生成：壞回應/失敗也算一批，防重試迴圈。
  Future<void> _maybeExpand({
    required int unseenCount,
    required Future<int> Function(String apiKey) generateAndStore,
  }) async {
    final apiKey = ref.read(apiKeyProvider);
    final enabled = ref.read(settingsProvider).autoExpand && apiKey.isNotEmpty;
    if (!ExpansionPolicy.shouldExpand(
      enabled: enabled,
      unseenCount: unseenCount,
      dailyCount: _readDailyCount(),
    )) {
      return;
    }
    await _bumpDailyCount();
    state = state.copyWith(status: ExpansionStatus.generating);
    try {
      final added = await generateAndStore(apiKey);
      state = state.copyWith(
          status: ExpansionStatus.done, lastAdded: added, error: null);
    } on AiException catch (e) {
      state = state.copyWith(status: ExpansionStatus.error, error: e.message);
    }
  }

  int _unseen(Iterable<String> keys) {
    final mastery = ref.read(masteryProvider);
    return keys.where((k) => (mastery[k] ?? 0) == 0).length;
  }

  Future<void> maybeExpandVocab(VocabTopic topic,
      {@visibleForTesting int? unseenOverride}) async {
    final repo = ref.read(contentRepositoryProvider);
    final pool = repo.vocab().where((w) => w.topic == topic);
    await _maybeExpand(
      unseenCount: unseenOverride ?? _unseen(pool.map((w) => w.key)),
      generateAndStore: (apiKey) async {
        final batch =
            await ref.read(contentExpansionServiceProvider).generateVocab(
                  apiKey: apiKey,
                  topic: topic,
                  existingJp: repo.vocab().map((w) => w.jp).toSet(),
                );
        return ref.read(dynamicContentStoreProvider).addVocab(batch,
            existingKeys: repo.vocab().map((w) => w.key).toSet());
      },
    );
  }

  Future<void> maybeExpandSentences(Scene scene,
      {@visibleForTesting int? unseenOverride}) async {
    final repo = ref.read(contentRepositoryProvider);
    final pool = repo.sentences().where((s) => s.scene == scene);
    await _maybeExpand(
      unseenCount: unseenOverride ?? _unseen(pool.map((s) => s.key)),
      generateAndStore: (apiKey) async {
        final batch =
            await ref.read(contentExpansionServiceProvider).generateSentences(
                  apiKey: apiKey,
                  scene: scene,
                  existingJp: repo.sentences().map((s) => s.jp).toSet(),
                );
        return ref.read(dynamicContentStoreProvider).addSentences(batch,
            existingKeys: repo.sentences().map((s) => s.key).toSet());
      },
    );
  }

  Future<void> maybeExpandGrammar(GrammarPoint point,
      {@visibleForTesting int? unseenOverride}) async {
    final repo = ref.read(contentRepositoryProvider);
    final existing = repo.grammarQuiz(point.id).map((q) => q.question).toSet();
    // 文法「未見過」定義：該課動態題少於門檻就補（教學固定、題目愈多愈好）
    final dynamicCount = existing.length - point.quiz.length;
    await _maybeExpand(
      unseenCount: unseenOverride ?? dynamicCount,
      generateAndStore: (apiKey) async {
        final batch = await ref
            .read(contentExpansionServiceProvider)
            .generateGrammarQuiz(
                apiKey: apiKey, point: point, existingQuestions: existing);
        return ref.read(dynamicContentStoreProvider).addGrammarQuiz(batch,
            existingKeys:
                existing.map((q) => '${point.id}|$q').toSet());
      },
    );
  }
}

final expansionProvider = NotifierProvider<ExpansionNotifier, ExpansionState>(
    ExpansionNotifier.new);
