import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/domain/models/menu_models.dart';
export 'package:kana_trainer/domain/models/menu_models.dart';

class MenuDoneNotifier extends Notifier<MenuDone> {
  static const storageKey = 'menu_done';

  @override
  MenuDone build() {
    final raw = ref.read(keyValueStoreProvider).getString(storageKey);
    if (raw == null) return const MenuDone();
    return MenuDone.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  bool get doneToday => state.date == StatsNotifier.today();

  void markDone({required int score, required int total}) {
    state = MenuDone(date: StatsNotifier.today(), score: score, total: total);
    ref.read(keyValueStoreProvider).setString(storageKey, jsonEncode(state.toJson()));
  }
}

final menuDoneProvider =
    NotifierProvider<MenuDoneNotifier, MenuDone>(MenuDoneNotifier.new);
