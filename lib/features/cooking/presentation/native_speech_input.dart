import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../application/cooking_ports.dart';

enum NativeSpeechDriverStatus { listening, notListening, done, unavailable }

@immutable
final class NativeSpeechDriverResult {
  const NativeSpeechDriverResult({
    required this.transcript,
    required this.isFinal,
  });

  final String transcript;
  final bool isFinal;
}

@immutable
final class NativeSpeechDriverError {
  const NativeSpeechDriverError({required this.code, required this.permanent});

  final String code;
  final bool permanent;
}

typedef NativeSpeechDriverResultHandler =
    void Function(NativeSpeechDriverResult result);
typedef NativeSpeechDriverErrorHandler =
    void Function(NativeSpeechDriverError error);
typedef NativeSpeechDriverStatusHandler =
    void Function(NativeSpeechDriverStatus status);

/// Small platform seam so lifecycle and error behavior can be tested without a
/// method channel or microphone.
abstract interface class NativeSpeechRecognitionDriver {
  Future<bool> get hasPermission;

  Future<bool> initialize({
    required NativeSpeechDriverErrorHandler onError,
    required NativeSpeechDriverStatusHandler onStatus,
  });

  Future<void> listen({
    required String localeId,
    required NativeSpeechDriverResultHandler onResult,
  });

  Future<void> stop();

  Future<void> cancel();
}

enum _SpeechLifecycleEndState { inProgress, succeeded, failed }

final class _SpeechLifecycleDrain {
  final Completer<void> _completer = Completer<void>();
  Timer? _probeTimer;
  Timer? _settleTimer;
  bool _doneSeen = false;
  _SpeechLifecycleEndState _endState = _SpeechLifecycleEndState.inProgress;

  Future<void> get done => _completer.future;

  bool tryBeginFailedEndRetry() {
    if (_endState != _SpeechLifecycleEndState.failed || _doneSeen) {
      return false;
    }
    _endState = _SpeechLifecycleEndState.inProgress;
    return true;
  }

  void observeRawCallback({required bool isDone}) {
    if (_completer.isCompleted) {
      return;
    }
    _doneSeen = _doneSeen || isDone;
    _scheduleQuietCompletion();
  }

  void markEndSucceeded() {
    if (_completer.isCompleted) {
      return;
    }
    _endState = _SpeechLifecycleEndState.succeeded;
    _scheduleQuietCompletion();
  }

  void markEndFailed() {
    if (_completer.isCompleted) {
      return;
    }
    _endState = _SpeechLifecycleEndState.failed;
    _scheduleQuietCompletion();
  }

  void _scheduleQuietCompletion() {
    if (!_doneSeen || _endState == _SpeechLifecycleEndState.inProgress) {
      return;
    }

    // The first turn is only a probe. A callback queued immediately after
    // `done` can otherwise sit behind a single zero-duration timer and arrive
    // after the drain opens. The second turn settles only if the raw callback
    // serial stayed quiet throughout both turns.
    _probeTimer?.cancel();
    _settleTimer?.cancel();
    _probeTimer = Timer(Duration.zero, () {
      _probeTimer = null;
      _settleTimer = Timer(Duration.zero, () {
        _settleTimer = null;
        if (!_completer.isCompleted) {
          _completer.complete();
        }
      });
    });
  }
}

