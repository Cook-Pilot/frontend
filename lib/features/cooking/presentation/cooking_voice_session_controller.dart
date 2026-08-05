import 'dart:async';

import 'package:flutter/widgets.dart';

import '../application/cooking_ports.dart';
import '../application/monotonic_clock.dart';

enum CookingVoiceSpeechPhase {
  idle,
  starting,
  listening,
  stopping,
  permissionDenied,
  retryRequired,
  unavailable,
}

typedef CookingVoiceStateHandler =
    void Function(CookingVoiceSpeechPhase phase, String? message);
typedef CookingVoiceTranscriptHandler = void Function(String transcript);

/// Owns one cooking screen's speech-input lifecycle.
///
/// Routing a final transcript and applying cooking actions deliberately stay
/// in the screen. This controller owns only microphone serialization, stale
/// callback rejection, lifecycle recovery, and hands-free rearming.
final class CookingVoiceSessionController {
  CookingVoiceSessionController({
    required this.speechInput,
    required bool handsFreeEnabled,
    required AppLifecycleState initialLifecycleState,
    required this.onStateChanged,
    required this.onTranscript,
    MonotonicClock? retryClock,
    this.retryWindow = const Duration(seconds: 6),
    this.maxAutomaticRetries = 5,
  }) : assert(retryWindow > Duration.zero),
       assert(maxAutomaticRetries >= 0),
       _handsFreeEnabled = handsFreeEnabled,
       _appLifecycleState = initialLifecycleState,
       _handsFreeAutoRearm = handsFreeEnabled,
       _retryClock = retryClock ?? StopwatchMonotonicClock();

  final SpeechInputPort speechInput;
  final CookingVoiceStateHandler onStateChanged;
  final CookingVoiceTranscriptHandler onTranscript;

  /// Total window in which a short OEM no-speech session may be retried.
  ///
  /// This is checked only after a recognizer failure. It never cuts off a
  /// session while a user is speaking.
  final Duration retryWindow;

  /// Circuit breaker for recognizers that fail immediately in a tight loop.
  final int maxAutomaticRetries;

  final bool _handsFreeEnabled;
  final MonotonicClock _retryClock;
  final Set<String> _seenUtteranceIds = <String>{};

  CookingVoiceSpeechPhase _phase = CookingVoiceSpeechPhase.idle;
  Future<void>? _stopFuture;
  AppLifecycleState _appLifecycleState;
  int _sessionGeneration = 0;
  int _resumeRestartEpoch = 0;
  int _automationEpoch = 0;
  int _automaticRetriesRemaining = 0;
  bool _restartOnResume = false;
  bool _resumeRestartTaskPending = false;
  bool _handsFreeAutoRearm;
  bool _handsFreeStartRequested = false;
  bool _handsFreeHasStarted = false;
  bool _completed = false;
  bool _disposed = false;

  CookingVoiceSpeechPhase get phase => _phase;

  bool get isActive =>
      _phase == CookingVoiceSpeechPhase.starting ||
      _phase == CookingVoiceSpeechPhase.listening ||
      _phase == CookingVoiceSpeechPhase.stopping;

  bool get shouldAutoStartHandsFree => _handsFreeAutoRearm;

  /// Starts the explicit hands-free choice, or defers it across a transient
  /// inactive permission overlay. A hidden/paused transition disarms it unless
  /// the caller identifies its own pending permission flow below.
  Future<void> startHandsFree() {
    if (!_handsFreeAutoRearm || _disposed || _completed) {
      return Future<void>.value();
    }
    _handsFreeStartRequested = true;
    if (_appLifecycleState == AppLifecycleState.inactive) {
      _restartOnResume = true;
      return Future<void>.value();
    }
    if (_appLifecycleState != AppLifecycleState.resumed) {
      disableAutomaticRearm();
      return Future<void>.value();
    }
    _handsFreeHasStarted = true;
    return start();
  }

