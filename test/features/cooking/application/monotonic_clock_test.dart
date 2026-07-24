import 'package:cookpilot/features/cooking/application/monotonic_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WallAnchoredMonotonicClock', () {
    late DateTime now;
    late WallAnchoredMonotonicClock clock;

    setUp(() {
      now = DateTime(2026, 1, 1, 12);
      clock = WallAnchoredMonotonicClock(wallClock: () => now);
    });

    test('실행 중에는 벽시계 경과를 반영한다(화면 off 동안 흐른 시간 포함)', () {
      clock.start();
      now = now.add(const Duration(seconds: 14));

      // 실제 Stopwatch는 거의 움직이지 않았지만 벽시계가 14초 흘렀으므로
      // 잠들어 있던 시간이 경과값에 반영된다.
      expect(clock.elapsed.inSeconds, 14);
    });

    test('정지 중에는 시간이 흐르지 않고 재개 후 이어진다', () {
      clock.start();
      now = now.add(const Duration(seconds: 20));
      clock.stop();
      now = now.add(const Duration(seconds: 30));

      expect(clock.elapsed.inSeconds, 20);

      clock.start();
      now = now.add(const Duration(seconds: 10));
      expect(clock.elapsed.inSeconds, 30);
    });

    test('reset은 누적을 0으로 되돌리고 실행 상태를 유지한다', () {
      clock.start();
      now = now.add(const Duration(seconds: 40));
      clock.reset();

      expect(clock.isRunning, isTrue);
      // 내부 Stopwatch가 실시간 마이크로초를 누적하므로 1초 미만이면 0으로 본다.
      expect(clock.elapsed, lessThan(const Duration(seconds: 1)));

      now = now.add(const Duration(seconds: 5));
      expect(clock.elapsed.inSeconds, 5);
    });

    test('실행 중 시스템 시각을 과거로 되돌려도 경과가 음수가 되지 않는다', () {
      clock.start();
      now = now.add(const Duration(seconds: 30));
      now = now.subtract(const Duration(seconds: 100));

      // 음수 델타는 0으로 클램프된다. (실제 단조 시계의 하한 보장은
      // 실시간이 흐르는 프로덕션에서 내부 Stopwatch가 담당한다.)
      expect(clock.elapsed.isNegative, isFalse);
    });

    test('중복 start/stop 호출은 상태를 깨뜨리지 않는다', () {
      clock.start();
      clock.start();
      now = now.add(const Duration(seconds: 12));
      clock.stop();
      clock.stop();

      expect(clock.isRunning, isFalse);
      expect(clock.elapsed.inSeconds, 12);
    });
  });
}