/// Production driver backed by the device speech recognizer.
final class SpeechToTextRecognitionDriver
    implements NativeSpeechRecognitionDriver {
  factory SpeechToTextRecognitionDriver({
    SpeechToText? speech,
    Duration lifecycleDrainTimeout = _defaultLifecycleDrainTimeout,
  }) {
    if (speech != null) {
      return SpeechToTextRecognitionDriver._(speech, lifecycleDrainTimeout);
    }
    return _shared;
  }

  SpeechToTextRecognitionDriver._(this._speech, this._lifecycleDrainTimeout);

  static const Duration _defaultLifecycleDrainTimeout = Duration(seconds: 2);
  static final SpeechToTextRecognitionDriver _shared =
      SpeechToTextRecognitionDriver._(
        SpeechToText(),
        _defaultLifecycleDrainTimeout,
      );

  final SpeechToText _speech;
  final Duration _lifecycleDrainTimeout;
  NativeSpeechDriverErrorHandler? _onError;
  NativeSpeechDriverStatusHandler? _onStatus;
  _SpeechLifecycleDrain? _lifecycleDrain;
  bool _lifecycleActive = false;

  @override
  Future<bool> get hasPermission => _speech.hasPermission;

  @override
  Future<bool> initialize({
    required NativeSpeechDriverErrorHandler onError,
    required NativeSpeechDriverStatusHandler onStatus,
  }) async {
    // Never replace A's mutable forwarding slots until every raw callback
    // caused by ending A has drained.
    await _awaitPriorLifecycleDrain();

    // SpeechToText() is a process singleton. Once initialization succeeds it
    // returns early on later initialize calls without replacing its listeners.
    // Keep one shared driver and let the listener installed by the first call
    // forward to the handlers owned by the current cooking screen.
    _onError = onError;
    _onStatus = onStatus;
    return _speech.initialize(
      onError: _handleRawError,
      onStatus: _handleRawStatus,
    );
  }

  @override
  Future<void> listen({
    required String localeId,
    required NativeSpeechDriverResultHandler onResult,
  }) async {
    await _awaitPriorLifecycleDrain();
    _lifecycleActive = true;
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(
            NativeSpeechDriverResult(
              transcript: result.recognizedWords,
              isFinal: result.finalResult,
            ),
          );
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          partialResults: false,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
    } on Object {
      _lifecycleActive = false;
      rethrow;
    }
  }

  @override
  Future<void> stop() => _endLifecycle(_speech.stop);

  @override
  Future<void> cancel() => _endLifecycle(_speech.cancel);

  void _handleRawError(SpeechRecognitionError error) {
    _lifecycleDrain?.observeRawCallback(isDone: false);
    _onError?.call(
      NativeSpeechDriverError(code: error.errorMsg, permanent: error.permanent),
    );
  }

  void _handleRawStatus(String status) {
    final mapped = _mapStatus(status);
    if (mapped == NativeSpeechDriverStatus.done) {
      final existingDrain = _lifecycleDrain;
      _lifecycleActive = false;
      final drain = existingDrain ?? _ensureLifecycleDrain();
      if (existingDrain == null) {
        drain.markEndSucceeded();
      }
      drain.observeRawCallback(isDone: true);
    } else {
      // Even statuses unknown to this adapter are part of the serialized raw
      // callback stream and extend an in-progress quiet drain.
      _lifecycleDrain?.observeRawCallback(isDone: false);
    }
    if (mapped == null) {
      return;
    }
    _onStatus?.call(mapped);
  }

  Future<void> _endLifecycle(Future<void> Function() end) async {
    final priorDrain = _lifecycleDrain;
    if (priorDrain != null) {
      if (priorDrain.tryBeginFailedEndRetry()) {
        await _runEndAndDrain(end, priorDrain);
      } else {
        await _awaitLifecycleDrain(priorDrain);
      }
      return;
    }

    if (!_lifecycleActive) {
      await end();
      await _awaitPriorLifecycleDrain();
      return;
    }

    final drain = _ensureLifecycleDrain();
    await _runEndAndDrain(end, drain);
  }

  Future<void> _runEndAndDrain(
    Future<void> Function() end,
    _SpeechLifecycleDrain drain,
  ) async {
    try {
      await end();
    } on Object {
      // The end operation itself settled, but native terminal callbacks can
      // still arrive afterward. Preserve the drain/tombstone so a retry cannot
      // bind a new mutable forwarding slot ahead of those callbacks.
      drain.markEndFailed();
      rethrow;
    }
    drain.markEndSucceeded();
    await _awaitLifecycleDrain(drain);
  }

  _SpeechLifecycleDrain _ensureLifecycleDrain() {
    return _lifecycleDrain ??= _SpeechLifecycleDrain();
  }

  Future<void> _awaitPriorLifecycleDrain() async {
    final drain = _lifecycleDrain;
    if (drain != null) {
      await _awaitLifecycleDrain(drain);
    }
  }

  Future<void> _awaitLifecycleDrain(_SpeechLifecycleDrain drain) async {
    try {
      await drain.done.timeout(_lifecycleDrainTimeout);
    } on TimeoutException {
      // "2턴 침묵 = 드레인 완료" 휴리스틱이 실기기에서 얼마나 어긋나는지
      // 관측하기 위한 로그. 특정 기종에서 빈발하면 타임아웃 조정의 근거가 된다.
      debugPrint(
        'speech lifecycle drain timed out after $_lifecycleDrainTimeout',
      );
      rethrow;
    }
    if (identical(_lifecycleDrain, drain)) {
      _lifecycleDrain = null;
    }
  }

  static NativeSpeechDriverStatus? _mapStatus(String status) {
    return switch (status) {
      SpeechToText.listeningStatus => NativeSpeechDriverStatus.listening,
      SpeechToText.notListeningStatus => NativeSpeechDriverStatus.notListening,
      SpeechToText.doneStatus => NativeSpeechDriverStatus.done,
      'unavailable' => NativeSpeechDriverStatus.unavailable,
      _ => null,
    };
  }
}