  /// [preservePendingHandsFreeStart] retains only a not-yet-started opt-in
  /// across hidden/paused. Detached always disarms because no host view remains.
  /// The caller remains responsible for starting it after returning resumed.
  void handleLifecycleStateChanged(
    AppLifecycleState state, {
    bool preservePendingHandsFreeStart = false,
  }) {
    if (_disposed || _completed) {
      return;
    }
    _appLifecycleState = state;

    if (state == AppLifecycleState.resumed) {
      // Duplicate resumed notifications must not invalidate a restart that is
      // already waiting for the previous native stop to drain.
      if (_restartOnResume && !_resumeRestartTaskPending) {
        _restartOnResume = false;
        final restartEpoch = _resumeRestartEpoch;
        _resumeRestartTaskPending = true;
        unawaited(_restartAfterStop(restartEpoch));
      }
      return;
    }

    final pendingRestart = _resumeRestartTaskPending;
    _resumeRestartTaskPending = false;
    _resumeRestartEpoch++;
    _closeRetryWindow();

    final preserveCallerOwnedStart =
        preservePendingHandsFreeStart &&
        (state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused) &&
        _handsFreeAutoRearm &&
        !_handsFreeHasStarted;
    if (preserveCallerOwnedStart) {
      // The caller owns this app-initiated permission flow and will start only
      // after both that flow and a resumed lifecycle have completed. Retain
      // the explicit opt-in without scheduling this controller's own restart.
      _restartOnResume = false;
    } else if (state == AppLifecycleState.inactive) {
      // Permission dialogs and overlays are indistinguishable. Replace a
      // starting session after a direct inactive -> resumed transition, but
      // never auto-resume an established listening session.
      final preserveDeferredStart =
          _restartOnResume ||
          pendingRestart ||
          _phase == CookingVoiceSpeechPhase.starting ||
          (_handsFreeAutoRearm &&
              _handsFreeStartRequested &&
              !_handsFreeHasStarted);
      _restartOnResume = preserveDeferredStart;
      if (!preserveDeferredStart &&
          (_handsFreeStartRequested || _handsFreeHasStarted)) {
        _handsFreeAutoRearm = false;
        _handsFreeStartRequested = false;
        _automationEpoch++;
      }
    } else {
      // hidden/paused/detached means the app actually left the foreground.
      _restartOnResume = false;
      _handsFreeAutoRearm = false;
      _handsFreeStartRequested = false;
      _automationEpoch++;
    }

    final message = isActive ? '화면을 벗어나 음성 입력을 멈췄어요.' : null;
    unawaited(deactivate(forceStop: true, message: message));
  }

  void toggle() {
    if (_phase == CookingVoiceSpeechPhase.starting ||
        _phase == CookingVoiceSpeechPhase.listening) {
      disableAutomaticRearm();
      unawaited(deactivate(message: '음성 입력을 멈췄어요.'));
      return;
    }
    if (_phase != CookingVoiceSpeechPhase.stopping) {
      _handsFreeAutoRearm = _handsFreeEnabled;
      _handsFreeStartRequested = _handsFreeEnabled;
      _automationEpoch++;
      unawaited(start());
    }
  }

  /// Begins one logical request. Short retryRequired sessions share a bounded
  /// retry window so an OEM's one-second initial timeout does not immediately
  /// send the user back to the button.
  Future<void> start() async {
    if (!_canStart || isActive) {
      return;
    }
    if (_handsFreeAutoRearm) {
      _handsFreeStartRequested = true;
      _handsFreeHasStarted = true;
    }
    await _startAttempt(beginRetryWindow: true);
  }

  Future<void> deactivate({bool forceStop = false, String? message}) async {
    final wasActive = isActive;
    if (!wasActive && !forceStop) {
      return;
    }

    _closeRetryWindow();
    final stopGeneration = ++_sessionGeneration;
    _emit(
      wasActive
          ? CookingVoiceSpeechPhase.stopping
          : CookingVoiceSpeechPhase.idle,
      message: message,
    );
    await _stopSpeechPort();
    if (_isCurrentSession(stopGeneration)) {
      _emit(CookingVoiceSpeechPhase.idle);
    }
  }

