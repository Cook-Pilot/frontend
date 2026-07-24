import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/cooking/application/cooking_session_controller.dart';
import 'package:cookpilot/features/cooking/application/local_command_router.dart';
import 'package:cookpilot/features/cooking/application/timer_controller.dart';
import 'package:cookpilot/features/cooking/domain/cooking_session_state.dart';
import 'package:cookpilot/features/cooking/domain/cooking_step.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/cooking_fakes.dart';

void main() {
  group('CookingSessionController', () {
    late FakeMonotonicClock monotonicClock;
    late FakeSpeechInput speechInput;
    late FakeSpeechOutput speech;
    late FakeExceptionAdvicePort advice;
    late DateTime now;
    late Duration commandTime;
    late CookingSessionController controller;

    setUp(() {
      monotonicClock = FakeMonotonicClock();
      speechInput = FakeSpeechInput();
      speech = FakeSpeechOutput();
      advice = FakeExceptionAdvicePort();
      now = DateTime(2026, 7, 20, 18);
      commandTime = Duration.zero;
      controller = CookingSessionController(
        sessionId: 'test-session',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(clock: monotonicClock, autoTick: false),
        speechInput: speechInput,
        speechOutput: speech,
        exceptionAdvice: advice,
        wallClock: () => now,
        commandClock: () => commandTime,
      );
    });

    tearDown(() => controller.dispose());

    test('단계 이동은 화면 상태를 먼저 바꾸고 현재 단계만 안내한다', () async {
      final result = await controller.execute(CookingCommand.nextStep);

      expect(result.executed, isTrue);
      expect(controller.state.stepIndex, 1);
      expect(controller.currentStep.id, 'ramen-noodles');
      expect(speech.spoken.single, contains('면과 스프'));
      expect(controller.state.voicePhase, VoicePhase.listening);
    });

    test('동일 명령의 빠른 중복 실행을 한 번만 처리한다', () async {
      final first = await controller.execute(CookingCommand.nextStep);
      final second = await controller.execute(CookingCommand.nextStep);

      expect(first.executed, isTrue);
      expect(second.executed, isFalse);
      expect(controller.state.stepIndex, 1);

      commandTime += const Duration(milliseconds: 301);
      final third = await controller.execute(CookingCommand.nextStep);
      expect(third.executed, isTrue);
      expect(controller.state.stepIndex, 2);
    });

    test('마지막 단계의 다음은 자동 완료하지 않는다', () async {
      await controller.execute(CookingCommand.nextStep);
      commandTime += const Duration(milliseconds: 301);
      await controller.execute(CookingCommand.nextStep);
      commandTime += const Duration(milliseconds: 301);

      final result = await controller.execute(CookingCommand.nextStep);

      expect(result.executed, isFalse);
      expect(controller.state.stepIndex, 2);
      expect(controller.state.sessionStatus, CookingSessionStatus.cooking);
    });

    test('음성과 버튼은 같은 로컬 command 경로를 사용한다', () async {
      final voiceResult = await controller.handleUtterance(
        '1분 더',
        utteranceId: 'utterance-1',
      );

      expect(voiceResult.executed, isTrue);
      expect(
        controller.timer.remaining,
        const Duration(minutes: 3, seconds: 14),
      );
      expect(controller.events.last.source.name, 'voice');
      expect(controller.events.last.command, 'add_minute');
    });

    test('동일 utterance id는 A-B-A 순서에서도 다시 실행하지 않는다', () async {
      await controller.enterForeground();
      speech.spoken.clear();
      final first = await controller.handleUtterance(
        '1분 더',
        utteranceId: 'stable-id',
      );
      commandTime += const Duration(milliseconds: 301);
      final between = await controller.handleUtterance(
        '타이머 멈춰',
        utteranceId: 'between-id',
      );
      commandTime += const Duration(milliseconds: 301);
      final duplicate = await controller.handleUtterance(
        '1분 더',
        utteranceId: 'stable-id',
      );

      expect(first.executed, isTrue);
      expect(between.executed, isTrue);
      expect(duplicate.executed, isFalse);
      expect(
        controller.timer.remaining,
        const Duration(minutes: 3, seconds: 14),
      );
    });

    test('예외 질문은 현재 맥락을 전달하고 답을 화면 상태에 저장한다', () async {
      final result = await controller.handleUtterance(
        '물이 안 끓어',
        utteranceId: 'utterance-2',
      );

      expect(result.executed, isTrue);
      final context = advice.requests.single;
      expect(context.recipeId, 'ramen');
      expect(context.recipeVersionId, 'base-v1');
      expect(context.stepIndex, 0);
      expect(context.remaining, const Duration(minutes: 2, seconds: 14));
      expect(context.recentEvents, isNotEmpty);
      expect(context.recentEvents.last.command, 'exception_advice_requested');
      expect(controller.state.exceptionFeedback, contains('30초'));
      expect(controller.state.voicePhase, VoicePhase.listening);
    });

    test('단계 변경 뒤 도착한 예전 LLM 답변을 폐기한다', () async {
      final deferred = DeferredExceptionAdvicePort();
      final staleController = CookingSessionController(
        sessionId: 'stale-test',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: FakeSpeechInput(),
        speechOutput: FakeSpeechOutput(),
        exceptionAdvice: deferred,
        wallClock: () => now,
      );
      addTearDown(staleController.dispose);

      final pending = staleController.handleUtterance(
        '물이 안 끓어',
        utteranceId: 'stale-1',
      );
      commandTime += const Duration(milliseconds: 301);
      await staleController.execute(CookingCommand.nextStep);
      deferred.completer.complete(
        const ExceptionAdvice(message: '이 답은 표시되면 안 됩니다.'),
      );

      final result = await pending;
      expect(result.executed, isFalse);
      expect(staleController.state.exceptionFeedback, isNull);
      expect(
        staleController.events.any(
          (event) => event.result == 'stale_context_or_request',
        ),
        isTrue,
      );
    });

    test('LLM 대기 중 타이머 안내가 끼어도 같은 맥락의 답변은 반영한다', () async {
      final pendingClock = FakeMonotonicClock();
      final deferred = DeferredExceptionAdvicePort();
      final timerSpeech = FakeSpeechOutput();
      final guardedController = CookingSessionController(
        sessionId: 'advice-survives-timer-prompt',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(clock: pendingClock, autoTick: false),
        speechInput: FakeSpeechInput(),
        speechOutput: timerSpeech,
        exceptionAdvice: deferred,
      );
      addTearDown(guardedController.dispose);
      await guardedController.enterForeground();

      final pendingAdvice = guardedController.handleUtterance(
        '물이 안 끓어',
        utteranceId: 'timer-during-advice',
      );
      pendingClock.elapse(const Duration(minutes: 3));
      guardedController.timer.sync();
      for (var index = 0; index < 5; index += 1) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(guardedController.state.voicePhase, VoicePhase.processing);
      deferred.completer.complete(
        const ExceptionAdvice(message: '같은 단계의 최신 답변'),
      );

      final result = await pendingAdvice;
      expect(result.executed, isTrue);
      expect(guardedController.state.exceptionFeedback, '같은 단계의 최신 답변');
      expect(timerSpeech.spoken.last, '같은 단계의 최신 답변');
      expect(
        guardedController.events.any(
          (event) => event.command == 'exception_advice_discarded',
        ),
        isFalse,
      );
    });

    test('LLM 대기 중 STT unavailable이면 답변은 남기되 listening으로 속이지 않는다', () async {
      final deferred = DeferredExceptionAdvicePort();
      final guardedInput = FakeSpeechInput();
      final guardedController = CookingSessionController(
        sessionId: 'advice-after-stt-unavailable',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: guardedInput,
        speechOutput: FakeSpeechOutput(),
        exceptionAdvice: deferred,
      );
      addTearDown(guardedController.dispose);
      await guardedController.enterForeground();

      final pendingAdvice = guardedController.handleUtterance(
        '물이 안 끓어',
        utteranceId: 'stt-fails-during-advice',
      );
      guardedInput.emitFailure(SpeechInputFailure.unavailable);
      deferred.completer.complete(
        const ExceptionAdvice(message: '화면에는 유지할 답변'),
      );

      final result = await pendingAdvice;
      expect(result.executed, isTrue);
      expect(guardedController.state.exceptionFeedback, '화면에는 유지할 답변');
      expect(guardedController.state.voicePhase, VoicePhase.failed);
      expect(guardedInput.startCount, 1);
    });

    test('LLM 답변 TTS 뒤 STT ready 전에는 starting을 유지한다', () async {
      final deferred = DeferredExceptionAdvicePort();
      final guardedInput = FakeSpeechInput();
      final guardedController = CookingSessionController(
        sessionId: 'advice-waits-for-stt-ready',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: guardedInput,
        speechOutput: FakeSpeechOutput(),
        exceptionAdvice: deferred,
      );
      addTearDown(guardedController.dispose);
      await guardedController.enterForeground();
      guardedInput.autoReady = false;

      final pendingAdvice = guardedController.handleUtterance(
        '물이 안 끓어',
        utteranceId: 'advice-ready-barrier',
      );
      deferred.completer.complete(const ExceptionAdvice(message: '준비 확인용 답변'));

      expect((await pendingAdvice).executed, isTrue);
      expect(guardedController.state.voicePhase, VoicePhase.starting);
      guardedInput.emitReady();
      expect(guardedController.state.voicePhase, VoicePhase.listening);
    });

    test('완료는 review로 한 번만 전환하고 음성을 종료한다', () async {
      final result = await controller.execute(CookingCommand.completeSession);
      final repeated = await controller.execute(CookingCommand.completeSession);

      expect(result.executed, isTrue);
      expect(repeated.executed, isFalse);
      expect(controller.state.sessionStatus, CookingSessionStatus.review);
      expect(controller.state.voicePhase, VoicePhase.off);
      expect(speechInput.stopCount, 1);
      expect(speech.stopCount, 1);
      expect(
        controller.events
            .where((event) => event.command == 'complete_session')
            .length,
        1,
      );
    });

    test('화면 이탈 시 음성 수신을 종료하지만 타이머 상태는 유지한다', () async {
      final before = controller.timer.status;
      await controller.leaveForeground();

      expect(controller.state.voicePhase, VoicePhase.off);
      expect(controller.timer.status, before);
      expect(speechInput.stopCount, 1);
      expect(speech.stopCount, 1);
    });

    test('foreground 복귀 시 monotonic 경과를 동기화하고 STT를 다시 시작한다', () async {
      monotonicClock.elapse(const Duration(minutes: 3));
      await controller.leaveForeground();

      await controller.enterForeground();

      expect(controller.timer.status, TimerStatus.elapsed);
      expect(controller.timer.remaining, Duration.zero);
      expect(controller.state.voicePhase, VoicePhase.listening);
      expect(speechInput.startCount, 1);
    });

    test('STT adapter 콜백은 로컬 command router로 전달된다', () async {
      await controller.enterForeground();

      speechInput.emitUtterance('1분 더', utteranceId: 'adapter-1');
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.timer.remaining,
        const Duration(minutes: 3, seconds: 14),
      );
      expect(controller.state.voicePhase, VoicePhase.listening);
    });

    test('최초 foreground에서 현재 단계를 한 번만 TTS로 안내한다', () async {
      await controller.enterForeground();
      expect(speech.spoken.single, contains('물 500ml'));

      await controller.leaveForeground();
      await controller.enterForeground();
      expect(speech.spoken, hasLength(1));
    });

    test('STT 시작 실패와 무관하게 첫 단계 TTS를 재생하고 failed 상태를 유지한다', () async {
      speechInput.startError = StateError('stt unavailable');

      await controller.enterForeground();

      expect(speech.spoken.single, contains('물 500ml'));
      expect(controller.state.voicePhase, VoicePhase.failed);
    });

    test('부분 활성화 뒤 start throw가 나도 recognizer를 무효화하고 정리한다', () async {
      speechInput
        ..activateBeforeStartError = true
        ..startError = StateError('started then failed');

      await controller.enterForeground();
      await Future<void>.delayed(Duration.zero);
      final before = controller.timer.remaining;
      speechInput.emitUtterance('1분 더', utteranceId: 'stale-after-throw');
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.voicePhase, VoicePhase.failed);
      expect(controller.timer.remaining, before);
      expect(speechInput.stopCount, greaterThanOrEqualTo(1));

      speechInput.startError = null;
      await controller.enterForeground();
      expect(speechInput.startCount, 2);
      expect(controller.state.voicePhase, VoicePhase.listening);
    });

    test('마이크 권한 거절 상태에서도 다시 듣기 TTS가 동작한다', () async {
      controller.setMicrophonePermissionDenied();

      final result = await controller.execute(CookingCommand.repeatInstruction);

      expect(result.executed, isTrue);
      expect(speech.spoken.single, contains('물 500ml'));
      expect(controller.state.voicePhase, VoicePhase.permissionDenied);
    });

    test('권한 거절 뒤 foreground 재진입은 권한 결과에 맞춰 복구한다', () async {
      controller.setMicrophonePermissionDenied();
      speechInput.startFailure = SpeechInputFailure.permissionDenied;

      await controller.enterForeground();

      expect(speechInput.startCount, 1);
      expect(controller.state.voicePhase, VoicePhase.permissionDenied);

      speechInput.startFailure = null;
      await controller.enterForeground();

      expect(speechInput.startCount, 2);
      expect(controller.state.voicePhase, VoicePhase.listening);
    });

    test('STT start 반환만으로 권한 거절 상태를 해제하지 않는다', () async {
      controller.setMicrophonePermissionDenied();
      speechInput.autoReady = false;

      await controller.enterForeground();

      expect(controller.state.voicePhase, VoicePhase.permissionDenied);
      speechInput.emitReady();
      expect(controller.state.voicePhase, VoicePhase.listening);
    });

    test('일반 진입도 STT ready 전까지 starting을 유지한다', () async {
      speechInput.autoReady = false;

      await controller.enterForeground();

      expect(controller.state.voicePhase, VoicePhase.starting);
      speechInput.emitReady();
      expect(controller.state.voicePhase, VoicePhase.listening);
    });

    test('첫 TTS가 끝난 뒤 STT ready가 올 때까지 starting을 유지한다', () async {
      final delayedInput = FakeSpeechInput()..autoReady = false;
      final delayedSpeech = DeferredSpeechOutput();
      final delayedController = CookingSessionController(
        sessionId: 'ready-during-tts',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: delayedInput,
        speechOutput: delayedSpeech,
        exceptionAdvice: FakeExceptionAdvicePort(),
      );
      addTearDown(delayedController.dispose);

      final entering = delayedController.enterForeground();
      await Future<void>.delayed(Duration.zero);
      expect(delayedController.state.voicePhase, VoicePhase.speaking);
      expect(delayedInput.startCount, 0);

      delayedSpeech.completions.single.complete();
      await entering;

      expect(delayedInput.startCount, 1);
      expect(delayedController.state.voicePhase, VoicePhase.starting);
      delayedInput.emitReady();
      expect(delayedController.state.voicePhase, VoicePhase.listening);
    });

    test('중복 foreground 진입은 첫 TTS와 STT를 한 번만 시작한다', () async {
      final delayedInput = FakeSpeechInput();
      final delayedSpeech = DeferredSpeechOutput();
      final guardedController = CookingSessionController(
        sessionId: 'duplicate-foreground-entry',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: delayedInput,
        speechOutput: delayedSpeech,
        exceptionAdvice: FakeExceptionAdvicePort(),
      );
      addTearDown(guardedController.dispose);

      final first = guardedController.enterForeground();
      final second = guardedController.enterForeground();
      await Future<void>.delayed(Duration.zero);

      expect(identical(first, second), isTrue);
      expect(delayedSpeech.completions, hasLength(1));
      expect(delayedInput.startCount, 0);

      delayedSpeech.completions.single.complete();
      await Future.wait<void>(<Future<void>>[first, second]);

      expect(delayedInput.startCount, 1);
      expect(guardedController.state.voicePhase, VoicePhase.listening);
    });

    test('진입 TTS와 겹친 다시 듣기가 끝나기 전에는 STT를 시작하지 않는다', () async {
      final guardedInput = FakeSpeechInput();
      final delayedSpeech = DeferredSpeechOutput();
      final guardedController = CookingSessionController(
        sessionId: 'foreground-playback-barrier',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: guardedInput,
        speechOutput: delayedSpeech,
        exceptionAdvice: FakeExceptionAdvicePort(),
      );
      addTearDown(guardedController.dispose);

      final entering = guardedController.enterForeground();
      await Future<void>.delayed(Duration.zero);
      final repeating = guardedController.execute(
        CookingCommand.repeatInstruction,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(delayedSpeech.completions, hasLength(2));
      expect(guardedInput.startCount, 0);

      delayedSpeech.completions[1].complete();
      await repeating;
      await entering;

      expect(guardedInput.startCount, 1);
      expect(guardedController.state.voicePhase, VoicePhase.listening);
    });

    test('STT unavailable 뒤 다시 듣기는 failed 상태를 listening으로 속이지 않는다', () async {
      await controller.enterForeground();
      speech.spoken.clear();
      speechInput.emitFailure(SpeechInputFailure.unavailable);

      await controller.execute(CookingCommand.repeatInstruction);

      expect(speech.spoken.single, contains('물 500ml'));
      expect(controller.state.voicePhase, VoicePhase.failed);
    });

    test('STT unavailable 뒤 늦은 콜백은 무시하고 명시적 재진입은 다시 시작한다', () async {
      await controller.enterForeground();
      final before = controller.timer.remaining;
      speechInput.emitFailure(SpeechInputFailure.unavailable);

      speechInput.emitUtterance('1분 더', utteranceId: 'late-unavailable');
      await Future<void>.delayed(Duration.zero);
      expect(controller.timer.remaining, before);

      await controller.enterForeground();
      expect(speechInput.startCount, 2);
    });

    test('화면 이탈 뒤 도착한 LLM 답변은 음성과 화면을 되살리지 않는다', () async {
      final deferred = DeferredExceptionAdvicePort();
      final lateSpeech = FakeSpeechOutput();
      final lateController = CookingSessionController(
        sessionId: 'background-test',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: FakeSpeechInput(),
        speechOutput: lateSpeech,
        exceptionAdvice: deferred,
      );
      addTearDown(lateController.dispose);

      final pending = lateController.handleUtterance(
        '물이 안 끓어',
        utteranceId: 'background-1',
      );
      await lateController.leaveForeground();
      deferred.completer.complete(const ExceptionAdvice(message: '늦게 도착한 답변'));

      final result = await pending;
      expect(result.executed, isFalse);
      expect(lateController.state.voicePhase, VoicePhase.off);
      expect(lateController.state.exceptionFeedback, isNull);
      expect(lateSpeech.spoken, isEmpty);
    });

    test('음성 stop 실패가 완료 전환을 막지 않는다', () async {
      speechInput.stopError = StateError('input stop failed');
      speech.stopError = StateError('output stop failed');

      final result = await controller.execute(CookingCommand.completeSession);

      expect(result.executed, isTrue);
      expect(controller.state.sessionStatus, CookingSessionStatus.review);
      expect(
        controller.events.any(
          (event) => event.command == 'speech_input_stop_failed',
        ),
        isTrue,
      );
      expect(
        controller.events.any(
          (event) => event.command == 'speech_output_stop_failed',
        ),
        isTrue,
      );
    });

    test('음성 stop이 끝나지 않아도 timeout 뒤 완료 전환을 반환한다', () async {
      final hangingInput = FakeSpeechInput()..hangOnStop = true;
      final hangingOutput = FakeSpeechOutput()..hangOnStop = true;
      final timeoutController = CookingSessionController(
        sessionId: 'stop-timeout-test',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: hangingInput,
        speechOutput: hangingOutput,
        exceptionAdvice: FakeExceptionAdvicePort(),
        voiceStopTimeout: const Duration(milliseconds: 5),
      );
      addTearDown(() {
        hangingInput.completePendingStop();
        hangingOutput.completePendingStop();
        hangingInput.hangOnStop = false;
        hangingOutput.hangOnStop = false;
        timeoutController.dispose();
      });

      final result = await timeoutController.execute(
        CookingCommand.completeSession,
      );

      expect(result.executed, isTrue);
      expect(
        timeoutController.state.sessionStatus,
        CookingSessionStatus.review,
      );
      expect(
        timeoutController.events.where(
          (event) => event.command.endsWith('stop_timed_out'),
        ),
        hasLength(2),
      );
    });

    test('STT stop timeout 뒤에는 늦은 stop이 끝나기 전 재시작하지 않는다', () async {
      final delayedStopInput = FakeSpeechInput()..hangOnStop = true;
      final guardedController = CookingSessionController(
        sessionId: 'input-stop-race-test',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: delayedStopInput,
        speechOutput: FakeSpeechOutput(),
        exceptionAdvice: FakeExceptionAdvicePort(),
        voiceStopTimeout: const Duration(milliseconds: 5),
      );
      addTearDown(() {
        delayedStopInput.completePendingStop();
        delayedStopInput.hangOnStop = false;
        guardedController.dispose();
      });
      await guardedController.enterForeground();
      expect(delayedStopInput.startCount, 1);

      await guardedController.leaveForeground();
      await guardedController.enterForeground();

      expect(delayedStopInput.startCount, 1);
      expect(guardedController.state.voicePhase, VoicePhase.failed);

      delayedStopInput.completePendingStop();
      delayedStopInput.hangOnStop = false;
      await Future<void>.delayed(Duration.zero);
      await guardedController.enterForeground();

      expect(delayedStopInput.startCount, 2);
      expect(guardedController.state.voicePhase, VoicePhase.listening);
    });

    test('TTS stop timeout 중에는 새 재생을 시작하지 않고 늦은 stop 뒤 복구한다', () async {
      final delayedStopOutput = FakeSpeechOutput()..hangOnStop = true;
      var outputCommandTime = Duration.zero;
      final guardedController = CookingSessionController(
        sessionId: 'output-stop-race-test',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: FakeSpeechInput(),
        speechOutput: delayedStopOutput,
        exceptionAdvice: FakeExceptionAdvicePort(),
        voiceStopTimeout: const Duration(milliseconds: 5),
        commandClock: () => outputCommandTime,
      );
      addTearDown(() {
        delayedStopOutput.completePendingStop();
        delayedStopOutput.hangOnStop = false;
        guardedController.dispose();
      });

      await guardedController.execute(CookingCommand.repeatInstruction);
      outputCommandTime += const Duration(milliseconds: 301);
      await guardedController.execute(CookingCommand.repeatInstruction);

      expect(delayedStopOutput.spoken, isEmpty);
      expect(guardedController.state.voicePhase, VoicePhase.failed);

      delayedStopOutput.completePendingStop();
      delayedStopOutput.hangOnStop = false;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await guardedController.enterForeground();

      expect(delayedStopOutput.spoken.single, contains('물 500ml'));
      expect(guardedController.state.voicePhase, VoicePhase.listening);
    });

    test('TTS 중 빠른 이탈·재진입은 늦은 stop이 끝나기 전 STT를 시작하지 않는다', () async {
      final guardedInput = FakeSpeechInput();
      final delayedOutput = DeferredSpeechOutput();
      final guardedController = CookingSessionController(
        sessionId: 'foreground-output-stop-race',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: guardedInput,
        speechOutput: delayedOutput,
        exceptionAdvice: FakeExceptionAdvicePort(),
        voiceStopTimeout: const Duration(milliseconds: 5),
        voicePlaybackTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(() {
        delayedOutput.completePendingStop();
        delayedOutput.hangOnStop = false;
        guardedController.dispose();
      });

      final initialEntry = guardedController.enterForeground();
      await Future<void>.delayed(Duration.zero);
      expect(delayedOutput.completions, hasLength(1));
      delayedOutput.hangOnStop = true;

      final leaving = guardedController.leaveForeground();
      final resumedEntry = guardedController.enterForeground();
      await leaving;
      await resumedEntry;
      await initialEntry;

      expect(guardedInput.startCount, 0);
      expect(guardedController.state.voicePhase, VoicePhase.failed);

      delayedOutput.completePendingStop();
      delayedOutput.hangOnStop = false;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final recoveredEntry = guardedController.enterForeground();
      await Future<void>.delayed(Duration.zero);
      expect(delayedOutput.completions, hasLength(2));
      delayedOutput.completions[1].complete();
      await recoveredEntry;

      expect(guardedInput.startCount, 1);
      expect(guardedController.state.voicePhase, VoicePhase.listening);
    });

    test('종료·이탈·권한 거절 뒤 음성 콜백을 거부한다', () async {
      controller.setMicrophonePermissionDenied();
      final denied = await controller.handleUtterance(
        '다음',
        utteranceId: 'denied-1',
      );
      expect(denied.executed, isFalse);
      expect(controller.state.voicePhase, VoicePhase.permissionDenied);

      final terminalController = CookingSessionController(
        sessionId: 'terminal-test',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: FakeSpeechInput(),
        speechOutput: FakeSpeechOutput(),
        exceptionAdvice: FakeExceptionAdvicePort(),
      );
      addTearDown(terminalController.dispose);
      await terminalController.execute(CookingCommand.completeSession);
      final terminal = await terminalController.handleUtterance(
        '1분 더',
        utteranceId: 'terminal-1',
      );
      expect(terminal.executed, isFalse);
      expect(
        terminalController.state.sessionStatus,
        CookingSessionStatus.review,
      );
      expect(terminalController.state.voicePhase, VoicePhase.off);
    });

    test('같은 단계의 예외 질문은 가장 최신 답변만 반영한다', () async {
      final queued = QueuedExceptionAdvicePort();
      final latestController = CookingSessionController(
        sessionId: 'latest-request-test',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: FakeSpeechInput(),
        speechOutput: FakeSpeechOutput(),
        exceptionAdvice: queued,
      );
      addTearDown(latestController.dispose);

      final first = latestController.handleUtterance(
        '물이 안 끓어',
        utteranceId: 'request-1',
      );
      final second = latestController.handleUtterance(
        '냄비가 넘쳐',
        utteranceId: 'request-2',
      );
      queued.completions[1].complete(const ExceptionAdvice(message: '최신 답변'));
      expect((await second).executed, isTrue);
      expect(latestController.state.exceptionFeedback, '최신 답변');

      queued.completions[0].complete(const ExceptionAdvice(message: '오래된 답변'));
      expect((await first).executed, isFalse);
      expect(latestController.state.exceptionFeedback, '최신 답변');
    });

    test('겹친 TTS는 마지막 재생이 끝날 때만 listening으로 돌아간다', () async {
      final deferredSpeech = DeferredSpeechOutput();
      var ttsCommandTime = Duration.zero;
      final ttsController = CookingSessionController(
        sessionId: 'tts-race-test',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: FakeSpeechInput(),
        speechOutput: deferredSpeech,
        exceptionAdvice: FakeExceptionAdvicePort(),
        commandClock: () => ttsCommandTime,
      );
      addTearDown(ttsController.dispose);

      final first = ttsController.execute(CookingCommand.repeatInstruction);
      await Future<void>.delayed(Duration.zero);
      expect(deferredSpeech.completions, hasLength(1));
      ttsCommandTime += const Duration(milliseconds: 301);
      final second = ttsController.execute(CookingCommand.repeatInstruction);
      await Future<void>.delayed(Duration.zero);
      expect(deferredSpeech.completions, hasLength(2));

      await first;
      expect(deferredSpeech.completions[0].isCompleted, isTrue);
      expect(ttsController.state.voicePhase, VoicePhase.speaking);

      deferredSpeech.completions[1].complete();
      await second;
      expect(ttsController.state.voicePhase, VoicePhase.listening);
    });

    test('TTS 재생 중 self-echo 음성 명령은 실행하지 않는다', () async {
      final deferredSpeech = DeferredSpeechOutput();
      final echoController = CookingSessionController(
        sessionId: 'tts-echo-test',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: FakeSpeechInput(),
        speechOutput: deferredSpeech,
        exceptionAdvice: FakeExceptionAdvicePort(),
      );
      addTearDown(echoController.dispose);

      final speaking = echoController.execute(CookingCommand.repeatInstruction);
      await Future<void>.delayed(Duration.zero);
      expect(echoController.state.voicePhase, VoicePhase.speaking);

      final echo = await echoController.handleUtterance(
        '다음 단계로 넘어가세요',
        utteranceId: 'device-echo-1',
      );
      expect(echo.executed, isFalse);
      expect(echoController.state.stepIndex, 0);

      deferredSpeech.completions.single.complete();
      await speaking;
    });

    test('TTS 종료 뒤 늦게 도착한 이전 STT 세대의 self-echo도 무시한다', () async {
      await controller.enterForeground();
      final oldUtteranceHandler = speechInput.utteranceHandlers.single;

      await controller.execute(CookingCommand.repeatInstruction);
      expect(speechInput.utteranceHandlers, hasLength(2));
      expect(controller.state.voicePhase, VoicePhase.listening);

      oldUtteranceHandler('다음 단계로 넘어가세요', 'delayed-device-echo');
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.stepIndex, 0);
    });

    test('TTS 뒤 새 STT 세션은 이전 세션과 같은 utterance id를 정상 처리한다', () async {
      await controller.enterForeground();
      speechInput.emitUtterance('1분 더', utteranceId: 'session-local-1');
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.timer.remaining,
        const Duration(minutes: 3, seconds: 14),
      );

      await controller.execute(CookingCommand.repeatInstruction);
      speechInput.emitUtterance('1분 더', utteranceId: 'session-local-1');
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.timer.remaining,
        const Duration(minutes: 4, seconds: 14),
      );
    });

    test('LLM 성공 뒤 TTS만 실패하면 답변은 화면에 남긴다', () async {
      speech.error = StateError('tts failed');

      final result = await controller.handleUtterance(
        '물이 안 끓어',
        utteranceId: 'tts-failure-1',
      );

      expect(result.executed, isTrue);
      expect(controller.state.exceptionFeedback, isNotNull);
      expect(controller.state.voicePhase, VoicePhase.failed);
      expect(
        controller.events.any(
          (event) => event.command == 'speech_output_failed',
        ),
        isTrue,
      );
      expect(
        controller.events.any(
          (event) => event.command == 'exception_advice_failed',
        ),
        isFalse,
      );
    });

    test('완료되지 않는 TTS도 제한 시간 뒤 중단하고 명령을 반환한다', () async {
      final guardedInput = FakeSpeechInput();
      final hangingSpeech = DeferredSpeechOutput();
      final guardedController = CookingSessionController(
        sessionId: 'playback-timeout',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: guardedInput,
        speechOutput: hangingSpeech,
        exceptionAdvice: FakeExceptionAdvicePort(),
        voiceStopTimeout: const Duration(milliseconds: 20),
        voicePlaybackTimeout: const Duration(milliseconds: 5),
      );
      addTearDown(guardedController.dispose);

      await guardedController.enterForeground().timeout(
        const Duration(milliseconds: 200),
      );
      final repeated = await guardedController
          .execute(CookingCommand.repeatInstruction)
          .timeout(const Duration(milliseconds: 200));

      expect(repeated.executed, isTrue);
      expect(guardedInput.startCount, 2);
      expect(hangingSpeech.completions, hasLength(2));
      expect(
        hangingSpeech.completions.every((item) => item.isCompleted),
        isTrue,
      );
      expect(
        guardedController.events
            .where(
              (event) => event.command == 'speech_output_playback_timed_out',
            )
            .length,
        2,
      );
    });

    test('STT 재시도 상태에서도 버튼 fallback은 계속 동작한다', () async {
      await controller.enterForeground();
      speechInput.emitFailure(SpeechInputFailure.retryRequired);

      expect(controller.state.voicePhase, VoicePhase.retryRequired);
      final result = await controller.execute(CookingCommand.addMinute);
      expect(result.executed, isTrue);
      expect(
        controller.timer.remaining,
        const Duration(minutes: 3, seconds: 14),
      );
    });

    test('LLM 실패 뒤에도 로컬 조작과 완료가 가능하다', () async {
      advice.error = StateError('network failed');
      final adviceResult = await controller.handleUtterance(
        '물이 안 끓어',
        utteranceId: 'network-failure-1',
      );

      expect(adviceResult.executed, isFalse);
      expect(controller.state.voicePhase, VoicePhase.failed);
      expect(
        (await controller.execute(CookingCommand.addMinute)).executed,
        isTrue,
      );
      expect(
        (await controller.execute(CookingCommand.completeSession)).executed,
        isTrue,
      );
      expect(controller.state.sessionStatus, CookingSessionStatus.review);
    });

    test('STT unavailable 상태에서도 버튼만으로 마지막 단계와 완료까지 진행한다', () async {
      await controller.enterForeground();
      speechInput.emitFailure(SpeechInputFailure.unavailable);

      expect(controller.state.voicePhase, VoicePhase.failed);
      expect(
        (await controller.execute(CookingCommand.nextStep)).executed,
        isTrue,
      );
      commandTime += const Duration(milliseconds: 301);
      expect(
        (await controller.execute(CookingCommand.nextStep)).executed,
        isTrue,
      );
      commandTime += const Duration(milliseconds: 301);
      expect(
        (await controller.execute(CookingCommand.completeSession)).executed,
        isTrue,
      );
      expect(controller.state.stepIndex, 2);
      expect(controller.state.sessionStatus, CookingSessionStatus.review);
    });

    test('중단은 한 번만 기록되고 stop 실패와 무관하게 terminal이 된다', () async {
      speechInput.stopError = StateError('input stop failed');
      speech.stopError = StateError('output stop failed');

      final first = await controller.execute(CookingCommand.abortSession);
      final second = await controller.execute(CookingCommand.abortSession);

      expect(first.executed, isTrue);
      expect(second.executed, isFalse);
      expect(controller.state.sessionStatus, CookingSessionStatus.aborted);
      expect(
        controller.events
            .where((event) => event.command == 'abort_session')
            .length,
        1,
      );
    });

    test('일시정지 상태에서 다음 단계로 가면 새 타이머와 세션이 함께 실행된다', () async {
      await controller.execute(CookingCommand.pauseTimer);
      commandTime += const Duration(milliseconds: 301);

      await controller.execute(CookingCommand.nextStep);

      expect(controller.timer.status, TimerStatus.running);
      expect(controller.state.sessionStatus, CookingSessionStatus.cooking);
    });

    test('tick 직전 0초 타이머의 pause는 elapsed로 처리한다', () async {
      monotonicClock.elapse(const Duration(minutes: 3));

      final result = await controller.execute(CookingCommand.pauseTimer);

      expect(result.executed, isFalse);
      expect(controller.timer.status, TimerStatus.elapsed);
      expect(controller.state.sessionStatus, CookingSessionStatus.cooking);
      expect(
        controller.events.any((event) => event.command == 'timer_elapsed'),
        isTrue,
      );
    });

    test('타이머가 0에 도달하면 알림음을 한 번만 울린다', () async {
      final alarm = FakeTimerAlarm();
      final alarmClock = FakeMonotonicClock();
      final alarmController = CookingSessionController(
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(clock: alarmClock, autoTick: false),
        speechInput: FakeSpeechInput(),
        speechOutput: FakeSpeechOutput(),
        exceptionAdvice: FakeExceptionAdvicePort(),
        alarm: alarm,
        wallClock: () => now,
      );
      addTearDown(alarmController.dispose);

      alarmClock.elapse(const Duration(minutes: 3));
      alarmController.timer.sync();
      // 이미 elapsed 상태에서 다시 sync해도 중복 발화하지 않는다.
      alarmController.timer.sync();

      expect(alarmController.timer.status, TimerStatus.elapsed);
      expect(alarm.signalCount, 1);
    });

    test('foreground 타이머 종료는 자동 이동 없이 다음 단계 안내를 TTS로 재생한다', () async {
      await controller.enterForeground();
      speech.spoken.clear();
      monotonicClock.elapse(const Duration(minutes: 3));

      controller.timer.sync();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.stepIndex, 0);
      expect(speech.spoken.single, contains('다음 버튼'));
      expect(controller.state.voicePhase, VoicePhase.listening);
      expect(
        controller.events.any(
          (event) => event.command == 'timer_elapsed_announcement_completed',
        ),
        isTrue,
      );
    });

    test('만료 안내 대기 중 1분 추가로 재개하면 오래된 종료 안내를 재생하지 않는다', () async {
      await controller.leaveForeground();
      monotonicClock.elapse(const Duration(minutes: 3));
      controller.timer.sync();
      await Future<void>.delayed(Duration.zero);

      await controller.execute(CookingCommand.addMinute);
      await controller.enterForeground();

      expect(controller.timer.status, TimerStatus.running);
      expect(speech.spoken.any((text) => text.contains('다음 버튼')), isFalse);
      expect(
        controller.events.any(
          (event) => event.command == 'timer_elapsed_announcement_completed',
        ),
        isFalse,
      );
    });

    test('재생 중인 만료 안내도 1분 추가 시 중단하고 STT를 안전하게 재개한다', () async {
      final activeClock = FakeMonotonicClock();
      final guardedInput = FakeSpeechInput();
      final delayedSpeech = DeferredSpeechOutput();
      final guardedController = CookingSessionController(
        sessionId: 'cancel-active-timer-prompt',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(clock: activeClock, autoTick: false),
        speechInput: guardedInput,
        speechOutput: delayedSpeech,
        exceptionAdvice: FakeExceptionAdvicePort(),
      );
      addTearDown(guardedController.dispose);

      final entering = guardedController.enterForeground();
      await Future<void>.delayed(Duration.zero);
      delayedSpeech.completions.single.complete();
      await entering;
      activeClock.elapse(const Duration(minutes: 3));
      guardedController.timer.sync();
      for (var index = 0; index < 5; index += 1) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(delayedSpeech.completions, hasLength(2));
      expect(delayedSpeech.spoken.last, contains('다음 버튼'));
      final result = await guardedController.execute(CookingCommand.addMinute);

      expect(result.executed, isTrue);
      expect(delayedSpeech.completions[1].isCompleted, isTrue);
      expect(guardedController.timer.status, TimerStatus.running);
      expect(guardedController.state.voicePhase, VoicePhase.listening);
      expect(guardedInput.startCount, 2);
      expect(
        guardedController.events.any(
          (event) => event.command == 'timer_elapsed_announcement_cancelled',
        ),
        isTrue,
      );
      expect(
        guardedController.events.any(
          (event) => event.command == 'timer_elapsed_announcement_completed',
        ),
        isFalse,
      );
    });

    test('만료 안내 취소가 지연돼도 후속 완료 상태와 이벤트를 덮지 않는다', () async {
      final activeClock = FakeMonotonicClock();
      final delayedSpeech = DeferredSpeechOutput();
      final guardedController = CookingSessionController(
        sessionId: 'timer-cancel-followed-by-complete',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(clock: activeClock, autoTick: false),
        speechInput: FakeSpeechInput(),
        speechOutput: delayedSpeech,
        exceptionAdvice: FakeExceptionAdvicePort(),
        voiceStopTimeout: const Duration(seconds: 1),
      );
      addTearDown(() {
        delayedSpeech.completePendingStop();
        delayedSpeech.hangOnStop = false;
        guardedController.dispose();
      });

      final entering = guardedController.enterForeground();
      await Future<void>.delayed(Duration.zero);
      delayedSpeech.completions.single.complete();
      await entering;
      activeClock.elapse(const Duration(minutes: 3));
      guardedController.timer.sync();
      for (var index = 0; index < 5; index += 1) {
        await Future<void>.delayed(Duration.zero);
      }
      delayedSpeech.hangOnStop = true;

      final adding = guardedController.execute(CookingCommand.addMinute);
      await Future<void>.delayed(Duration.zero);
      final completing = guardedController.execute(
        CookingCommand.completeSession,
      );
      delayedSpeech.hangOnStop = false;
      delayedSpeech.completePendingStop();
      await completing;
      await adding;

      expect(
        guardedController.state.sessionStatus,
        CookingSessionStatus.review,
      );
      expect(guardedController.state.lastCommandMessage, contains('조리가 끝났어요'));
      final addIndex = guardedController.events.indexWhere(
        (event) => event.command == 'add_minute',
      );
      final completeIndex = guardedController.events.indexWhere(
        (event) => event.command == 'complete_session',
      );
      expect(addIndex, greaterThanOrEqualTo(0));
      expect(completeIndex, greaterThan(addIndex));
    });

    test('foreground 진입 마지막 구간에 만료된 타이머 안내도 누락하지 않는다', () async {
      final pendingClock = FakeMonotonicClock();
      final guardedInput = FakeSpeechInput();
      final delayedSpeech = DeferredSpeechOutput();
      late final CookingSessionController guardedController;
      guardedInput.onStart = () {
        pendingClock.elapse(const Duration(minutes: 3));
        guardedController.timer.sync();
      };
      guardedController = CookingSessionController(
        sessionId: 'foreground-tail-timer',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(clock: pendingClock, autoTick: false),
        speechInput: guardedInput,
        speechOutput: delayedSpeech,
        exceptionAdvice: FakeExceptionAdvicePort(),
      );
      addTearDown(guardedController.dispose);

      final entering = guardedController.enterForeground();
      await Future<void>.delayed(Duration.zero);
      expect(delayedSpeech.completions, hasLength(1));
      expect(guardedInput.startCount, 0);

      delayedSpeech.completions.single.complete();
      await entering;
      for (var index = 0; index < 5; index += 1) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(delayedSpeech.completions, hasLength(2));
      expect(delayedSpeech.spoken.last, contains('다음 버튼'));
      delayedSpeech.completions[1].complete();
      for (var index = 0; index < 5; index += 1) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        guardedController.events.any(
          (event) => event.command == 'timer_elapsed_announcement_completed',
        ),
        isTrue,
      );
    });

    test('dispose 뒤 pending 답변이 완료돼도 상태 알림을 시도하지 않는다', () async {
      final deferred = DeferredExceptionAdvicePort();
      final disposable = CookingSessionController(
        sessionId: 'dispose-test',
        recipeId: 'ramen',
        recipeVersionId: 'base-v1',
        steps: ramenDemoSteps,
        timer: LocalTimerController(
          clock: FakeMonotonicClock(),
          autoTick: false,
        ),
        speechInput: FakeSpeechInput(),
        speechOutput: FakeSpeechOutput(),
        exceptionAdvice: deferred,
      );
      final pending = disposable.handleUtterance(
        '물이 안 끓어',
        utteranceId: 'dispose-1',
      );
      disposable.dispose();
      deferred.completer.complete(const ExceptionAdvice(message: '폐기할 답변'));

      final result = await pending;
      expect(result.executed, isFalse);
    });
  });
}
