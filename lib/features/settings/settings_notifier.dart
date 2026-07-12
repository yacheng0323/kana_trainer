import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kana_trainer/data/storage/prefs_store.dart';
import 'package:kana_trainer/domain/models/app_settings.dart';
export 'package:kana_trainer/domain/models/app_settings.dart';

class SettingsNotifier extends Notifier<Settings> {
  static const storageKey = 'settings';

  @override
  Settings build() {
    final raw = ref.read(keyValueStoreProvider).getString(storageKey);
    if (raw == null) return const Settings();
    return Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  void update(Settings Function(Settings) updater) {
    state = updater(state);
    ref.read(keyValueStoreProvider).setString(storageKey, jsonEncode(state.toJson()));
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
