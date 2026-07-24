import '../application/cooking_ports.dart';
import 'local_notification_timer_alarm.dart';

/// 앱 전체에서 하나의 [LocalNotificationTimerAlarm]만 초기화해 재사용한다.
/// 최초 호출 시 플러그인·타임존을 준비하고 알림 권한을 요청한다.
Future<TimerAlarmPort>? _pending;

Future<TimerAlarmPort> resolveTimerAlarm() {
  return _pending ??= LocalNotificationTimerAlarm.initialize();
}
