import 'dart:async';

import 'package:cookpilot/features/cooking/presentation/native_speech_output.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'configures Korean native TTS once and stops before every utterance',
    () async {
      final engine = _FakeSpeechSynthesisEngine(autoCompletePlayback: true);
      final output = NativeSpeechOutput(engine: engine);

      await output.speak('  첫 단계 안내  ');
      await output.speak('두 번째 안내');

      expect(engine.configureCount, 1);
      expect(engine.spoken, <String>['첫 단계 안내', '두 번째 안내']);
      expect(engine.events, <String>[
        'stop',
        'configure',
        'speak:첫 단계 안내',
        'stop',
        'speak:두 번째 안내',
      ]);
    },
  );

  test('a newer utterance cancels audible playback before it starts', () async {
    final engine = _FakeSpeechSynthesisEngine();
    final output = NativeSpeechOutput(engine: engine);

    final first = output.speak('이전 안내');
    await engine.waitForSpeakCount(1);
    expect(engine.pendingPlaybacks.single.isCompleted, isFalse);

    final second = output.speak('최신 안내');
    await engine.waitForSpeakCount(2);

    await first;
    expect(engine.pendingPlaybacks.first.isCompleted, isTrue);
    expect(engine.events, <String>[
      'stop',
      'configure',
      'speak:이전 안내',
      'stop',
      'speak:최신 안내',
    ]);

    engine.completeLatestPlayback();
    await second;
  });

  test('a superseded request waiting on stop never reaches speak', () async {
    final firstStop = Completer<void>();
    final engine = _FakeSpeechSynthesisEngine()..nextStopGate = firstStop;
    final output = NativeSpeechOutput(engine: engine);

    final first = output.speak('낡은 안내');
    await engine.waitForStopCount(1);
    final latest = output.speak('최신 안내');

    expect(engine.spoken, isEmpty);
    firstStop.complete();
    await first;
    await engine.waitForSpeakCount(1);

    expect(engine.spoken, <String>['최신 안내']);
    engine.completeLatestPlayback();
    await latest;
  });

  test(
    'configuration and platform failures do not escape to the cooking UI',
    () async {
      final engine = _FakeSpeechSynthesisEngine()
        ..configureError = StateError('engine');
      final output = NativeSpeechOutput(engine: engine);

      await expectLater(output.speak('첫 시도'), completes);
      expect(engine.spoken, isEmpty);

      engine.configureError = null;
      engine.speakError = StateError('voice missing');
      await expectLater(output.speak('두 번째 시도'), completes);

      expect(engine.configureCount, 2);
      expect(engine.spoken, <String>['두 번째 시도']);
    },
  );

  test(
    'dispose itself cancels playback and rejects all future speech',
    () async {
      final engine = _FakeSpeechSynthesisEngine();
      final output = NativeSpeechOutput(engine: engine);

      final playback = output.speak('종료할 안내');
      await engine.waitForSpeakCount(1);
      output.dispose();
      await playback;
      await output.speak('폐기 뒤 안내');
      await Future<void>.delayed(Duration.zero);

      expect(engine.spoken, <String>['종료할 안내']);
      expect(engine.stopCount, 2);
    },
  );

  test('an old playback timeout cannot stop a newer utterance', () async {
    final engine = _FakeSpeechSynthesisEngine(completePlaybackOnStop: false);
    final output = NativeSpeechOutput(
      engine: engine,
      playbackTimeoutFor: (text) => text.startsWith('완료')
          ? const Duration(milliseconds: 40)
          : const Duration(seconds: 5),
    );

    final first = output.speak('완료 콜백이 없는 안내');
    await engine.waitForSpeakCount(1);
    final latest = output.speak('계속 재생할 최신 안내');
    await engine.waitForSpeakCount(2);
    final stopCountAfterLatestStarted = engine.stopCount;

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(engine.stopCount, stopCountAfterLatestStarted);

    engine.completeAllPlaybacks();
    await first;
    await latest;
  });
}

final class _FakeSpeechSynthesisEngine implements SpeechSynthesisEngine {
  _FakeSpeechSynthesisEngine({
    this.autoCompletePlayback = false,
    this.completePlaybackOnStop = true,
  });

  final bool autoCompletePlayback;
  final bool completePlaybackOnStop;
  final List<String> events = <String>[];
  final List<String> spoken = <String>[];
  final List<Completer<void>> pendingPlaybacks = <Completer<void>>[];
  final List<Completer<void>> _speakCountWaiters = <Completer<void>>[];
  final List<Completer<void>> _stopCountWaiters = <Completer<void>>[];
  int configureCount = 0;
  int stopCount = 0;
  Object? configureError;
  Object? speakError;
  Object? stopError;
  Completer<void>? nextStopGate;

  @override
  Future<void> configure() async {
    configureCount += 1;
    events.add('configure');
    final error = configureError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    events.add('speak:$text');
    final playback = Completer<void>();
    pendingPlaybacks.add(playback);
    _notifyWaiters(_speakCountWaiters);
    final error = speakError;
    if (error != null) {
      return Future<void>.error(error);
    }
    if (autoCompletePlayback) {
      playback.complete();
    }
    return playback.future;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    events.add('stop');
    _notifyWaiters(_stopCountWaiters);
    final gate = nextStopGate;
    nextStopGate = null;
    if (gate != null) {
      await gate.future;
    }
    if (completePlaybackOnStop) {
      completeAllPlaybacks();
    }
    final error = stopError;
    if (error != null) {
      throw error;
    }
  }

  Future<void> waitForSpeakCount(int count) =>
      _waitForCount(() => spoken.length, count, _speakCountWaiters);

  Future<void> waitForStopCount(int count) =>
      _waitForCount(() => stopCount, count, _stopCountWaiters);

  void completeLatestPlayback() {
    final playback = pendingPlaybacks.last;
    if (!playback.isCompleted) {
      playback.complete();
    }
  }

  void completeAllPlaybacks() {
    for (final playback in pendingPlaybacks) {
      if (!playback.isCompleted) {
        playback.complete();
      }
    }
  }

  Future<void> _waitForCount(
    int Function() current,
    int expected,
    List<Completer<void>> waiters,
  ) async {
    while (current() < expected) {
      final waiter = Completer<void>();
      waiters.add(waiter);
      await waiter.future;
    }
  }

  void _notifyWaiters(List<Completer<void>> waiters) {
    final pending = List<Completer<void>>.of(waiters);
    waiters.clear();
    for (final waiter in pending) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
  }
}
