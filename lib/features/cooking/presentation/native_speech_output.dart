import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../application/cooking_ports.dart';

/// Minimal native synthesizer boundary kept separate from the cooking port.
///
/// Tests can inject a deterministic engine without registering a method
/// channel, while production delegates to [FlutterTts].
abstract interface class SpeechSynthesisEngine {
  /// Configures [speak] to complete after audible playback completes.
  Future<void> configure();

  Future<void> speak(String text);

  Future<void> stop();
}

final class FlutterTtsSpeechSynthesisEngine implements SpeechSynthesisEngine {
  FlutterTtsSpeechSynthesisEngine({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;

  @override
  Future<void> configure() async {
    // The cooking port promises playback completion rather than merely method
    // channel submission. Korean is preferred, while the platform remains free
    // to fall back to its installed default voice.
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setLanguage('ko-KR');
    await _flutterTts.setSpeechRate(0.48);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
  }

  @override
  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}

/// Race-safe native implementation of cooking speech output.
///
/// Stop/configure/start transitions are serialized independently from audible
/// playback. This lets a newer utterance stop one that is still speaking while
/// preventing an older, slower stop from cancelling the newer utterance.
final class NativeSpeechOutput implements SpeechOutputPort {
  NativeSpeechOutput({
    SpeechSynthesisEngine? engine,
    this.configurationTimeout = const Duration(seconds: 5),
    this.stopTimeout = const Duration(seconds: 3),
    Duration Function(String text)? playbackTimeoutFor,
  }) : assert(configurationTimeout > Duration.zero),
       assert(stopTimeout > Duration.zero),
       _engine = engine ?? FlutterTtsSpeechSynthesisEngine(),
       _playbackTimeoutFor = playbackTimeoutFor ?? _defaultPlaybackTimeoutFor;

  final SpeechSynthesisEngine _engine;
  final Duration configurationTimeout;
  final Duration stopTimeout;
  final Duration Function(String text) _playbackTimeoutFor;

  Future<void> _controlTail = Future<void>.value();
  int _requestVersion = 0;
  bool _configured = false;
  bool _disposed = false;

  @override
  Future<void> speak(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty || _disposed) {
      return;
    }

    final requestVersion = ++_requestVersion;
    Future<void>? playback;
    await _enqueueControl(() async {
      // QUEUE_FLUSH behavior is made explicit and cross-platform: every new
      // utterance first drains the previous native playback.
      await _stopEngineBestEffort();
      if (!_owns(requestVersion)) {
        return;
      }
      if (!await _configureBestEffort() || !_owns(requestVersion)) {
        return;
      }
      try {
        // Do not await here. Holding the control queue for the full audible
        // duration would prevent the next request from reaching stop().
        playback = _engine.speak(normalized);
      } on Object {
        playback = null;
      }
    });

    final currentPlayback = playback;
    if (currentPlayback == null) {
      return;
    }
    try {
      await currentPlayback.timeout(_playbackTimeoutFor(normalized));
    } on TimeoutException {
      // Some OEM engines fail to emit completion. Stop only if this utterance
      // still owns output; an older timeout must never cancel newer speech.
      await _enqueueControl(() async {
        if (_owns(requestVersion)) {
          await _stopEngineBestEffort();
        }
      });
    } on Object {
      // Missing voices, unavailable engines, and platform-channel failures
      // must not break cooking controls or AI answer rendering.
    }
  }

  @override
  Future<void> stop() async {
    _requestVersion++;
    await _enqueueControl(_stopEngineBestEffort);
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _requestVersion++;
    unawaited(_enqueueControl(_stopEngineBestEffort));
  }

  bool _owns(int requestVersion) =>
      !_disposed && requestVersion == _requestVersion;

  Future<bool> _configureBestEffort() async {
    if (_configured) {
      return true;
    }
    try {
      await _engine.configure().timeout(configurationTimeout);
      _configured = true;
      return true;
    } on Object {
      // Retry on a later utterance: engine initialization failures can be
      // transient after lifecycle or audio-session changes.
      return false;
    }
  }

  Future<void> _stopEngineBestEffort() async {
    try {
      await _engine.stop().timeout(stopTimeout);
    } on Object {
      // Best effort by design. A broken TTS engine cannot own the UI flow.
    }
  }

  Future<void> _enqueueControl(Future<void> Function() operation) {
    final previous = _controlTail;
    final current = (() async {
      try {
        await previous;
      } on Object {
        // A prior control failure must not poison the serialization queue.
      }
      await operation();
    })();
    _controlTail = current.then<void>((_) {}, onError: (_) {});
    return current;
  }

  static Duration _defaultPlaybackTimeoutFor(String text) {
    final estimatedSeconds = 6 + (text.length / 4).ceil();
    return Duration(seconds: estimatedSeconds.clamp(8, 60));
  }
}
