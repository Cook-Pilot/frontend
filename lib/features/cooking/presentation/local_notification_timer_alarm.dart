import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../application/cooking_ports.dart';

/// 화면이 꺼지거나 앱이 백그라운드/종료 상태여도 OS가 타이머 완료 시각에
/// 알림음을 울리도록 로컬 알림을 예약한다. 포그라운드에서는 즉시 소리·진동을 낸다.
///
/// 초기화(권한 요청 포함)는 [initialize]로 한 번만 수행한다.
final class LocalNotificationTimerAlarm implements TimerAlarmPort {
  LocalNotificationTimerAlarm(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// 타이머 알림은 항상 하나만 유지되므로 고정 id를 재사용한다.
  static const int _notificationId = 7001;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'cooking_timer',
      '조리 타이머',
      channelDescription: '조리 타이머가 끝나면 알립니다.',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  /// 플러그인·타임존을 초기화하고 알림/정확 알람 권한을 요청한다.
  static Future<LocalNotificationTimerAlarm> initialize() async {
    tzdata.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestSoundPermission: true,
        ),
      ),
    );
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    // 정확한 시각 알람(Android 12+). 거부되면 inexact로 대체된다.
    await android?.requestExactAlarmsPermission();
    return LocalNotificationTimerAlarm(plugin);
  }

  @override
  void signalTimerElapsed() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  }

  @override
  Future<void> scheduleTimerElapsed(DateTime at) async {
    final now = tz.TZDateTime.now(tz.local);
    final when = tz.TZDateTime.from(at, tz.local);
    // 과거 시각이면 즉시(1초 뒤)로 보정한다.
    final target = when.isAfter(now) ? when : now.add(const Duration(seconds: 1));
    await _plugin.zonedSchedule(
      _notificationId,
      '조리 타이머 완료',
      '설정한 시간이 끝났어요. 다음 단계를 확인하세요.',
      target,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelScheduledAlarm() => _plugin.cancel(_notificationId);
}
