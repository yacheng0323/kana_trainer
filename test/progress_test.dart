import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/data/storage/prefs_provider.dart';
import 'package:kana_trainer/features/progress/mastery_notifier.dart';
import 'package:kana_trainer/features/progress/stats_notifier.dart';
import 'package:kana_trainer/features/progress/wrong_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> makeContainer() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [prefsProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StatsNotifier.today = () => '2026-07-09';
  });

  group('MasteryNotifier', () {
    test('答對 +1、答錯 -1、clamp 0..5', () async {
      final c = await makeContainer();
      final n = c.read(masteryProvider.notifier);
      n.record('か', correct: false); // 0-1 → clamp 0
      expect(c.read(masteryProvider)['か'], 0);
      for (var i = 0; i < 7; i++) {
        n.record('か', correct: true);
      }
      expect(c.read(masteryProvider)['か'], 5); // clamp 5
      n.record('か', correct: false);
      expect(c.read(masteryProvider)['か'], 4);
    });

    test('持久化：重建 container 後仍在', () async {
      final c1 = await makeContainer();
      c1.read(masteryProvider.notifier).record('き', correct: true);
      final c2 = await makeContainer();
      expect(c2.read(masteryProvider)['き'], 1);
    });

    test('progressOf 平均熟練度', () async {
      final c = await makeContainer();
      final n = c.read(masteryProvider.notifier);
      for (var i = 0; i < 5; i++) {
        n.record('か', correct: true);
      }
      // か=5, き=0 → (5+0)/(2*5) = 0.5
      expect(n.progressOf(['か', 'き']), 0.5);
    });
  });

  group('WrongNotifier', () {
    test('add 累計、resolve 遞減至移除、clear 全清', () async {
      final c = await makeContainer();
      final n = c.read(wrongProvider.notifier);
      n.add('シ');
      n.add('シ');
      expect(c.read(wrongProvider)['シ'], 2);
      n.resolve('シ');
      expect(c.read(wrongProvider)['シ'], 1);
      n.resolve('シ');
      expect(c.read(wrongProvider).containsKey('シ'), isFalse);
      n.add('か');
      n.clear();
      expect(c.read(wrongProvider), isEmpty);
    });

    test('持久化', () async {
      final c1 = await makeContainer();
      c1.read(wrongProvider.notifier).add('つ');
      final c2 = await makeContainer();
      expect(c2.read(wrongProvider)['つ'], 1);
    });
  });

  group('StatsNotifier', () {
    test('record 累計 total/correct/streak/today', () async {
      final c = await makeContainer();
      final n = c.read(statsProvider.notifier);
      n.record(correct: true);
      n.record(correct: true);
      n.record(correct: false);
      final s = c.read(statsProvider);
      expect(s.total, 3);
      expect(s.correct, 2);
      expect(s.wrong, 1);
      expect(s.currentStreak, 0); // 最後一題錯
      expect(s.bestStreak, 2);
      expect(s.todayTotal, 3);
      expect(s.todayCorrect, 2);
      expect(s.accuracy, closeTo(2 / 3, 0.001));
    });

    test('跨日 today 歸零，total 保留', () async {
      final c1 = await makeContainer();
      c1.read(statsProvider.notifier).record(correct: true);

      StatsNotifier.today = () => '2026-07-10';
      final c2 = await makeContainer();
      final s = c2.read(statsProvider);
      expect(s.todayTotal, 0);
      expect(s.total, 1);
    });
  });
}