final class _NativeSpeechDriverLease {
  _NativeSpeechDriverLease({required this.onRevoked});

  final VoidCallback onRevoked;
  bool initialized = false;
}

/// Serializes access and tracks ownership at the shared driver boundary.
///
/// `SpeechToText` is process-global, so adapter-local queues cannot protect a
/// new screen from an old screen's cancel. Each driver identity gets one
/// coordinator: ownership handoff retires the old callbacks, drains cancel,
/// then lets the new session bind callbacks and listen.
final class _NativeSpeechDriverCoordinator {
  Future<void> _queue = Future<void>.value();
  _NativeSpeechDriverLease? _owner;

  bool owns(_NativeSpeechDriverLease lease) => identical(_owner, lease);

  Future<void> startSession({
    required NativeSpeechRecognitionDriver driver,
    required _NativeSpeechDriverLease lease,
    required bool Function() isCurrent,
    required Future<void> Function() start,
    required void Function(Object error) onHandoffFailure,
  }) {
    return _enqueue(() async {
      if (!isCurrent()) {
        return;
      }

      final previousOwner = _owner;
      if (previousOwner != null && !identical(previousOwner, lease)) {
        previousOwner.onRevoked();
        if (previousOwner.initialized) {
          try {
            await driver.cancel();
          } on Object catch (error) {
            if (isCurrent()) {
              onHandoffFailure(error);
            }
            return;
          }
        }
        _owner = null;
      }

      if (!isCurrent()) {
        return;
      }
      _owner = lease;
      await start();
    });
  }