  /// Stops a step-bound session and opens a fresh one only when hands-free is
  /// still armed. This rejects callbacks captured from the previous step.
  Future<void> deactivateAndRearmHandsFree({String? message}) async {
    final shouldRearm = _handsFreeAutoRearm;
    final automationEpoch = _automationEpoch;
    await deactivate(message: message);
    await Future<void>.value();
    if (shouldRearm &&
        automationEpoch == _automationEpoch &&
        _canRearmHandsFree) {
      await start();
    }
  }

  /// Prevents hands-free, bounded retry, or lifecycle recovery from opening
  /// another microphone session.
  void disableAutomaticRearm() {
    _handsFreeAutoRearm = false;
    _handsFreeStartRequested = false;
    _restartOnResume = false;
    _resumeRestartTaskPending = false;
    _resumeRestartEpoch++;
    _automationEpoch++;
    _closeRetryWindow();
  }

  /// Invalidates callbacks and starts closing the microphone immediately.
  void complete() {
    if (_completed || _disposed) {
      return;
    }
    _completed = true;
    disableAutomaticRearm();
    _sessionGeneration++;
    unawaited(_stopSpeechPort());
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    disableAutomaticRearm();
    _sessionGeneration++;
    unawaited(_stopSpeechPort());
  }

  bool get _canStart =>
      !_disposed &&
      !_completed &&
      _appLifecycleState == AppLifecycleState.resumed;

  bool get _canRearmHandsFree => _handsFreeAutoRearm && _canStart && !isActive;

  bool _isCurrentSession(int generation) =>
      !_disposed && !_completed && generation == _sessionGeneration;

  void _beginRetryWindow() {
    _retryClock
      ..stop()
      ..reset()
      ..start();
    _automaticRetriesRemaining = maxAutomaticRetries;
  }

  void _closeRetryWindow() {
    _retryClock.stop();
    _automaticRetriesRemaining = 0;
  }

  bool get _canRetryCurrentRequest =>
      _canStart &&
      _retryClock.isRunning &&
      _retryClock.elapsed < retryWindow &&
      _automaticRetriesRemaining > 0;

  Future<void> _startAttempt({
    int? replacingGeneration,
    bool beginRetryWindow = false,
  }) async {
    if (!_canStart) {
      return;
    }
    if (replacingGeneration == null) {
      if (isActive) {
        return;
      }
    } else if (!_isCurrentSession(replacingGeneration) ||
        _phase != CookingVoiceSpeechPhase.stopping) {
      return;
    }

    final generation = ++_sessionGeneration;
    _emit(CookingVoiceSpeechPhase.starting, message: '마이크를 준비하고 있어요.');

    final pendingStop = _stopFuture;
    if (pendingStop != null) {
      await pendingStop;
    }
    if (!_isCurrentSession(generation) || !_canStart) {
      return;
    }
    if (beginRetryWindow) {
      // A previous native stop can take time to drain. Count the retry window
      // only from the point this request can actually reach the port.
      _beginRetryWindow();
    }

    try {
      speechInput.start(
        onReady: () {
          if (!_isCurrentSession(generation)) {
            return;
          }
          if (_appLifecycleState != AppLifecycleState.resumed) {
            if (_appLifecycleState == AppLifecycleState.inactive) {
              _restartOnResume = true;
            } else {
              disableAutomaticRearm();
            }
            unawaited(
              deactivate(forceStop: true, message: '화면을 벗어나 음성 입력을 멈췄어요.'),
            );
            return;
          }
          _emit(
            CookingVoiceSpeechPhase.listening,
            message: '듣고 있어요. “다음 단계”처럼 말해보세요.',
          );
        },
        onUtterance: (utterance, utteranceId) {
          _handleUtterance(
            utterance,
            utteranceId: utteranceId,
            sessionGeneration: generation,
          );
        },
        onFailure: (failure) {
          _handleFailure(failure, sessionGeneration: generation);
        },
      );
    } catch (_) {
      _handleFailure(
        SpeechInputFailure.unavailable,
        sessionGeneration: generation,
      );
    }
  }

  Future<void> _stopSpeechPort() {
    final pending = _stopFuture;
    if (pending != null) {
      return pending;
    }

    late final Future<void> currentStop;
    currentStop = (() async {
      try {
        await speechInput.stop();
      } catch (_) {
        // Button and timer controls must remain usable after port failures.
      }
    })();
    _stopFuture = currentStop;
    unawaited(
      currentStop.whenComplete(() {
        if (identical(_stopFuture, currentStop)) {
          _stopFuture = null;
        }
      }),
    );
    return currentStop;
  }

