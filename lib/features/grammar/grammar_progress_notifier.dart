import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/grammar_data.dart';
import '../../core/storage/prefs_provider.dart';

/// 已完成的文法課 id 集合。線性解鎖：第 i 課解鎖條件 = 第 i-1 課完成。
class GrammarProgressNotifier extends Notifier<Set<String>> {
  static const storageKey = 'grammar_done';

  @override
  Set<String> build() {
    final raw = ref.read(prefsProvider).getString(storageKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as List).cast<String>().toSet();
  }

  void markDone(String id) {
    state = {...state, id};
    ref.read(prefsProvider).setString(storageKey, jsonEncode(state.toList()));
  }

  bool isUnlocked(int index) {
    if (index == 0) return true;
    return state.contains(allGrammar[index - 1].id);
  }
}

final grammarProgressProvider =
    NotifierProvider<GrammarProgressNotifier, Set<String>>(
  GrammarProgressNotifier.new,
);
