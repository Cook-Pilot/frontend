import 'package:cookpilot/features/cooking/application/timer_controller.dart';
import 'package:cookpilot/features/cooking/domain/cooking_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/cooking_fakes.dart';

void main() {
  group('LocalTimerController', () {
    late FakeMonotonicClock clock;
    late LocalTimerController controller;

    setUp(() {
      clock = FakeMonotonicClock();
      controller = LocalTimerController(clock: clock, autoTick: false);
    });

    tearDown(() => controller.dispose());

    test('monotonic elapsed를 기준으로 남은 시간을 재계산한다', () {
      controller.reset(const Duration(minutes: 2, seconds: 14));
      clock.elapse(const Duration(seconds: 14));
      controller.sync();

      expect(controller.status, TimerStatus.running);
      expect(controller.remaining, const Duration(minutes: 2));
      expect(controller.progress, closeTo(14 / 134, 0.001));
    });

    test('일시정지 중에는 시간이 흐르지 않고 재개 후 이어진다', () {
      controller.reset(const Duration(minutes: 2));
      clock.elapse(const Duration(seconds: 20));
      controller.pause();
      clock.elapse(const Duration(seconds: 30));

      expect(controller.status, TimerStatus.paused);
      expect(controller.remaining, const Duration(minutes: 1, seconds: 40));

      controller.resume();
      clock.elapse(const Duration(seconds: 10));
      controller.sync();
      expect(controller.remaining, const Duration(minutes: 1, seconds: 30));
    });

    test('1분 추가는 네트워크 없이 즉시 반영된다', () {
      controller.reset(const Duration(minutes: 1));
      controller.pause();
      controller.add(const Duration(minutes: 1));

      expect(controller.status, TimerStatus.paused);
      expect(controller.remaining, const Duration(minutes: 2));
      expect(controller.effectiveDuration, const Duration(minutes: 2));
    });

    test('종료되어도 단계 이동을 발생시키지 않고 elapsed에 머문다', () {
      controller.reset(const Duration(seconds: 5));
      clock.elapse(const Duration(seconds: 6));
      controller.sync();

      expect(controller.status, TimerStatus.elapsed);
      expect(controller.remaining, Duration.zero);
    });

    test('단계 snapshot을 복원한다', () {
      controller.reset(const Duration(minutes: 2));
      clock.elapse(const Duration(seconds: 20));
      controller.pause();
      final snapshot = controller.snapshot();

      controller.reset(const Duration(minutes: 5));
      controller.restore(snapshot);

      expect(controller.status, TimerStatus.paused);
      expect(controller.remaining, const Duration(minutes: 1, seconds: 40));
    });

    test('running이지만 0초인 snapshot은 elapsed로 정규화한다', () {
      controller.restore(
        const StepTimerSnapshot(
          originalDuration: Duration(minutes: 1),
          effectiveDuration: Duration(minutes: 1),
          remaining: Duration.zero,
          status: TimerStatus.running,
        ),
      );

      expect(controller.status, TimerStatus.elapsed);
      expect(controller.remaining, Duration.zero);
    });

    test('음수 snapshot 값은 안전한 idle 0초로 정규화한다', () {
      controller.restore(
        const StepTimerSnapshot(
          originalDuration: Duration(seconds: -10),
          effectiveDuration: Duration(seconds: -5),
          remaining: Duration(seconds: -1),
          status: TimerStatus.running,
        ),
      );

      expect(controller.originalDuration, Duration.zero);
      expect(controller.effectiveDuration, Duration.zero);
      expect(controller.remaining, Duration.zero);
      expect(controller.status, TimerStatus.idle);
    });

    test('남은 시간이 전체 시간을 넘는 snapshot은 상한 안으로 정규화한다', () {
      controller.restore(
        const StepTimerSnapshot(
          originalDuration: Duration(minutes: 1),
          effectiveDuration: Duration(seconds: 30),
          remaining: Duration(minutes: 2),
          status: TimerStatus.elapsed,
        ),
      );

      expect(controller.originalDuration, const Duration(minutes: 1));
      expect(controller.effectiveDuration, const Duration(minutes: 1));
      expect(controller.remaining, const Duration(minutes: 1));
      expect(controller.status, TimerStatus.paused);
    });
  });
}
