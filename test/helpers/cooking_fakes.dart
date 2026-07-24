import 'dart:async';

import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/cooking/application/monotonic_clock.dart';

final class FakeSpeechInput implements SpeechInputPort {
  int startCount = 0;
  int stopCount = 0;
  Object? startError;
  Object? stopError;
  SpeechInputFailure? startFailure;
  bool activateBeforeStartError = false;
  bool autoReady = true;
  bool hangOnStop = false;
  Completer<void>? pendingStop;
  void Function()? onStart;
  SpeechInputReadyHandler? onReady;
  SpeechUtteranceHandler? onUtterance;
  SpeechInputFailureHandler? onFailure;
  final List<SpeechUtteranceHandler> utteranceHandlers =
      <SpeechUtteranceHandler>[];

  @override
  void start({
    required SpeechInputReadyHandler onReady,
    required SpeechUtteranceHandler onUtterance,
    required SpeechInputFailureHandler onFailure,
  }) {
    startCount += 1;
    final currentError = startError;
    if (currentError != null && !activateBeforeStartError) {
      throw currentError;
    }
    this.onReady = onReady;
    this.onUtterance = onUtterance;
    this.onFailure = onFailure;
    utteranceHandlers.add(onUtterance);
    onStart?.call();
    if (currentError != null) {
      throw currentError;
    }
    final currentFailure = startFailure;
    if (currentFailure != null) {
      onFailure(currentFailure);
      return;
    }
    if (autoReady) {
      onReady();
    }
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    if (hangOnStop) {
      pendingStop ??= Completer<void>();
      await pendingStop!.future;
    }
    final currentError = stopError;
    if (currentError != null) {
      throw currentError;
    }
  }

  void emitUtterance(String utterance, {String? utteranceId}) {
    onUtterance?.call(utterance, utteranceId);
  }

  void emitReady() {
    onReady?.call();
  }

  void emitFailure(SpeechInputFailure failure) {
    onFailure?.call(failure);
  }

  void completePendingStop() {
    final completion = pendingStop;
    if (completion != null && !completion.isCompleted) {
      completion.complete();
    }
  }
}

final class FakeTimerAlarm implements TimerAlarmPort {
  int signalCount = 0;

  @override
  void signalTimerElapsed() => signalCount += 1;
}

final class FakeMonotonicClock implements MonotonicClock {
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;

  @override
  Duration get elapsed => _elapsed;

  @override
  bool get isRunning => _isRunning;

  void elapse(Duration duration) {
    if (_isRunning) {
      _elapsed += duration;
    }
  }

  @override
  void reset() => _elapsed = Duration.zero;

  @override
  void start() => _isRunning = true;

  @override
  void stop() => _isRunning = false;
}

final class FakeSpeechOutput implements SpeechOutputPort {
  final List<String> spoken = <String>[];
  int stopCount = 0;
  Object? error;
  Object? stopError;
  bool hangOnStop = false;
  Completer<void>? pendingStop;

  @override
  Future<void> speak(String text) {
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    spoken.add(text);
    return Future<void>.value();
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    if (hangOnStop) {
      pendingStop ??= Completer<void>();
      await pendingStop!.future;
    }
    final currentStopError = stopError;
    if (currentStopError != null) {
      throw currentStopError;
    }
  }

  void completePendingStop() {
    final completion = pendingStop;
    if (completion != null && !completion.isCompleted) {
      completion.complete();
    }
  }
}

final class DeferredSpeechOutput implements SpeechOutputPort {
  final List<String> spoken = <String>[];
  final List<Completer<void>> completions = <Completer<void>>[];
  int stopCount = 0;
  bool hangOnStop = false;
  Completer<void>? pendingStop;

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    final completer = Completer<void>();
    completions.add(completer);
    return completer.future;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    if (hangOnStop) {
      pendingStop ??= Completer<void>();
      await pendingStop!.future;
    }
    for (final completion in completions) {
      if (!completion.isCompleted) {
        completion.complete();
      }
    }
  }

  void completePendingStop() {
    final completion = pendingStop;
    if (completion != null && !completion.isCompleted) {
      completion.complete();
    }
  }
}

final class FakeExceptionAdvicePort implements ExceptionAdvicePort {
  FakeExceptionAdvicePort({
    this.response = const ExceptionAdvice(message: '불을 낮추고 30초 더 확인하세요.'),
    this.error,
  });

  final ExceptionAdvice response;
  Object? error;
  final List<ExceptionAdviceContext> requests = <ExceptionAdviceContext>[];

  @override
  Future<ExceptionAdvice> requestAdvice(ExceptionAdviceContext context) async {
    requests.add(context);
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    return response;
  }
}

final class DeferredExceptionAdvicePort implements ExceptionAdvicePort {
  final completer = Completer<ExceptionAdvice>();
  ExceptionAdviceContext? request;

  @override
  Future<ExceptionAdvice> requestAdvice(ExceptionAdviceContext context) {
    request = context;
    return completer.future;
  }
}

final class QueuedExceptionAdvicePort implements ExceptionAdvicePort {
  final List<ExceptionAdviceContext> requests = <ExceptionAdviceContext>[];
  final List<Completer<ExceptionAdvice>> completions =
      <Completer<ExceptionAdvice>>[];

  @override
  Future<ExceptionAdvice> requestAdvice(ExceptionAdviceContext context) {
    requests.add(context);
    final completer = Completer<ExceptionAdvice>();
    completions.add(completer);
    return completer.future;
  }
}
