import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/cooking/presentation/cooking_voice_session_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/cooking_fakes.dart';

void main() {
  CookingVoiceSessionController createController({
    required FakeSpeechInput speech,
    required List<(CookingVoiceSpeechPhase, String?)> states,
    required List<String> transcripts,
    bool handsFreeEnabled = false,
    AppLifecycleState initialLifecycleState = AppLifecycleState.resumed,
    FakeMonotonicClock? retryClock,
    int maxAutomaticRetries = 5,
  }) {
    return CookingVoiceSessionController(
      speechInput: speech,
      handsFreeEnabled: handsFreeEnabled,
      initialLifecycleState: initialLifecycleState,
      retryClock: retryClock,
      maxAutomaticRetries: maxAutomaticRetries,
      onStateChanged: (phase, message) => states.add((phase, message)),
      onTranscript: transcripts.add,
    );
  }

  test('짧은 retryRequired는 stop 완료 뒤 같은 논리 요청에서 다시 듣는다', () async {
    final speech = FakeSpeechInput()..hangOnStop = true;
    final states = <(CookingVoiceSpeechPhase, String?)>[];
    final controller = createController(
      speech: speech,
      states: states,
      transcripts: <String>[],
      retryClock: FakeMonotonicClock(),
    );
    addTearDown(controller.dispose);

    await controller.start();
    expect(speech.startCount, 1);
    expect(controller.phase, CookingVoiceSpeechPhase.listening);

    speech.emitFailure(SpeechInputFailure.retryRequired);
    await pumpEventQueue();
    expect(speech.stopCount, 1);
    expect(speech.startCount, 1);
    expect(controller.phase, CookingVoiceSpeechPhase.stopping);
    expect(states.last.$2, contains('조금 더 기다릴게요'));

    speech.completePendingStop();
    await pumpEventQueue();
    expect(speech.startCount, 2);
    expect(controller.phase, CookingVoiceSpeechPhase.listening);
  });

  test('즉시 실패 recognizer는 retry 횟수 상한 뒤 오류 상태에 머문다', () async {
    final speech = FakeSpeechInput();
    final controller = createController(
      speech: speech,
      states: <(CookingVoiceSpeechPhase, String?)>[],
      transcripts: <String>[],
      retryClock: FakeMonotonicClock(),
      maxAutomaticRetries: 2,
    );
    addTearDown(controller.dispose);

    await controller.start();
    speech.emitFailure(SpeechInputFailure.retryRequired);
    await pumpEventQueue();
    speech.emitFailure(SpeechInputFailure.retryRequired);
    await pumpEventQueue();
    speech.emitFailure(SpeechInputFailure.retryRequired);
    await pumpEventQueue();

    expect(speech.startCount, 3);
    expect(controller.phase, CookingVoiceSpeechPhase.retryRequired);
  });

  test('1초 cutoff는 최대 여섯 attempt로 약 6초까지 완화한다', () async {
    final retryClock = FakeMonotonicClock();
    final speech = FakeSpeechInput();
    final controller = createController(
      speech: speech,
      states: <(CookingVoiceSpeechPhase, String?)>[],
      transcripts: <String>[],
      retryClock: retryClock,
    );
    addTearDown(controller.dispose);

    await controller.start();
    for (var retry = 0; retry < 5; retry++) {
      retryClock.elapse(const Duration(seconds: 1));
      speech.emitFailure(SpeechInputFailure.retryRequired);
      await pumpEventQueue();
      expect(speech.startCount, retry + 2);
    }

    // The deadline and attempt cap are circuit breakers, not a timer that cuts
    // off an active utterance or a strict six-second minimum guarantee.
    retryClock.elapse(const Duration(seconds: 1));
    speech.emitFailure(SpeechInputFailure.retryRequired);
    await pumpEventQueue();
    expect(speech.startCount, 6);
    expect(controller.phase, CookingVoiceSpeechPhase.retryRequired);
  });

  test('준비 창이 지난 retryRequired와 권한 오류는 자동 재시작하지 않는다', () async {
    final retryClock = FakeMonotonicClock();
    final speech = FakeSpeechInput();
    final controller = createController(
      speech: speech,
      states: <(CookingVoiceSpeechPhase, String?)>[],
      transcripts: <String>[],
      retryClock: retryClock,
    );
    addTearDown(controller.dispose);

    await controller.start();
    retryClock.elapse(const Duration(seconds: 6));
    speech.emitFailure(SpeechInputFailure.retryRequired);
    await pumpEventQueue();
    expect(speech.startCount, 1);
    expect(controller.phase, CookingVoiceSpeechPhase.retryRequired);

    controller.toggle();
    await pumpEventQueue();
    expect(speech.startCount, 2);
    speech.emitFailure(SpeechInputFailure.permissionDenied);
    await pumpEventQueue();
    expect(speech.startCount, 2);
    expect(controller.phase, CookingVoiceSpeechPhase.permissionDenied);
  });

  test('중복 inactive와 resumed도 pending stop 뒤 시작을 정확히 한 번 복구한다', () async {
    final speech = FakeSpeechInput()
      ..autoReady = false
      ..hangOnStop = true;
    final controller = createController(
      speech: speech,
      states: <(CookingVoiceSpeechPhase, String?)>[],
      transcripts: <String>[],
    );
    addTearDown(controller.dispose);

    await controller.start();
    controller.handleLifecycleStateChanged(AppLifecycleState.inactive);
    controller.handleLifecycleStateChanged(AppLifecycleState.inactive);
    controller.handleLifecycleStateChanged(AppLifecycleState.resumed);
    controller.handleLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();

    expect(speech.startCount, 1);
    speech.completePendingStop();
    await pumpEventQueue();
    expect(speech.startCount, 2);
    expect(controller.phase, CookingVoiceSpeechPhase.starting);
  });

  test('inactive에서 요청된 최초 핸즈프리는 direct resumed까지 미룬다', () async {
    final speech = FakeSpeechInput();
    final controller = createController(
      speech: speech,
      states: <(CookingVoiceSpeechPhase, String?)>[],
      transcripts: <String>[],
      handsFreeEnabled: true,
      initialLifecycleState: AppLifecycleState.inactive,
    );
    addTearDown(controller.dispose);

    await controller.startHandsFree();
    expect(speech.startCount, 0);

    controller.handleLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(speech.startCount, 1);
    expect(controller.phase, CookingVoiceSpeechPhase.listening);
  });

  test('호출자가 소유한 권한 흐름의 hidden과 paused는 최초 핸즈프리 opt-in을 보존한다', () async {
    final speech = FakeSpeechInput();
    final controller = createController(
      speech: speech,
      states: <(CookingVoiceSpeechPhase, String?)>[],
      transcripts: <String>[],
      handsFreeEnabled: true,
    );
    addTearDown(controller.dispose);

    controller.handleLifecycleStateChanged(
      AppLifecycleState.hidden,
      preservePendingHandsFreeStart: true,
    );
    controller.handleLifecycleStateChanged(
      AppLifecycleState.paused,
      preservePendingHandsFreeStart: true,
    );
    controller.handleLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(speech.startCount, 0);

    await controller.startHandsFree();
    expect(speech.startCount, 1);
    expect(controller.phase, CookingVoiceSpeechPhase.listening);
  });

  test('중복 inactive 뒤 복구한 핸즈프리는 명령 후에도 다시 듣는다', () async {
    final speech = FakeSpeechInput()
      ..autoReady = false
      ..hangOnStop = true;
    final transcripts = <String>[];
    final controller = createController(
      speech: speech,
      states: <(CookingVoiceSpeechPhase, String?)>[],
      transcripts: transcripts,
      handsFreeEnabled: true,
    );
    addTearDown(controller.dispose);

    await controller.startHandsFree();
    controller.handleLifecycleStateChanged(AppLifecycleState.inactive);
    controller.handleLifecycleStateChanged(AppLifecycleState.inactive);
    controller.handleLifecycleStateChanged(AppLifecycleState.resumed);
    speech.completePendingStop();
    await pumpEventQueue();
    expect(speech.startCount, 2);

    speech.emitReady();
    speech.emitUtterance('다음 단계', utteranceId: 'after-resume');
    await pumpEventQueue();
    expect(transcripts, ['다음 단계']);
    expect(speech.startCount, 3);
  });

  test('listening background와 완료는 pending 자동 재시작을 취소한다', () async {
    final speech = FakeSpeechInput()..hangOnStop = true;
    final controller = createController(
      speech: speech,
      states: <(CookingVoiceSpeechPhase, String?)>[],
      transcripts: <String>[],
      handsFreeEnabled: true,
    );
    addTearDown(controller.dispose);

    await controller.startHandsFree();
    controller.handleLifecycleStateChanged(AppLifecycleState.paused);
    controller.handleLifecycleStateChanged(AppLifecycleState.resumed);
    speech.completePendingStop();
    await pumpEventQueue();
    expect(speech.startCount, 1);

    controller.toggle();
    await pumpEventQueue();
    expect(speech.startCount, 2);
    speech.emitFailure(SpeechInputFailure.retryRequired);
    controller.complete();
    await pumpEventQueue();
    expect(speech.startCount, 2);
  });

  test('단계 경계는 이전 callback을 버리고 hands-free만 stop 뒤 재무장한다', () async {
    final speech = FakeSpeechInput()..hangOnStop = true;
    final transcripts = <String>[];
    final controller = createController(
      speech: speech,
      states: <(CookingVoiceSpeechPhase, String?)>[],
      transcripts: transcripts,
      handsFreeEnabled: true,
    );
    addTearDown(controller.dispose);

    await controller.startHandsFree();
    final staleUtterance = speech.onUtterance!;
    final rearm = controller.deactivateAndRearmHandsFree();
    staleUtterance('늦은 다음 단계', 'stale-step');
    await pumpEventQueue();
    expect(transcripts, isEmpty);
    expect(speech.startCount, 1);

    speech.completePendingStop();
    await rearm;
    expect(speech.startCount, 2);
    expect(controller.phase, CookingVoiceSpeechPhase.listening);
  });
}
