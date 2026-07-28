import '../application/cooking_ports.dart';
import 'local_notification_timer_alarm.dart';

/// 앱 전체에서 하나의 [LocalNotificationTimerAlarm]만 초기화해 재사용한다.
/// 최초 호출 시 플러그인·타임존을 준비하고 알림 권한을 요청한다.
/// 초기화가 실패하면 캐시를 비워 다음 조리 화면 진입 때 다시 시도한다.
Future<TimerAlarmPort>? _pending;

Future<TimerAlarmPort> resolveTimerAlarm() {
  return _pending ??= LocalNotificationTimerAlarm.initialize().catchError((
    Object error,
    StackTrace stackTrace,
  ) {
    _pending = null;
    Error.throwWithStackTrace(error, stackTrace);
  });
}
