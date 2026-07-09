import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 單例，於 main() 以 overrideWithValue 注入。
final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefsProvider 必須在 main() override');
});
