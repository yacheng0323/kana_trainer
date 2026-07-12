import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/domain/models/exam_models.dart';

/// 模擬測驗成績歷史（新的在前）。
class ExamHistoryNotifier extends Notifier<List<ExamRecord>> {
  static const storageKey = 'exam_history';

  @override
  List<ExamRecord> build() {
    final raw = ref.read(keyValueStoreProvider).getString(storageKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => ExamRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void add(ExamRecord record) {
    state = [record, ...state];
    ref.read(keyValueStoreProvider).setString(
          storageKey,
          jsonEncode(state.map((r) => r.toJson()).toList()),
        );
  }
}

final examHistoryProvider =
    NotifierProvider<ExamHistoryNotifier, List<ExamRecord>>(
  ExamHistoryNotifier.new,
);
