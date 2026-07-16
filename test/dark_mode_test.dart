import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/app/app.dart';
import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/data/storage/prefs_provider.dart';
import 'package:kana_trainer/features/settings/settings_notifier.dart';
import 'package:kana_trainer/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AppColors.dark = false); // 全域開關，測試間必須歸零

  group('palette 翻轉', () {
    test('dark=true 時全部 token 換色、dark=false 還原', () {
      final lightValues = [
        AppColors.cream,
        AppColors.surface,
        AppColors.indigo,
        AppColors.gold,
        AppColors.green,
        AppColors.red,
        AppColors.indigoFaded,
      ];
      AppColors.dark = true;
      final darkValues = [
        AppColors.cream,
        AppColors.surface,
        AppColors.indigo,
        AppColors.gold,
        AppColors.green,
        AppColors.red,
        AppColors.indigoFaded,
      ];
      for (var i = 0; i < lightValues.length; i++) {
        expect(darkValues[i], isNot(lightValues[i]), reason: 'token $i 沒翻');
      }
      AppColors.dark = false;
      expect(AppColors.cream, lightValues[0]);
    });

    test('indigoSurface 兩模式都是深色（填色不能翻淺）', () {
      expect(AppColors.indigoSurface.computeLuminance(), lessThan(0.2));
      AppColors.dark = true;
      expect(AppColors.indigoSurface.computeLuminance(), lessThan(0.2));
    });

    test('深色主題 scaffold 背景 = 深色 cream', () {
      AppColors.dark = true;
      expect(AppTheme.current.scaffoldBackgroundColor,
          const Color(0xFF14162B));
    });
  });

  group('resolveDark', () {
    test('三態解析', () {
      expect(resolveDark('dark', Brightness.light), isTrue);
      expect(resolveDark('light', Brightness.dark), isFalse);
      expect(resolveDark('system', Brightness.dark), isTrue);
      expect(resolveDark('system', Brightness.light), isFalse);
    });
  });

  group('Settings.themeMode', () {
    test('round-trip + 壞值 fallback system', () {
      const s = Settings(themeMode: 'dark');
      expect(Settings.fromJson(s.toJson()).themeMode, 'dark');
      expect(Settings.fromJson({'themeMode': '???'}).themeMode, 'system');
      expect(Settings.fromJson({}).themeMode, 'system');
    });
  });

  testWidgets('設定頁切深色 → 持久化', (tester) async {
    tester.view.physicalSize = const Size(800, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    expect(container.read(settingsProvider).themeMode, 'system');
    await tester.tap(find.text('深色'));
    await tester.pump();
    expect(container.read(settingsProvider).themeMode, 'dark');
  });

  testWidgets('KanaTrainerApp：themeMode=dark → AppColors.dark 生效', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings', '{"themeMode":"dark"}');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const KanaTrainerApp(),
      ),
    );
    await tester.pump();
    expect(AppColors.dark, isTrue);
  });
}