  Future<void> _restartAfterStop(int restartEpoch) async {
    final pendingStop = _stopFuture;
    if (pendingStop != null) {
      await pendingStop;
    }
    if (restartEpoch != _resumeRestartEpoch) {
      return;
    }
    _resumeRestartTaskPending = false;
    if (_canStart) {
      await start();
    }
  }

  void _handleFailure(
    SpeechInputFailure failure, {
    required int sessionGeneration,
  }) {
    if (!_isCurrentSession(sessionGeneration)) {
      return;
    }

    if (failure == SpeechInputFailure.retryRequired &&
        _canRetryCurrentRequest) {
      _automaticRetriesRemaining--;
      final retryGeneration = ++_sessionGeneration;
      _emit(
        CookingVoiceSpeechPhase.stopping,
        message: '조금 더 기다릴게요. 음성 입력을 다시 준비하고 있어요.',
      );
      final completedStop = _stopSpeechPort();
      unawaited(_restartRetryAfterStop(completedStop, retryGeneration));
      return;
    }

    disableAutomaticRearm();
    _sessionGeneration++;
    final (phase, message) = switch (failure) {
      SpeechInputFailure.permissionDenied => (
        CookingVoiceSpeechPhase.permissionDenied,
        '마이크 권한이 없어요. 직접 입력으로 질문할 수 있어요.',
      ),
      SpeechInputFailure.retryRequired => (
        CookingVoiceSpeechPhase.retryRequired,
        '음성을 인식하지 못했어요. 다시 시도하거나 직접 입력해주세요.',
      ),
      SpeechInputFailure.unavailable => (
        CookingVoiceSpeechPhase.unavailable,
        '이 기기에서는 음성 입력을 사용할 수 없어요. 직접 입력을 이용해주세요.',
      ),
    };
    _emit(phase, message: message);
    unawaited(_stopSpeechPort());
  }

  Future<void> _restartRetryAfterStop(
    Future<void> completedStop,
    int retryGeneration,
  ) async {
    await completedStop;
    await Future<void>.value();
    if (_isCurrentSession(retryGeneration) && _canStart) {
      await _startAttempt(replacingGeneration: retryGeneration);
    }
  }

  void _handleUtterance(
    String utterance, {
    required String? utteranceId,
    required int sessionGeneration,
  }) {
    if (!_isCurrentSession(sessionGeneration)) {
      return;
    }
    if (utteranceId != null && !_rememberUtteranceId(utteranceId)) {
      return;
    }

    final transcript = utterance.trim();
    if (transcript.isEmpty) {
      _handleFailure(
        SpeechInputFailure.retryRequired,
        sessionGeneration: sessionGeneration,
      );
      return;
    }

    _closeRetryWindow();
    _sessionGeneration++;
    _emit(CookingVoiceSpeechPhase.idle, message: '“$transcript”로 들었어요.');
    final completedStop = _stopSpeechPort();
    final automationEpoch = _automationEpoch;
    try {
      onTranscript(transcript);
    } finally {
      unawaited(_rearmHandsFreeAfterCommand(completedStop, automationEpoch));
    }
  }

  Future<void> _rearmHandsFreeAfterCommand(
    Future<void> completedStop,
    int automationEpoch,
  ) async {
    await completedStop;
    await Future<void>.value();
    if (automationEpoch == _automationEpoch && _canRearmHandsFree) {
      await start();
    }
  }

  bool _rememberUtteranceId(String utteranceId) {
    if (!_seenUtteranceIds.add(utteranceId)) {
      return false;
    }
    if (_seenUtteranceIds.length > 64) {
      _seenUtteranceIds
        ..clear()
        ..add(utteranceId);
    }
    return true;
  }

  void _emit(CookingVoiceSpeechPhase phase, {String? message}) {
    if (_disposed || _completed) {
      return;
    }
    _phase = phase;
    onStateChanged(phase, message);
  }
}
