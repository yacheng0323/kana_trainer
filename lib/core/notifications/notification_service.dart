import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 每日提醒服務。測試以 fake override [notificationServiceProvider]。
abstract class NotificationService {
  /// 回傳是否取得通知權限。
  Future<bool> requestPermission();

  Future<void> scheduleDaily({required int hour, required int minute});

  Future<void> cancel();
}

/// flutter_local_notifications 實作（Android；Web/桌面靜默 no-op）。
/// 使用 inexact 排程，免 exact-alarm 權限。
class LocalNotificationService implements NotificationService {
  static const _id = 1001;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // 取不到時區就用預設（UTC），提醒時間會偏移但不炸
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    try {
      await _ensureInit();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> scheduleDaily({required int hour, required int minute}) async {
    if (!_supported) return;
    try {
      await _ensureInit();
      var when = tz.TZDateTime(
        tz.local,
        tz.TZDateTime.now(tz.local).year,
        tz.TZDateTime.now(tz.local).month,
        tz.TZDateTime.now(tz.local).day,
        hour,
        minute,
      );
      if (when.isBefore(tz.TZDateTime.now(tz.local))) {
        when = when.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        _id,
        '今天還沒練日語喔 🔥',
        '今日任務等著你，別讓連續達標斷掉！',
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            '每日提醒',
            channelDescription: '每天固定時間提醒學習',
            importance: Importance.defaultImportance,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // 每天重複
      );
    } catch (_) {
      // 排程失敗靜默（模擬器/權限問題），不影響 App 使用
    }
  }

  @override
  Future<void> cancel() async {
    if (!_supported) return;
    try {
      await _ensureInit();
      await _plugin.cancel(_id);
    } catch (_) {}
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => LocalNotificationService());