  Future<void> endSession({
    required NativeSpeechRecognitionDriver driver,
    required _NativeSpeechDriverLease lease,
    required bool cancelDriver,
  }) {
    return _enqueue(() async {
      // A stale screen must never cancel the driver after a newer screen has
      // acquired it.
      if (!identical(_owner, lease)) {
        return;
      }
      if (cancelDriver && lease.initialized) {
        await driver.cancel();
      }
      _owner = null;
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

/// Native Korean speech recognizer for an active cooking screen.
///
/// A start request owns a generation. Stop/cancel and subsequent starts
/// invalidate older generations, so late method-channel callbacks cannot reach
/// a screen that already left its listening lifecycle.
final class NativeSpeechInput implements SpeechInputPort {
  NativeSpeechInput({
    NativeSpeechRecognitionDriver? driver,
    this.localeId = 'ko_KR',
  }) : _driver = driver ?? SpeechToTextRecognitionDriver() {
    _driverCoordinator = _driverCoordinators[_driver] ??=
        _NativeSpeechDriverCoordinator();
  }

  static final Expando<_NativeSpeechDriverCoordinator> _driverCoordinators =
      Expando<_NativeSpeechDriverCoordinator>('native speech driver');

  final NativeSpeechRecognitionDriver _driver;
  final String localeId;
  late final _NativeSpeechDriverCoordinator _driverCoordinator;

  int _generation = 0;
  int _utteranceSequence = 0;
  bool _sessionOpen = false;
  bool _startPending = false;
  bool _listening = false;
  bool _readyDelivered = false;
  bool _finalDelivered = false;
  SpeechUtteranceHandler? _onUtterance;
  SpeechInputFailureHandler? _onFailure;
  SpeechInputReadyHandler? _onReady;
  _NativeSpeechDriverLease? _session;

  @override
  void start({
    required SpeechInputReadyHandler onReady,
    required SpeechUtteranceHandler onUtterance,
    required SpeechInputFailureHandler onFailure,
  }) {
    if (_sessionOpen || _startPending || _listening) {
      return;
    }

    final generation = ++_generation;
    _sessionOpen = true;
    _startPending = true;
    _readyDelivered = false;
    _finalDelivered = false;
    _onReady = onReady;
    _onUtterance = onUtterance;
    _onFailure = onFailure;

    late final _NativeSpeechDriverLease session;
    session = _NativeSpeechDriverLease(
      onRevoked: () => _revokeSession(generation, session),
    );
    _session = session;

    unawaited(
      _driverCoordinator.startSession(
        driver: _driver,
        lease: session,
        isCurrent: () => _isLocallyCurrent(generation, session),
        start: () => _startRecognition(generation, session),
        onHandoffFailure: (error) {
          _reportHandoffFailure(
            generation,
            session,
            _classifyThrownError(error),
          );
        },
      ),
    );
  }

  Future<void> _startRecognition(
    int generation,
    _NativeSpeechDriverLease session,
  ) async {
    if (!_isCurrent(generation, session)) {
      return;
    }

    final bool available;
    try {
      // Rebind on every recognition session. The production driver forwards
      // the process-global plugin callbacks to these generation-scoped
      // handlers even when SpeechToText.initialize returns early.
      available = await _driver.initialize(
        onError: (error) => _handleDriverError(generation, session, error),
        onStatus: (status) => _handleDriverStatus(generation, session, status),
      );
    } on Object catch (error) {
      _reportFailure(
        generation,
        session,
        _classifyThrownError(error, duringInitialization: true),
        cancelDriver: false,
      );
      return;
    }
    if (!_isCurrent(generation, session)) {
      return;
    }
    if (!available) {
      final permissionGranted = await _readPermission();
      if (!_isCurrent(generation, session)) {
        return;
      }
      _reportFailure(
        generation,
        session,
        permissionGranted
            ? SpeechInputFailure.unavailable
            : SpeechInputFailure.permissionDenied,
        cancelDriver: false,
      );
      return;
    }
    session.initialized = true;

    try {
      await _driver.listen(
        localeId: localeId,
        onResult: (result) => _handleResult(generation, session, result),
      );
    } on Object catch (error) {
      _reportFailure(generation, session, _classifyThrownError(error));
      return;
    }
    if (!_isCurrent(generation, session)) {
      return;
    }

    // The plugin normally reports `listening` before this future completes.
    // Some platform recognizers only complete the call, so this is the
    // readiness fallback and is guarded against duplicate delivery.
    _deliverReady(generation, session);
  }

  Future<bool> _readPermission() async {
    try {
      return await _driver.hasPermission;
    } on Object {
      // 권한 확인 자체가 실패하면 보수적으로 "권한 없음"으로 본다. 반대로
      // 기울이면 unavailable("기기 미지원")로 보고되어, 권한만 허용하면 되는
      // 사용자에게 복구 경로 없는 안내가 나간다.
      return false;
    }
  }

  void _handleResult(
    int generation,
    _NativeSpeechDriverLease session,
    NativeSpeechDriverResult result,
  ) {
    if (!_isCurrent(generation, session) ||
        !result.isFinal ||
        _finalDelivered) {
      return;
    }
    final transcript = result.transcript.trim();
    if (transcript.isEmpty) {
      return;
    }

    _finalDelivered = true;
    final utteranceId = 'native-stt-$generation-${++_utteranceSequence}';
    _onUtterance?.call(transcript, utteranceId);
  }

  void _handleDriverError(
    int generation,
    _NativeSpeechDriverLease session,
    NativeSpeechDriverError error,
  ) {
    if (!_isCurrent(generation, session)) {
      return;
    }
    _reportFailure(generation, session, _classifyDriverError(error));
  }

  void _handleDriverStatus(
    int generation,
    _NativeSpeechDriverLease session,
    NativeSpeechDriverStatus status,
  ) {
    if (!_isCurrent(generation, session)) {
      return;
    }
    switch (status) {
      case NativeSpeechDriverStatus.listening:
        _deliverReady(generation, session);
      case NativeSpeechDriverStatus.notListening:
        _listening = false;
      case NativeSpeechDriverStatus.done:
        final deliveredFinal = _finalDelivered;
        final onFailure = _onFailure;
        _invalidateCurrentSession();
        unawaited(
          _driverCoordinator.endSession(
            driver: _driver,
            lease: session,
            cancelDriver: false,
          ),
        );
        if (!deliveredFinal) {
          onFailure?.call(SpeechInputFailure.retryRequired);
        }
      case NativeSpeechDriverStatus.unavailable:
        _reportFailure(generation, session, SpeechInputFailure.unavailable);
    }
  }

  void _deliverReady(int generation, _NativeSpeechDriverLease session) {
    if (!_isCurrent(generation, session) || _readyDelivered) {
      return;
    }
    _readyDelivered = true;
    _startPending = false;
    _listening = true;
    _onReady?.call();
  }

  void _reportFailure(
    int generation,
    _NativeSpeechDriverLease session,
    SpeechInputFailure failure, {
    bool cancelDriver = true,
  }) {
    if (!_isCurrent(generation, session)) {
      return;
    }
    final onFailure = _onFailure;
    _invalidateCurrentSession();
    unawaited(
      _driverCoordinator.endSession(
        driver: _driver,
        lease: session,
        cancelDriver: cancelDriver,
      ),
    );
    onFailure?.call(failure);
  }

  void _reportHandoffFailure(
    int generation,
    _NativeSpeechDriverLease session,
    SpeechInputFailure failure,
  ) {
    if (!_isLocallyCurrent(generation, session)) {
      return;
    }
    final onFailure = _onFailure;
    _invalidateCurrentSession();
    onFailure?.call(failure);
  }

  @override
  Future<void> stop() => _endRecognition();

  /// Cancels recognition without asking the platform for a final transcript.
  Future<void> cancel() => _endRecognition();

  Future<void> _endRecognition() {
    final session = _session;
    final shouldEndDriver = session != null && _sessionOpen;
    _invalidateCurrentSession();
    if (!shouldEndDriver) {
      return Future<void>.value();
    }
    return _driverCoordinator.endSession(
      driver: _driver,
      lease: session,
      cancelDriver: true,
    );
  }

  void _revokeSession(int generation, _NativeSpeechDriverLease session) {
    if (_isLocallyCurrent(generation, session)) {
      _invalidateCurrentSession();
    }
  }

  void _invalidateCurrentSession() {
    _generation += 1;
    _sessionOpen = false;
    _startPending = false;
    _listening = false;
    _readyDelivered = false;
    _finalDelivered = false;
    _onReady = null;
    _onUtterance = null;
    _onFailure = null;
    _session = null;
  }

  bool _isLocallyCurrent(int generation, _NativeSpeechDriverLease session) =>
      _sessionOpen && generation == _generation && identical(_session, session);

  bool _isCurrent(int generation, _NativeSpeechDriverLease session) =>
      _isLocallyCurrent(generation, session) &&
      _driverCoordinator.owns(session);

  static SpeechInputFailure _classifyDriverError(
    NativeSpeechDriverError error,
  ) {
    final code = error.code.toLowerCase();
    if (_looksLikePermissionError(code)) {
      return SpeechInputFailure.permissionDenied;
    }
    // 재시도 단서와 사용 불가 단서가 한 문자열에 섞이면 재시도를 우선한다.
    // 오분류 비용이 비대칭이다 — 재시도는 한 번 더 시도할 뿐이지만,
    // unavailable은 세션 내내 핸즈프리를 영구 해제한다.
    if (_looksRetryable(code)) {
      return SpeechInputFailure.retryRequired;
    }
    if (_looksUnavailable(code)) {
      return SpeechInputFailure.unavailable;
    }
    // OEM별 오류 문자열 분포를 베타에서 수집하기 위한 로그.
    debugPrint('unclassified speech error code: ${error.code}');
    return error.permanent
        ? SpeechInputFailure.unavailable
        : SpeechInputFailure.retryRequired;
  }

  static SpeechInputFailure _classifyThrownError(
    Object error, {
    bool duringInitialization = false,
  }) {
    final message = switch (error) {
      ListenFailedException(:final message, :final details) =>
        '${message ?? ''} ${details ?? ''}'.toLowerCase(),
      _ => error.toString().toLowerCase(),
    };
    if (_looksLikePermissionError(message)) {
      return SpeechInputFailure.permissionDenied;
    }
    if (duringInitialization || _looksUnavailable(message)) {
      return SpeechInputFailure.unavailable;
    }
    return SpeechInputFailure.retryRequired;
  }

  static bool _looksLikePermissionError(String value) =>
      value.contains('permission') ||
      value.contains('not_authorized') ||
      value.contains('not authorized') ||
      value.contains('not_allowed') ||
      value.contains('not allowed');

  static bool _looksUnavailable(String value) =>
      value.contains('language_not_supported') ||
      value.contains('language_unavailable') ||
      value.contains('recognizer_disabled') ||
      value.contains('recognizer_not_available') ||
      value.contains('failed to create speech recognizer') ||
      value.contains('assets_not_installed') ||
      value.contains('speech_not_supported') ||
      value.contains('not supported') ||
      value.contains('not_initialized') ||
      value.contains('listen_failed') ||
      value.contains('missingplugin');

  static bool _looksRetryable(String value) =>
      value.contains('retry') ||
      value.contains('no_match') ||
      value.contains('speech_timeout') ||
      value.contains('network') ||
      value.contains('busy') ||
      value.contains('server') ||
      value.contains('audio_error') ||
      value.contains('error_client') ||
      value.contains('request_cancelled') ||
      value.contains('already_active') ||
      value.contains('connection_') ||
      value.contains('too_many_requests');
}
