import 'package:flutter/services.dart';

import '../application/cooking_ports.dart';

/// 의존성 없이 OS 기본 알림음과 진동으로 타이머 종료를 알린다.
/// 소리가 무음일 때를 대비해 햅틱도 함께 울린다.
final class SystemTimerAlarm implements TimerAlarmPort {
  const SystemTimerAlarm();

  @override
  void signalTimerElapsed() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  }
}
