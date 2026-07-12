import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 日文發音服務。測試以 fake override [ttsProvider]。
abstract class TtsService {
  Future<void> speak(String text);
  Future<void> stop();
}

/// flutter_tts 實作（ja-JP）。裝置無 TTS 引擎時靜默失敗。
class FlutterTtsService implements TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage('ja-JP');
      await _tts.setSpeechRate(0.45);
    } catch (_) {
      // 引擎不可用：保持未初始化，speak 時再試
    }
    _initialized = true;
  }

  @override
  Future<void> speak(String text) async {
    try {
      await _ensureInit();
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // 無 TTS 引擎（模擬器/Web 部分環境）：靜默跳過
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

final ttsProvider = Provider<TtsService>((ref) => FlutterTtsService());
