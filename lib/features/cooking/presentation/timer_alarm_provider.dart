import 'dart:async';

import '../application/cooking_ports.dart';
import 'local_notification_timer_alarm.dart';

typedef TimerAlarmPermissionFlowChanged = void Function(bool active);

/// 한 화면의 shared alarm 초기화 구독과 결과를 함께 소유한다.
///
/// [cancel]은 멱등이며 alarm 초기화가 끝나기 전 화면이 사라질 때 listener를
/// 즉시 제거한다. 초기화가 먼저 끝나도 provider가 자동으로 취소한다.
final class TimerAlarmRegistration {
  factory TimerAlarmRegistration({
    required Future<TimerAlarmPort> alarm,
    void Function()? onCancel,
  }) => TimerAlarmRegistration._(alarm, onCancel);

  TimerAlarmRegistration._(this.alarm, this._onCancel);

  final Future<TimerAlarmPort> alarm;
  void Function()? _onCancel;

  void cancel() {
    final onCancel = _onCancel;
    _onCancel = null;
    onCancel?.call();
  }
}

/// 테스트 resolver도 실제 구현과 같은 권한-flow 경계를 화면에 전달한다.
typedef TimerAlarmResolver =
    TimerAlarmRegistration Function(
      TimerAlarmPermissionFlowChanged onPermissionFlowChanged,
    );

typedef TimerAlarmInitializer =
    Future<TimerAlarmPort> Function(
      TimerAlarmPermissionFlowChanged onPermissionFlowChanged,
    );

/// 하나의 alarm 초기화를 공유하면서 각 화면 listener의 수명을 분리한다.
final class TimerAlarmProvider {
  factory TimerAlarmProvider({required TimerAlarmInitializer initialize}) =>
      TimerAlarmProvider._(initialize);

  TimerAlarmProvider._(this._initialize);

  final TimerAlarmInitializer _initialize;
  final Set<TimerAlarmPermissionFlowChanged> _permissionFlowListeners =
      <TimerAlarmPermissionFlowChanged>{};

  Future<TimerAlarmPort>? _pending;
  bool _permissionFlowActive = false;

  TimerAlarmRegistration resolve({
    TimerAlarmPermissionFlowChanged? onPermissionFlowChanged,
  }) {
    TimerAlarmPermissionFlowChanged? registeredListener;
    if (onPermissionFlowChanged != null) {
      // Wrapper identity gives every caller its own cancellable registration,
      // even when the same callback tear-off is supplied more than once.
      registeredListener = (active) =>
          _notifyListener(onPermissionFlowChanged, active);
      _permissionFlowListeners.add(registeredListener);
      if (_permissionFlowActive) {
        registeredListener(true);
      }
    }

    void cancel() {
      final listener = registeredListener;
      if (listener != null) {
        _permissionFlowListeners.remove(listener);
      }
    }

    var resolution = _pending;
    if (resolution == null) {
      final started = _initialize(_broadcastPermissionFlow);
      _pending = started;
      // 실패한 초기화를 캐시에 남기면 앱 재시작 전까지 모든 조리 화면이 같은
      // 실패를 재사용해 백그라운드 알람이 조용히 죽는다(호출부 catch가 삼킴).
      // 실패는 잊고 다음 resolve가 재시도하게 한다.
      unawaited(
        started.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {
            if (identical(_pending, started)) {
              _pending = null;
            }
          },
        ),
      );
      resolution = started;
    }
    late final TimerAlarmRegistration registration;
    registration = TimerAlarmRegistration(
      alarm: resolution.whenComplete(() => registration.cancel()),
      onCancel: cancel,
    );
    return registration;
  }

  void _broadcastPermissionFlow(bool active) {
    if (_permissionFlowActive == active) {
      return;
    }
    _permissionFlowActive = active;
    for (final listener in List<TimerAlarmPermissionFlowChanged>.of(
      _permissionFlowListeners,
    )) {
      listener(active);
    }
  }
}

/// 앱 전체에서 하나의 [LocalNotificationTimerAlarm]만 초기화해 재사용한다.
/// 최초 호출 시 플러그인·타임존을 준비하고 알림 권한을 요청한다.
final TimerAlarmProvider _sharedTimerAlarmProvider = TimerAlarmProvider(
  initialize: (onPermissionFlowChanged) =>
      LocalNotificationTimerAlarm.initialize(
        onPermissionFlowChanged: onPermissionFlowChanged,
      ),
);

TimerAlarmRegistration resolveTimerAlarm({
  TimerAlarmPermissionFlowChanged? onPermissionFlowChanged,
}) {
  return _sharedTimerAlarmProvider.resolve(
    onPermissionFlowChanged: onPermissionFlowChanged,
  );
}

void _notifyListener(TimerAlarmPermissionFlowChanged listener, bool active) {
  try {
    listener(active);
  } catch (_) {
    // A disposed or faulty UI listener must not break the shared alarm setup.
  }
}
