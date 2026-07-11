import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/prefs_provider.dart';
import '../progress/stats_notifier.dart';

/// 今日菜單完成紀錄：{date, score, total}。跨日自動視為未完成。
class MenuDone {
  final String date;
  final int score;
  final int total;

  const MenuDone({this.date = '', this.score = 0, this.total = 0});

  Map<String, dynamic> toJson() => {'date': date, 'score': score, 'total': total};

  factory MenuDone.fromJson(Map<String, dynamic> json) => MenuDone(
        date: json['date'] as String? ?? '',
        score: json['score'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
      );
}

class MenuDoneNotifier extends Notifier<MenuDone> {
  static const storageKey = 'menu_done';

  @override
  MenuDone build() {
    final raw = ref.read(prefsProvider).getString(storageKey);
    if (raw == null) return const MenuDone();
    return MenuDone.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  bool get doneToday => state.date == StatsNotifier.today();

  void markDone({required int score, required int total}) {
    state = MenuDone(date: StatsNotifier.today(), score: score, total: total);
    ref.read(prefsProvider).setString(storageKey, jsonEncode(state.toJson()));
  }
}

final menuDoneProvider =
    NotifierProvider<MenuDoneNotifier, MenuDone>(MenuDoneNotifier.new);
