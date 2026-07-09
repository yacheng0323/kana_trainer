import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/prefs_provider.dart';

/// App 設定。
class Settings {
  final bool autoNext; // 答對後自動下一題
  final bool caseSensitive; // 區分大小寫（預設不區分）
  final bool showHint; // 顯示提示按鈕（首字母）
  final bool sound; // 音效/震動回饋
  final bool romajiHint; // 題目下方直接顯示羅馬拼音（學習模式）

  const Settings({
    this.autoNext = true,
    this.caseSensitive = false,
    this.showHint = true,
    this.sound = true,
    this.romajiHint = false,
  });

  Map<String, dynamic> toJson() => {
        'autoNext': autoNext,
        'caseSensitive': caseSensitive,
        'showHint': showHint,
        'sound': sound,
        'romajiHint': romajiHint,
      };

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        autoNext: json['autoNext'] as bool? ?? true,
        caseSensitive: json['caseSensitive'] as bool? ?? false,
        showHint: json['showHint'] as bool? ?? true,
        sound: json['sound'] as bool? ?? true,
        romajiHint: json['romajiHint'] as bool? ?? false,
      );

  Settings copyWith({
    bool? autoNext,
    bool? caseSensitive,
    bool? showHint,
    bool? sound,
    bool? romajiHint,
  }) =>
      Settings(
        autoNext: autoNext ?? this.autoNext,
        caseSensitive: caseSensitive ?? this.caseSensitive,
        showHint: showHint ?? this.showHint,
        sound: sound ?? this.sound,
        romajiHint: romajiHint ?? this.romajiHint,
      );
}

class SettingsNotifier extends Notifier<Settings> {
  static const storageKey = 'settings';

  @override
  Settings build() {
    final raw = ref.read(prefsProvider).getString(storageKey);
    if (raw == null) return const Settings();
    return Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  void update(Settings Function(Settings) updater) {
    state = updater(state);
    ref.read(prefsProvider).setString(storageKey, jsonEncode(state.toJson()));
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
