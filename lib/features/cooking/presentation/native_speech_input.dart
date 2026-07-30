import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// Production driver backed by the device speech recognizer.
final class SpeechToTextRecognitionDriver
    implements NativeSpeechRecognitionDriver {
  factory SpeechToTextRecognitionDriver({SpeechToText? speech}) {
    if (speech != null) {
      return SpeechToTextRecognitionDriver._(speech);
    }
    return _shared;
  }

  SpeechToTextRecognitionDriver._(this._speech);

  static final SpeechToTextRecognitionDriver _shared =
      SpeechToTextRecognitionDriver._(SpeechToText());

  final SpeechToText _speech;
  NativeSpeechDriverErrorHandler? _onError;
  NativeSpeechDriverStatusHandler? _onStatus;

  @override
  Future<bool> get hasPermission => _speech.hasPermission;

  @override
  Future<bool> initialize({
    required NativeSpeechDriverErrorHandler onError,
    required NativeSpeechDriverStatusHandler onStatus,
  }) {
    // SpeechToText() is a process singleton. Once initialization succeeds it
    // returns early on later initialize calls without replacing its listeners.
    // Keep one shared driver and let the listener installed by the first call
    // forward to the handlers owned by the current cooking screen.
    _onError = onError;
    _onStatus = onStatus;
    return _speech.initialize(
      onError: (error) {
        _onError?.call(
          NativeSpeechDriverError(
            code: error.errorMsg,
            permanent: error.permanent,
          ),
        );
      },
      onStatus: (status) {
        final mapped = _mapStatus(status);
        if (mapped != null) {
          _onStatus?.call(mapped);
        }
      },
    );
  }

  @override
  Future<void> listen({
    required String localeId,
    required NativeSpeechDriverResultHandler onResult,
  }) async {
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
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();

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

/// Native Korean speech recognizer for an active cooking screen.
///
/// A start request owns a generation. Stop/cancel and subsequent starts
/// invalidate older generations, so late method-channel callbacks cannot reach
/// a screen that already left its listening lifecycle.
final class NativeSpeechInput implements SpeechInputPort {
  NativeSpeechInput({
    NativeSpeechRecognitionDriver? driver,
    this.localeId = 'ko_KR',
  }) : _driver = driver ?? SpeechToTextRecognitionDriver();

  final NativeSpeechRecognitionDriver _driver;
  final String localeId;

  Future<void> _driverQueue = Future<void>.value();
  int _generation = 0;
  int _utteranceSequence = 0;
  bool _initialized = false;
  bool _sessionOpen = false;
  bool _startPending = false;
  bool _listening = false;
  bool _readyDelivered = false;
  bool _finalDelivered = false;
  SpeechUtteranceHandler? _onUtterance;
  SpeechInputFailureHandler? _onFailure;
  SpeechInputReadyHandler? _onReady;

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

    unawaited(_enqueueDriverOperation(() => _startRecognition(generation)));
  }

  Future<void> _startRecognition(int generation) async {
    if (!_isCurrent(generation)) {
      return;
    }

    if (!_initialized) {
      final bool available;
      try {
        available = await _driver.initialize(
          onError: _handleDriverError,
          onStatus: _handleDriverStatus,
        );
      } on Object catch (error) {
        _reportFailure(
          generation,
          _classifyThrownError(error, duringInitialization: true),
          resetInitialization: true,
          cancelDriver: false,
        );
        return;
      }
      if (!_isCurrent(generation)) {
        return;
      }
      if (!available) {
        final permissionGranted = await _readPermission();
        if (!_isCurrent(generation)) {
          return;
        }
        _reportFailure(
          generation,
          permissionGranted
              ? SpeechInputFailure.unavailable
              : SpeechInputFailure.permissionDenied,
          resetInitialization: true,
          cancelDriver: false,
        );
        return;
      }
      _initialized = true;
    }

    try {
      await _driver.listen(
        localeId: localeId,
        onResult: (result) => _handleResult(generation, result),
      );
    } on Object catch (error) {
      _reportFailure(
        generation,
        _classifyThrownError(error),
        resetInitialization: _looksUnavailable(error.toString()),
      );
      return;
    }
    if (!_isCurrent(generation)) {
      return;
    }

    // The plugin normally reports `listening` before this future completes.
    // Some platform recognizers only complete the call, so this is the
    // readiness fallback and is guarded against duplicate delivery.
    _deliverReady(generation);
  }

  Future<bool> _readPermission() async {
    try {
      return await _driver.hasPermission;
    } on Object {
      return true;
    }
  }

  void _handleResult(int generation, NativeSpeechDriverResult result) {
    if (!_isCurrent(generation) || !result.isFinal || _finalDelivered) {
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

  void _handleDriverError(NativeSpeechDriverError error) {
    if (!_sessionOpen) {
      return;
    }
    final failure = _classifyDriverError(error);
    _reportFailure(
      _generation,
      failure,
      resetInitialization:
          failure == SpeechInputFailure.permissionDenied ||
          failure == SpeechInputFailure.unavailable,
    );
  }

  void _handleDriverStatus(NativeSpeechDriverStatus status) {
    if (!_sessionOpen) {
      return;
    }
    final generation = _generation;
    switch (status) {
      case NativeSpeechDriverStatus.listening:
        _deliverReady(generation);
      case NativeSpeechDriverStatus.notListening:
        _listening = false;
      case NativeSpeechDriverStatus.done:
        final deliveredFinal = _finalDelivered;
        final onFailure = _onFailure;
        _invalidateCurrentSession();
        if (!deliveredFinal) {
          onFailure?.call(SpeechInputFailure.retryRequired);
        }
      case NativeSpeechDriverStatus.unavailable:
        _reportFailure(
          generation,
          SpeechInputFailure.unavailable,
          resetInitialization: true,
        );
    }
  }

  void _deliverReady(int generation) {
    if (!_isCurrent(generation) || _readyDelivered) {
      return;
    }
    _readyDelivered = true;
    _startPending = false;
    _listening = true;
    _onReady?.call();
  }

  void _reportFailure(
    int generation,
    SpeechInputFailure failure, {
    bool resetInitialization = false,
    bool cancelDriver = true,
  }) {
    if (!_isCurrent(generation)) {
      return;
    }
    final onFailure = _onFailure;
    final shouldCancelDriver = cancelDriver && _initialized;
    _invalidateCurrentSession();
    if (resetInitialization) {
      _initialized = false;
    }
    if (shouldCancelDriver) {
      unawaited(_enqueueDriverOperation(_driver.cancel));
    }
    onFailure?.call(failure);
  }

  @override
  Future<void> stop() => _endRecognition(cancel: true);

  /// Cancels recognition without asking the platform for a final transcript.
  Future<void> cancel() => _endRecognition(cancel: true);

  Future<void> _endRecognition({required bool cancel}) {
    final shouldEndDriver = _initialized && _sessionOpen;
    _invalidateCurrentSession();
    if (!shouldEndDriver) {
      return Future<void>.value();
    }
    return _enqueueDriverOperation(cancel ? _driver.cancel : _driver.stop);
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
  }

  bool _isCurrent(int generation) => _sessionOpen && generation == _generation;

  Future<void> _enqueueDriverOperation(Future<void> Function() operation) {
    final result = _driverQueue.then((_) => operation());
    _driverQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  static SpeechInputFailure _classifyDriverError(
    NativeSpeechDriverError error,
  ) {
    final code = error.code.toLowerCase();
    if (_looksLikePermissionError(code)) {
      return SpeechInputFailure.permissionDenied;
    }
    if (_looksUnavailable(code)) {
      return SpeechInputFailure.unavailable;
    }
    if (_looksRetryable(code)) {
      return SpeechInputFailure.retryRequired;
    }
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
