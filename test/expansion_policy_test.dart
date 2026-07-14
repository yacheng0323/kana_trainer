import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/domain/logic/expansion_policy.dart';

void main() {
  test('未見過 < 5 且今日 < 5 批且開啟 → 補貨', () {
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: true, unseenCount: 4, dailyCount: 0),
        isTrue);
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: true, unseenCount: 0, dailyCount: 4),
        isTrue);
  });

  test('未見過夠多 → 不補', () {
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: true, unseenCount: 5, dailyCount: 0),
        isFalse);
  });

  test('今日達上限 → 不補', () {
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: true, unseenCount: 0, dailyCount: 5),
        isFalse);
  });

  test('關閉 → 永不補', () {
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: false, unseenCount: 0, dailyCount: 0),
        isFalse);
  });
}
