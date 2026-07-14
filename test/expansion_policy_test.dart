import 'package:flutter_test/flutter_test.dart';
import 'package:kana_trainer/domain/logic/expansion_policy.dart';

void main() {
  test('門檻與上限（v2.6.2 放寬：詞彙量持續成長）', () {
    expect(ExpansionPolicy.unseenThreshold, 10);
    expect(ExpansionPolicy.dailyLimit, 20);
  });

  test('未見過 < 門檻 且 今日 < 上限 且開啟 → 補貨', () {
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: true,
            unseenCount: ExpansionPolicy.unseenThreshold - 1,
            dailyCount: 0),
        isTrue);
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: true,
            unseenCount: 0,
            dailyCount: ExpansionPolicy.dailyLimit - 1),
        isTrue);
  });

  test('未見過夠多且池夠大 → 不補', () {
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: true,
            unseenCount: ExpansionPolicy.unseenThreshold,
            dailyCount: 0,
            poolSize: ExpansionPolicy.minPoolSize),
        isFalse);
  });

  test('池子太小 → 即使全是未見過也補（新主題第一天就長詞彙）', () {
    // v2.8.1 修：全新主題 15 字全未見過（15≥10），舊條件永不觸發
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: true, unseenCount: 15, dailyCount: 0, poolSize: 15),
        isTrue);
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: true,
            unseenCount: 15,
            dailyCount: 0,
            poolSize: ExpansionPolicy.minPoolSize),
        isFalse);
  });

  test('今日達上限 → 不補', () {
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: true,
            unseenCount: 0,
            dailyCount: ExpansionPolicy.dailyLimit),
        isFalse);
  });

  test('關閉 → 永不補', () {
    expect(
        ExpansionPolicy.shouldExpand(
            enabled: false, unseenCount: 0, dailyCount: 0),
        isFalse);
  });
}
