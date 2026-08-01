import '../application/cooking_ports.dart';
import 'local_notification_timer_alarm.dart';

typedef TimerAlarmPermissionFlowChanged = void Function(bool active);

/// 테스트 resolver도 실제 구현과 같은 권한-flow 경계를 화면에 전달한다.
typedef TimerAlarmResolver =
    Future<TimerAlarmPort> Function(
      TimerAlarmPermissionFlowChanged onPermissionFlowChanged,
    );

/// 앱 전체에서 하나의 [LocalNotificationTimerAlarm]만 초기화해 재사용한다.
/// 최초 호출 시 플러그인·타임존을 준비하고 알림 권한을 요청한다.
Future<TimerAlarmPort>? _pending;
bool _permissionFlowActive = false;
final Set<TimerAlarmPermissionFlowChanged> _permissionFlowListeners =
    <TimerAlarmPermissionFlowChanged>{};

Future<TimerAlarmPort> resolveTimerAlarm({
  TimerAlarmPermissionFlowChanged? onPermissionFlowChanged,
}) {
  if (onPermissionFlowChanged != null) {
    _permissionFlowListeners.add(onPermissionFlowChanged);
    if (_permissionFlowActive) {
      _notifyListener(onPermissionFlowChanged, true);
    }
  }
  final resolution = _pending ??= LocalNotificationTimerAlarm.initialize(
    onPermissionFlowChanged: _broadcastPermissionFlow,
  );
  return resolution.whenComplete(() {
    if (onPermissionFlowChanged != null) {
      _permissionFlowListeners.remove(onPermissionFlowChanged);
    }
  });
}

void _broadcastPermissionFlow(bool active) {
  if (_permissionFlowActive == active) {
    return;
  }
  _permissionFlowActive = active;
  for (final listener in List<TimerAlarmPermissionFlowChanged>.of(
    _permissionFlowListeners,
  )) {
    _notifyListener(listener, active);
  }
}

void _notifyListener(TimerAlarmPermissionFlowChanged listener, bool active) {
  try {
    listener(active);
  } catch (_) {
    // A disposed or faulty UI listener must not break the shared alarm setup.
  }
}
