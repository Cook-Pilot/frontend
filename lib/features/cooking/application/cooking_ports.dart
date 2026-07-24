import 'package:flutter/foundation.dart';

@immutable
final class ExceptionAdviceEvent {
  const ExceptionAdviceEvent({
    required this.stepIndex,
    required this.source,
    required this.command,
    required this.result,
    required this.occurredAt,
  });

  final int stepIndex;
  final String source;
  final String command;
  final String result;
  final DateTime occurredAt;
}

@immutable
final class ExceptionAdviceContext {
  const ExceptionAdviceContext({
    required this.sessionId,
    required this.recipeId,
    required this.recipeVersionId,
    required this.stepIndex,
    required this.requestContextVersion,
    required this.instruction,
    required this.remaining,
    required this.utterance,
    required this.recentEvents,
  });

  final String sessionId;
  final String recipeId;
  final String recipeVersionId;
  final int stepIndex;
  final int requestContextVersion;
  final String instruction;
  final Duration remaining;
  final String utterance;
  final List<ExceptionAdviceEvent> recentEvents;
}

@immutable
final class ExceptionAdvice {
  const ExceptionAdvice({required this.message});

  final String message;
}

abstract interface class SpeechOutputPort {
  /// Completes only after audible playback finishes or is cancelled.
  Future<void> speak(String text);

  /// Completes after the current playback has actually stopped.
  Future<void> stop();
}

enum SpeechInputFailure { retryRequired, permissionDenied, unavailable }

typedef SpeechUtteranceHandler =
    void Function(String utterance, String? utteranceId);
typedef SpeechInputFailureHandler = void Function(SpeechInputFailure failure);
typedef SpeechInputReadyHandler = void Function();

abstract interface class SpeechInputPort {
  /// Starts recognition without blocking on the recognition session lifetime.
  /// Readiness and asynchronous failures are reported through callbacks.
  void start({
    required SpeechInputReadyHandler onReady,
    required SpeechUtteranceHandler onUtterance,
    required SpeechInputFailureHandler onFailure,
  });

  Future<void> stop();
}

abstract interface class ExceptionAdvicePort {
  Future<ExceptionAdvice> requestAdvice(ExceptionAdviceContext context);
}

/// 타이머 종료 알림을 담당한다.
///
/// - [signalTimerElapsed]: 앱이 포그라운드일 때 즉시 알림음·진동을 낸다.
/// - [scheduleTimerElapsed]/[cancelScheduledAlarm]: 화면이 꺼지거나 앱이
///   백그라운드/종료 상태여도 OS가 [at] 시각에 알리도록 예약/취소한다.
///   (백그라운드에선 Dart isolate가 동결되어 앱이 직접 소리를 낼 수 없으므로
///   OS 예약이 유일한 수단이다.)
abstract interface class TimerAlarmPort {
  void signalTimerElapsed();
  Future<void> scheduleTimerElapsed(DateTime at);
  Future<void> cancelScheduledAlarm();
}

/// 알림을 내지 않는 기본 구현. 테스트와 무음 환경에서 사용한다.
final class SilentTimerAlarm implements TimerAlarmPort {
  const SilentTimerAlarm();

  @override
  void signalTimerElapsed() {}

  @override
  Future<void> scheduleTimerElapsed(DateTime at) async {}

  @override
  Future<void> cancelScheduledAlarm() async {}
}

final class DemoSpeechInput implements SpeechInputPort {
  @override
  void start({
    required SpeechInputReadyHandler onReady,
    required SpeechUtteranceHandler onUtterance,
    required SpeechInputFailureHandler onFailure,
  }) {
    onReady();
  }

  @override
  Future<void> stop() async {}
}

final class DemoSpeechOutput implements SpeechOutputPort {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

final class DemoExceptionAdvicePort implements ExceptionAdvicePort {
  @override
  Future<ExceptionAdvice> requestAdvice(ExceptionAdviceContext context) async {
    final normalized = context.utterance.replaceAll(' ', '');
    if (normalized.contains('안끓') || normalized.contains('끓지않')) {
      return const ExceptionAdvice(
        message:
            '냄비를 불 가운데에 두고 화력을 한 단계 높여보세요. 30초 뒤에도 변화가 없으면 화구가 켜졌는지 먼저 확인하세요.',
      );
    }
    return const ExceptionAdvice(
      message:
          '불을 잠시 낮추고 현재 단계를 멈춰 확인하세요. 안전 여부가 확실하지 않으면 먹지 말고 새 재료로 다시 시작하세요.',
    );
  }
}
