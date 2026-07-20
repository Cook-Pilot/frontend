import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/cooking_session_state.dart';
import 'monotonic_clock.dart';

@immutable
final class StepTimerSnapshot {
  const StepTimerSnapshot({
    required this.originalDuration,
    required this.effectiveDuration,
    required this.remaining,
    required this.status,
  });

  final Duration originalDuration;
  final Duration effectiveDuration;
  final Duration remaining;
  final TimerStatus status;
}

final class LocalTimerController extends ChangeNotifier {
  LocalTimerController({MonotonicClock? clock, this.autoTick = true})
    : _clock = clock ?? StopwatchMonotonicClock();

  final MonotonicClock _clock;
  final bool autoTick;

  Timer? _ticker;
  Duration _originalDuration = Duration.zero;
  Duration _effectiveDuration = Duration.zero;
  Duration _remainingAtAnchor = Duration.zero;
  TimerStatus _status = TimerStatus.idle;

  Duration get originalDuration => _originalDuration;
  Duration get effectiveDuration => _effectiveDuration;
  TimerStatus get status => _status;

  Duration get remaining {
    if (_status != TimerStatus.running) {
      return _remainingAtAnchor;
    }
    final value = _remainingAtAnchor - _clock.elapsed;
    return value.isNegative ? Duration.zero : value;
  }

  double get progress {
    if (_effectiveDuration == Duration.zero) {
      return _status == TimerStatus.elapsed ? 1 : 0;
    }
    final elapsed = _effectiveDuration - remaining;
    return (elapsed.inMilliseconds / _effectiveDuration.inMilliseconds)
        .clamp(0, 1)
        .toDouble();
  }

  void reset(Duration duration, {bool autoStart = true}) {
    _cancelTicker();
    _clock
      ..stop()
      ..reset();
    _originalDuration = duration;
    _effectiveDuration = duration;
    _remainingAtAnchor = duration;
    _status = TimerStatus.idle;

    if (autoStart && duration > Duration.zero) {
      start();
      return;
    }
    notifyListeners();
  }

  void start() {
    if (_status == TimerStatus.running) {
      return;
    }
    if (_remainingAtAnchor <= Duration.zero) {
      _status = _effectiveDuration > Duration.zero
          ? TimerStatus.elapsed
          : TimerStatus.idle;
      notifyListeners();
      return;
    }
    _clock
      ..stop()
      ..reset()
      ..start();
    _status = TimerStatus.running;
    _ensureTicker();
    notifyListeners();
  }

  void pause() {
    if (_status != TimerStatus.running) {
      return;
    }
    _remainingAtAnchor = remaining;
    _clock
      ..stop()
      ..reset();
    _status = _remainingAtAnchor == Duration.zero
        ? TimerStatus.elapsed
        : TimerStatus.paused;
    _cancelTicker();
    notifyListeners();
  }

  void resume() {
    if (_status != TimerStatus.paused) {
      return;
    }
    start();
  }

  void add(Duration extension) {
    if (extension <= Duration.zero) {
      return;
    }
    final wasRunning = _status == TimerStatus.running;
    final currentRemaining = remaining;
    _effectiveDuration += extension;
    _remainingAtAnchor = currentRemaining + extension;
    _clock
      ..stop()
      ..reset();

    if (wasRunning ||
        _status == TimerStatus.idle ||
        _status == TimerStatus.elapsed) {
      _clock.start();
      _status = TimerStatus.running;
      _ensureTicker();
    }
    notifyListeners();
  }

  void sync() {
    if (_status != TimerStatus.running) {
      return;
    }
    if (remaining == Duration.zero) {
      _remainingAtAnchor = Duration.zero;
      _clock
        ..stop()
        ..reset();
      _status = TimerStatus.elapsed;
      _cancelTicker();
    }
    notifyListeners();
  }

  StepTimerSnapshot snapshot() {
    return StepTimerSnapshot(
      originalDuration: _originalDuration,
      effectiveDuration: _effectiveDuration,
      remaining: remaining,
      status: _status,
    );
  }

  void restore(StepTimerSnapshot snapshot) {
    _cancelTicker();
    _clock
      ..stop()
      ..reset();
    _originalDuration = snapshot.originalDuration.isNegative
        ? Duration.zero
        : snapshot.originalDuration;
    final nonNegativeEffective = snapshot.effectiveDuration.isNegative
        ? Duration.zero
        : snapshot.effectiveDuration;
    _effectiveDuration = nonNegativeEffective < _originalDuration
        ? _originalDuration
        : nonNegativeEffective;
    final nonNegativeRemaining = snapshot.remaining.isNegative
        ? Duration.zero
        : snapshot.remaining;
    _remainingAtAnchor = nonNegativeRemaining > _effectiveDuration
        ? _effectiveDuration
        : nonNegativeRemaining;
    if (_effectiveDuration == Duration.zero) {
      _status = TimerStatus.idle;
    } else if (_remainingAtAnchor == Duration.zero) {
      _status = TimerStatus.elapsed;
    } else if (snapshot.status == TimerStatus.elapsed) {
      _status = TimerStatus.paused;
    } else {
      _status = snapshot.status;
    }

    if (_status == TimerStatus.running) {
      _clock.start();
      _ensureTicker();
    }
    notifyListeners();
  }

  void _ensureTicker() {
    if (!autoTick || _ticker != null) {
      return;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => sync());
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _cancelTicker();
    _clock.stop();
    super.dispose();
  }
}
