abstract interface class MonotonicClock {
  Duration get elapsed;
  bool get isRunning;

  void reset();
  void start();
  void stop();
}

final class StopwatchMonotonicClock implements MonotonicClock {
  StopwatchMonotonicClock() : _stopwatch = Stopwatch();

  final Stopwatch _stopwatch;

  @override
  Duration get elapsed => _stopwatch.elapsed;

  @override
  bool get isRunning => _stopwatch.isRunning;

  @override
  void reset() => _stopwatch.reset();

  @override
  void start() => _stopwatch.start();

  @override
  void stop() => _stopwatch.stop();
}

/// 화면이 꺼지거나 앱이 백그라운드로 내려가 프로세스가 동결되면
/// [Stopwatch]가 쓰는 단조 시계(Android `CLOCK_MONOTONIC`, iOS
/// `mach_absolute_time`)는 진행을 멈춘다. 그 결과 화면을 다시 켰을 때 잠들어
/// 있던 시간이 반영되지 않아 타이머가 실제보다 느리게 간다.
///
/// 이 구현은 벽시계([DateTime])를 함께 앵커로 두어 잠든 시간을 복원한다.
/// 매 순간 경과값은 단조 시계와 벽시계 중 **큰 값**을 취한다.
///   - 딥슬립 동안에는 단조 시계가 멈추므로 벽시계가 실제 경과를 채운다.
///   - 사용자가 시스템 시각을 과거로 되돌리면 벽시계가 줄지만 단조 시계는
///     절대 뒤로 가지 않으므로 하한을 지킨다.
final class WallAnchoredMonotonicClock implements MonotonicClock {
  WallAnchoredMonotonicClock({DateTime Function()? wallClock})
    : _wallClock = wallClock ?? DateTime.now;

  final DateTime Function() _wallClock;
  final Stopwatch _stopwatch = Stopwatch();

  /// 정지된 이전 구간들에서 누적된 벽시계 경과.
  Duration _wallAccumulated = Duration.zero;

  /// 현재 실행 구간이 시작된 벽시계 시각(정지 상태면 null).
  DateTime? _segmentStart;

  @override
  bool get isRunning => _stopwatch.isRunning;

  @override
  Duration get elapsed {
    final monotonic = _stopwatch.elapsed;
    final wall = _wallElapsed();
    return wall > monotonic ? wall : monotonic;
  }

  Duration _wallElapsed() {
    final start = _segmentStart;
    if (start == null) {
      return _wallAccumulated;
    }
    final delta = _wallClock().difference(start);
    return _wallAccumulated + (delta.isNegative ? Duration.zero : delta);
  }

  @override
  void start() {
    if (_stopwatch.isRunning) {
      return;
    }
    _stopwatch.start();
    _segmentStart = _wallClock();
  }

  @override
  void stop() {
    if (!_stopwatch.isRunning) {
      return;
    }
    _wallAccumulated = _wallElapsed();
    _segmentStart = null;
    _stopwatch.stop();
  }

  @override
  void reset() {
    _stopwatch.reset();
    _wallAccumulated = Duration.zero;
    _segmentStart = _stopwatch.isRunning ? _wallClock() : null;
  }
}
