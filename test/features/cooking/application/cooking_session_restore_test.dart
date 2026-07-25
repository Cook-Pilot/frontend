import 'package:cookpilot/features/cooking/application/cooking_session_controller.dart';
import 'package:cookpilot/features/cooking/application/timer_controller.dart';
import 'package:cookpilot/features/cooking/domain/cooking_session_state.dart';
import 'package:cookpilot/features/cooking/domain/cooking_step.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/cooking_fakes.dart';

void main() {
  group('CookingSessionController 복원', () {
    late FakeMonotonicClock monotonicClock;
    late FakeTimerAlarm alarm;

    setUp(() {
      monotonicClock = FakeMonotonicClock();
      alarm = FakeTimerAlarm();
    });

    CookingSessionController buildController({
      int initialStepIndex = 0,
      StepTimerSnapshot? initialTimerSnapshot,
    }) {
      return CookingSessionController(
        sessionId: 'restore-test',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(clock: monotonicClock, autoTick: false),
        speechInput: FakeSpeechInput(),
        speechOutput: FakeSpeechOutput(),
        exceptionAdvice: FakeExceptionAdvicePort(),
        alarm: alarm,
        wallClock: () => DateTime(2026, 7, 24, 18),
        initialStepIndex: initialStepIndex,
        initialTimerSnapshot: initialTimerSnapshot,
      );
    }

    test('저장된 단계와 타이머로 세션을 이어서 시작한다', () {
      final controller = buildController(
        initialStepIndex: 1,
        initialTimerSnapshot: const StepTimerSnapshot(
          originalDuration: Duration(minutes: 3),
          effectiveDuration: Duration(minutes: 3),
          remaining: Duration(minutes: 1, seconds: 30),
          status: TimerStatus.running,
        ),
      );
      addTearDown(controller.dispose);

      expect(controller.state.stepIndex, 1);
      expect(controller.currentStep.id, 'ramen-noodles');
      expect(controller.state.sessionStatus, CookingSessionStatus.cooking);
      expect(controller.timer.status, TimerStatus.running);
      expect(
        controller.timer.remaining,
        const Duration(minutes: 1, seconds: 30),
      );
      expect(controller.events.first.command, 'session_restored');
      // 실행 중 타이머는 완료 시각 기준으로 백그라운드 알림을 다시 예약한다.
      expect(
        alarm.lastScheduledAt,
        DateTime(2026, 7, 24, 18).add(const Duration(minutes: 1, seconds: 30)),
      );
    });

    test('일시정지 상태로 저장된 세션은 일시정지로 복원한다', () {
      final controller = buildController(
        initialStepIndex: 1,
        initialTimerSnapshot: const StepTimerSnapshot(
          originalDuration: Duration(minutes: 3),
          effectiveDuration: Duration(minutes: 3),
          remaining: Duration(minutes: 2),
          status: TimerStatus.paused,
        ),
      );
      addTearDown(controller.dispose);

      expect(controller.state.sessionStatus, CookingSessionStatus.paused);
      expect(controller.timer.status, TimerStatus.paused);
      expect(controller.timer.remaining, const Duration(minutes: 2));
    });

    test('앱이 꺼진 사이 시간이 다 지난 타이머는 종료 상태로 복원한다', () {
      final controller = buildController(
        initialStepIndex: 0,
        initialTimerSnapshot: const StepTimerSnapshot(
          originalDuration: Duration(minutes: 2, seconds: 14),
          effectiveDuration: Duration(minutes: 2, seconds: 14),
          remaining: Duration(minutes: -3), // 복원 계산 결과 음수
          status: TimerStatus.running,
        ),
      );
      addTearDown(controller.dispose);

      expect(controller.timer.status, TimerStatus.elapsed);
      expect(controller.timer.remaining, Duration.zero);
    });

    test('범위를 벗어난 단계 인덱스는 안전하게 보정한다', () {
      final tooLarge = buildController(initialStepIndex: 99);
      addTearDown(tooLarge.dispose);
      expect(tooLarge.state.stepIndex, ramenDemoSteps.length - 1);

      final negative = buildController(initialStepIndex: -1);
      addTearDown(negative.dispose);
      expect(negative.state.stepIndex, 0);
    });

    test('복원 없이 시작하면 기존과 동일하게 동작한다', () {
      final controller = buildController();
      addTearDown(controller.dispose);

      expect(controller.state.stepIndex, 0);
      expect(controller.events.first.command, 'session_started');
      expect(controller.state.lastCommandMessage, '조리를 시작했어요.');
    });
  });
}
