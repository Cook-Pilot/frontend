import 'dart:async';

import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/cooking/presentation/native_speech_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  test('ko_KR로 시작하고 final transcript만 한 번 전달한다', () async {
    final driver = _FakeSpeechDriver();
    final input = NativeSpeechInput(driver: driver);
    var readyCount = 0;
    final utterances = <(String, String?)>[];
    final failures = <SpeechInputFailure>[];

    input.start(
      onReady: () => readyCount++,
      onUtterance: (text, id) => utterances.add((text, id)),
      onFailure: failures.add,
    );
    await pumpEventQueue();

    expect(driver.listenCount, 1);
    expect(driver.lastLocaleId, 'ko_KR');
    expect(readyCount, 1);

    driver.emitResult('아직 듣는 중', isFinal: false);
    driver.emitResult('  다음 단계  ', isFinal: true);
    driver.emitResult('중복 final', isFinal: true);
    driver.emitStatus(NativeSpeechDriverStatus.done);

    expect(utterances, hasLength(1));
    expect(utterances.single.$1, '다음 단계');
    expect(utterances.single.$2, startsWith('native-stt-'));
    expect(failures, isEmpty);
  });

  test('pending 또는 active 상태의 중복 start를 무시한다', () async {
    final driver = _FakeSpeechDriver();
    final input = NativeSpeechInput(driver: driver);

    void start() {
      input.start(onReady: () {}, onUtterance: (_, _) {}, onFailure: (_) {});
    }

    start();
    start();
    await pumpEventQueue();
    start();
    await pumpEventQueue();

    expect(driver.initializeCount, 1);
    expect(driver.listenCount, 1);
  });

  test('초기화 실패는 권한 상태로 permissionDenied와 unavailable을 구분한다', () async {
    final deniedDriver = _FakeSpeechDriver()
      ..initializeResult = false
      ..permissionGranted = false;
    final unavailableDriver = _FakeSpeechDriver()
      ..initializeResult = false
      ..permissionGranted = true;

    expect(
      await _startAndReadFailure(deniedDriver),
      SpeechInputFailure.permissionDenied,
    );
    expect(
      await _startAndReadFailure(unavailableDriver),
      SpeechInputFailure.unavailable,
    );
  });

  test('플러그인 오류 코드를 세 실패 유형으로 매핑한다', () async {
    Future<SpeechInputFailure> failureFor(
      String code, {
      bool permanent = true,
    }) async {
      final driver = _FakeSpeechDriver();
      final failure = Completer<SpeechInputFailure>();
      final input = NativeSpeechInput(driver: driver);
      input.start(
        onReady: () {},
        onUtterance: (_, _) {},
        onFailure: failure.complete,
      );
      await pumpEventQueue();
      driver.emitError(code, permanent: permanent);
      return failure.future;
    }

    expect(
      await failureFor('error_permission'),
      SpeechInputFailure.permissionDenied,
    );
    expect(
      await failureFor('error_no_match'),
      SpeechInputFailure.retryRequired,
    );
    expect(
      await failureFor('error_language_not_supported'),
      SpeechInputFailure.unavailable,
    );
    expect(
      await failureFor('unknown transient', permanent: false),
      SpeechInputFailure.retryRequired,
    );
  });

  test('권한 확인 자체가 실패하면 보수적으로 permissionDenied로 분류한다', () async {
    final driver = _FakeSpeechDriver()
      ..initializeResult = false
      ..permissionError = StateError('permission channel unavailable');

    expect(
      await _startAndReadFailure(driver),
      SpeechInputFailure.permissionDenied,
    );
  });

  test('재시도와 사용 불가 단서가 섞인 오류 코드는 재시도로 분류한다', () async {
    final driver = _FakeSpeechDriver();
    final failure = Completer<SpeechInputFailure>();
    final input = NativeSpeechInput(driver: driver);
    input.start(
      onReady: () {},
      onUtterance: (_, _) {},
      onFailure: failure.complete,
    );
    await pumpEventQueue();

    // unavailable 단서(listen_failed)와 재시도 단서(retry)가 섞이면, 핸즈프리를
    // 영구 해제하는 unavailable 대신 비용이 싼 재시도를 우선한다.
    driver.emitError('listen_failed: recognizer busy, retry', permanent: true);

    expect(await failure.future, SpeechInputFailure.retryRequired);
  });

  test('final 결과 없이 자연 종료되면 retryRequired를 알린다', () async {
    final driver = _FakeSpeechDriver();
    final failure = Completer<SpeechInputFailure>();
    final input = NativeSpeechInput(driver: driver);
    input.start(
      onReady: () {},
      onUtterance: (_, _) {},
      onFailure: failure.complete,
    );
    await pumpEventQueue();

    driver.emitResult('부분 결과', isFinal: false);
    driver.emitStatus(NativeSpeechDriverStatus.done);

    expect(await failure.future, SpeechInputFailure.retryRequired);
  });

  test('stop과 cancel은 플랫폼 결과를 취소하고 늦은 callback을 폐기한다', () async {
    final driver = _FakeSpeechDriver();
    final input = NativeSpeechInput(driver: driver);
    final utterances = <String>[];

    void start() {
      input.start(
        onReady: () {},
        onUtterance: (text, _) => utterances.add(text),
        onFailure: (_) {},
      );
    }

    start();
    await pumpEventQueue();
    final firstResultHandler = driver.onResult;
    await input.stop();
    firstResultHandler?.call(
      const NativeSpeechDriverResult(transcript: '늦은 stop 결과', isFinal: true),
    );

    start();
    await pumpEventQueue();
    final secondResultHandler = driver.onResult;
    await input.cancel();
    secondResultHandler?.call(
      const NativeSpeechDriverResult(transcript: '늦은 cancel 결과', isFinal: true),
    );

    expect(driver.stopCount, 0);
    expect(driver.cancelCount, 2);
    expect(utterances, isEmpty);
  });

  test('공유 driver는 이전 화면 cancel 완료 후 새 화면 listen을 시작한다', () async {
    final driver = _FakeSpeechDriver();
    final firstInput = NativeSpeechInput(driver: driver);
    final secondInput = NativeSpeechInput(driver: driver);
    final cancelCompleter = Completer<void>();

    firstInput.start(onReady: () {}, onUtterance: (_, _) {}, onFailure: (_) {});
    await pumpEventQueue();
    driver.cancelCompleter = cancelCompleter;

    final stopFuture = firstInput.stop();
    secondInput.start(
      onReady: () {},
      onUtterance: (_, _) {},
      onFailure: (_) {},
    );
    await pumpEventQueue();

    expect(driver.cancelCount, 1);
    expect(driver.listenCount, 1);

    cancelCompleter.complete();
    await stopFuture;
    await pumpEventQueue();

    expect(driver.listenCount, 2);
  });

  test('새 화면이 공유 driver를 선점한 뒤 이전 화면 stop은 새 세션을 취소하지 않는다', () async {
    final driver = _FakeSpeechDriver();
    final firstInput = NativeSpeechInput(driver: driver);
    final secondInput = NativeSpeechInput(driver: driver);
    final secondUtterances = <String>[];
    final secondFailures = <SpeechInputFailure>[];

    // 두 adapter를 모두 한 번 초기화한 뒤 firstInput이 driver를 소유하게
    // 만든다. 기존 구현에서는 이 상태에서 second start와 first stop이
    // 각자의 queue를 타므로 새 listen 뒤에 이전 cancel이 실행될 수 있다.
    secondInput.start(
      onReady: () {},
      onUtterance: (_, _) {},
      onFailure: (_) {},
    );
    await pumpEventQueue();
    await secondInput.stop();
    firstInput.start(onReady: () {}, onUtterance: (_, _) {}, onFailure: (_) {});
    await pumpEventQueue();
    driver.operations.clear();

    secondInput.start(
      onReady: () {},
      onUtterance: (text, _) => secondUtterances.add(text),
      onFailure: secondFailures.add,
    );
    final staleStopFuture = firstInput.stop();
    await staleStopFuture;
    await pumpEventQueue();

    expect(driver.operations, ['cancel', 'initialize', 'listen']);

    driver.emitResult('새 화면 명령', isFinal: true);
    driver.emitStatus(NativeSpeechDriverStatus.done);

    expect(secondUtterances, ['새 화면 명령']);
    expect(secondFailures, isEmpty);
  });

  test('driver handoff의 cancel terminal callback은 새 세션에 전달하지 않는다', () async {
    final driver = _FakeSpeechDriver();
    final firstInput = NativeSpeechInput(driver: driver);
    final secondInput = NativeSpeechInput(driver: driver);
    final firstFailures = <SpeechInputFailure>[];
    final secondFailures = <SpeechInputFailure>[];
    final secondUtterances = <String>[];

    firstInput.start(
      onReady: () {},
      onUtterance: (_, _) {},
      onFailure: firstFailures.add,
    );
    await pumpEventQueue();
    driver
      ..statusDuringCancel = NativeSpeechDriverStatus.done
      ..errorDuringCancel = const NativeSpeechDriverError(
        code: 'error_no_match',
        permanent: false,
      );

    secondInput.start(
      onReady: () {},
      onUtterance: (text, _) => secondUtterances.add(text),
      onFailure: secondFailures.add,
    );
    final staleStopFuture = firstInput.stop();
    await staleStopFuture;
    await pumpEventQueue();

    expect(driver.operations, [
      'initialize',
      'listen',
      'cancel',
      'initialize',
      'listen',
    ]);
    driver.emitResult('handoff 이후 결과', isFinal: true);
    driver.emitStatus(NativeSpeechDriverStatus.done);

    expect(firstFailures, isEmpty);
    expect(secondFailures, isEmpty);
    expect(secondUtterances, ['handoff 이후 결과']);
  });

  test('공유 driver queue는 cancel 예외 뒤 다음 세션에서 복구한다', () async {
    final driver = _FakeSpeechDriver();
    final firstInput = NativeSpeechInput(driver: driver);
    final secondInput = NativeSpeechInput(driver: driver);
    final secondUtterances = <String>[];

    firstInput.start(onReady: () {}, onUtterance: (_, _) {}, onFailure: (_) {});
    await pumpEventQueue();
    driver.cancelError = StateError('cancel failed');

    await expectLater(firstInput.stop(), throwsA(isA<StateError>()));

    driver.cancelError = null;
    secondInput.start(
      onReady: () {},
      onUtterance: (text, _) => secondUtterances.add(text),
      onFailure: (_) {},
    );
    await pumpEventQueue();

    expect(driver.cancelCount, 2);
    driver.emitResult('복구된 세션', isFinal: true);
    driver.emitStatus(NativeSpeechDriverStatus.done);
    expect(secondUtterances, ['복구된 세션']);
  });

  test('재시작 뒤 이전 세션의 늦은 done status를 무시한다', () async {
    final driver = _FakeSpeechDriver();
    final input = NativeSpeechInput(driver: driver);
    final utterances = <String>[];
    final failures = <SpeechInputFailure>[];

    input.start(onReady: () {}, onUtterance: (_, _) {}, onFailure: (_) {});
    await pumpEventQueue();
    final staleStatus = driver.onStatus;
    await input.stop();

    input.start(
      onReady: () {},
      onUtterance: (text, _) => utterances.add(text),
      onFailure: failures.add,
    );
    await pumpEventQueue();

    staleStatus?.call(NativeSpeechDriverStatus.done);
    driver.emitResult('재시작 세션 결과', isFinal: true);
    driver.emitStatus(NativeSpeechDriverStatus.done);

    expect(utterances, ['재시작 세션 결과']);
    expect(failures, isEmpty);
  });

  test('재시작 뒤 이전 세션의 늦은 error를 무시한다', () async {
    final driver = _FakeSpeechDriver();
    final input = NativeSpeechInput(driver: driver);
    final utterances = <String>[];
    final failures = <SpeechInputFailure>[];

    input.start(onReady: () {}, onUtterance: (_, _) {}, onFailure: (_) {});
    await pumpEventQueue();
    final staleError = driver.onError;
    await input.stop();

    input.start(
      onReady: () {},
      onUtterance: (text, _) => utterances.add(text),
      onFailure: failures.add,
    );
    await pumpEventQueue();

    staleError?.call(
      const NativeSpeechDriverError(code: 'error_no_match', permanent: false),
    );
    driver.emitResult('재시작 세션 결과', isFinal: true);
    driver.emitStatus(NativeSpeechDriverStatus.done);

    expect(utterances, ['재시작 세션 결과']);
    expect(failures, isEmpty);
  });

  test('초기화 도중 stop하면 준비와 결과 callback이 살아나지 않는다', () async {
    final driver = _FakeSpeechDriver()..initializeCompleter = Completer<bool>();
    final input = NativeSpeechInput(driver: driver);
    var readyCount = 0;
    var utteranceCount = 0;
    var failureCount = 0;

    input.start(
      onReady: () => readyCount++,
      onUtterance: (_, _) => utteranceCount++,
      onFailure: (_) => failureCount++,
    );
    await pumpEventQueue();

    final stopFuture = input.stop();
    driver.initializeCompleter!.complete(true);
    await stopFuture;
    driver.emitStatus(NativeSpeechDriverStatus.listening);
    driver.emitResult('늦은 결과', isFinal: true);

    expect(driver.listenCount, 0);
    expect(readyCount, 0);
    expect(utteranceCount, 0);
    expect(failureCount, 0);
  });

  test('listen 시작 예외는 retryRequired로 매핑한다', () async {
    final driver = _FakeSpeechDriver()
      ..listenError = StateError('temporary listen failure');

    expect(
      await _startAndReadFailure(driver),
      SpeechInputFailure.retryRequired,
    );
  });

  test('ListenFailedException의 message와 details로 실패 유형을 구분한다', () async {
    final unavailableDriver = _FakeSpeechDriver()
      ..listenError = ListenFailedException(
        'listen failed',
        'error_language_not_supported',
      );
    final permissionDriver = _FakeSpeechDriver()
      ..listenError = ListenFailedException('error_permission');
    final recognizerCreationDriver = _FakeSpeechDriver()
      ..listenError = ListenFailedException(
        'Failed to create speech recognizer',
      );

    expect(
      await _startAndReadFailure(unavailableDriver),
      SpeechInputFailure.unavailable,
    );
    expect(
      await _startAndReadFailure(permissionDriver),
      SpeechInputFailure.permissionDenied,
    );
    expect(
      await _startAndReadFailure(recognizerCreationDriver),
      SpeechInputFailure.unavailable,
    );
  });

  test('production driver는 재초기화 때 현재 화면의 status handler로 교체한다', () async {
    final speech = _ReinitializeIgnoringSpeechToText();
    final driver = SpeechToTextRecognitionDriver(speech: speech);
    final firstStatuses = <NativeSpeechDriverStatus>[];
    final secondStatuses = <NativeSpeechDriverStatus>[];

    await driver.initialize(onError: (_) {}, onStatus: firstStatuses.add);
    await driver.initialize(onError: (_) {}, onStatus: secondStatuses.add);
    speech.emitStatus(SpeechToText.doneStatus);

    expect(firstStatuses, isEmpty);
    expect(secondStatuses, [NativeSpeechDriverStatus.done]);
  });

  test(
    'production driver는 이전 raw lifecycle을 drain한 뒤 새 handler를 연결한다',
    () async {
      final speech = _LateLifecycleSpeechToText();
      final driver = SpeechToTextRecognitionDriver(
        speech: speech,
        lifecycleDrainTimeout: const Duration(seconds: 1),
      );
      final firstInput = NativeSpeechInput(driver: driver);
      final secondInput = NativeSpeechInput(driver: driver);
      final firstFailures = <SpeechInputFailure>[];
      final secondFailures = <SpeechInputFailure>[];

      firstInput.start(
        onReady: () {},
        onUtterance: (_, _) {},
        onFailure: firstFailures.add,
      );
      await pumpEventQueue();

      final stopFuture = firstInput.stop();
      secondInput.start(
        onReady: () {},
        onUtterance: (_, _) {},
        onFailure: secondFailures.add,
      );
      await pumpEventQueue();

      // Underlying cancel already returned, but its raw terminal callbacks have
      // not arrived. The mutable forwarding slots must still belong to A.
      expect(speech.cancelCount, 1);
      expect(speech.listenCount, 1);

      speech.emitDoneThenQueuedError();
      await stopFuture;
      await pumpEventQueue();

      expect(speech.listenCount, 2);
      expect(firstFailures, isEmpty);
      expect(secondFailures, isEmpty);

      // Once B is bound, a genuine B error must still be delivered.
      speech.emitError('error_no_match', permanent: false);
      await pumpEventQueue();
      expect(secondFailures, [SpeechInputFailure.retryRequired]);

      speech.emitStatus(SpeechToText.doneStatus);
      await pumpEventQueue();
    },
  );

  test(
    'production driver drain은 done과 cancel 완료 뒤 quiet turn을 모두 기다린다',
    () async {
      final speech = _LateLifecycleSpeechToText()
        ..cancelCompleter = Completer<void>();
      final driver = SpeechToTextRecognitionDriver(
        speech: speech,
        lifecycleDrainTimeout: const Duration(seconds: 1),
      );
      final firstInput = NativeSpeechInput(driver: driver);
      final secondInput = NativeSpeechInput(driver: driver);
      final secondFailures = <SpeechInputFailure>[];

      firstInput.start(
        onReady: () {},
        onUtterance: (_, _) {},
        onFailure: (_) {},
      );
      await pumpEventQueue();

      final stopFuture = firstInput.stop();
      secondInput.start(
        onReady: () {},
        onUtterance: (_, _) {},
        onFailure: secondFailures.add,
      );
      await pumpEventQueue();

      // done alone cannot release B while the underlying cancel is pending.
      speech.emitStatus(SpeechToText.doneStatus);
      await pumpEventQueue();
      expect(speech.listenCount, 1);

      speech.completeCancelThenQueueError();
      await stopFuture;
      await pumpEventQueue();

      expect(speech.listenCount, 2);
      expect(secondFailures, isEmpty);
    },
  );

  test('production driver는 자연 종료 뒤 trailing raw error까지 drain한다', () async {
    final speech = _LateLifecycleSpeechToText();
    final driver = SpeechToTextRecognitionDriver(
      speech: speech,
      lifecycleDrainTimeout: const Duration(seconds: 1),
    );
    final firstInput = NativeSpeechInput(driver: driver);
    final secondInput = NativeSpeechInput(driver: driver);
    final secondFailures = <SpeechInputFailure>[];

    firstInput.start(onReady: () {}, onUtterance: (_, _) {}, onFailure: (_) {});
    await pumpEventQueue();

    speech.emitDoneThenQueuedError();
    secondInput.start(
      onReady: () {},
      onUtterance: (_, _) {},
      onFailure: secondFailures.add,
    );
    await pumpEventQueue();

    expect(speech.listenCount, 2);
    expect(secondFailures, isEmpty);
  });

  test('production driver drain timeout은 이전 owner를 tombstone으로 유지한다', () async {
    final speech = _LateLifecycleSpeechToText();
    final driver = SpeechToTextRecognitionDriver(
      speech: speech,
      lifecycleDrainTimeout: const Duration(milliseconds: 20),
    );
    final firstInput = NativeSpeechInput(driver: driver);
    final secondInput = NativeSpeechInput(driver: driver);
    final handoffFailure = Completer<SpeechInputFailure>();

    firstInput.start(onReady: () {}, onUtterance: (_, _) {}, onFailure: (_) {});
    await pumpEventQueue();

    secondInput.start(
      onReady: () {},
      onUtterance: (_, _) {},
      onFailure: handoffFailure.complete,
    );

    expect(await handoffFailure.future, SpeechInputFailure.retryRequired);
    expect(speech.listenCount, 1);

    // The late acknowledgement clears the driver fence. A retry then retires
    // the coordinator's previous-owner tombstone before binding the new slot.
    speech.emitStatus(SpeechToText.doneStatus);
    await pumpEventQueue();
    secondInput.start(
      onReady: () {},
      onUtterance: (_, _) {},
      onFailure: (_) {},
    );
    await pumpEventQueue();

    expect(speech.listenCount, 2);
  });

  test('production driver는 end 예외 뒤에도 raw drain tombstone을 유지한다', () async {
    final speech = _LateLifecycleSpeechToText()
      ..cancelError = StateError('native cancel failed')
      ..doneBeforeCancelError = true
      ..errorAfterCancelError = true;
    final driver = SpeechToTextRecognitionDriver(
      speech: speech,
      lifecycleDrainTimeout: const Duration(seconds: 1),
    );
    final firstInput = NativeSpeechInput(driver: driver);
    final secondInput = NativeSpeechInput(driver: driver);
    final handoffFailure = Completer<SpeechInputFailure>();
    final retryFailures = <SpeechInputFailure>[];

    firstInput.start(onReady: () {}, onUtterance: (_, _) {}, onFailure: (_) {});
    await pumpEventQueue();

    secondInput.start(
      onReady: () {},
      onUtterance: (_, _) {},
      onFailure: handoffFailure.complete,
    );
    expect(await handoffFailure.future, SpeechInputFailure.retryRequired);
    expect(speech.listenCount, 1);

    // Retry before the next event turn. If the end-error catch cleared the
    // existing drain, the queued old error would be forwarded into this B slot.
    secondInput.start(
      onReady: () {},
      onUtterance: (_, _) {},
      onFailure: retryFailures.add,
    );
    await pumpEventQueue();

    expect(speech.cancelCount, 1);
    expect(speech.listenCount, 2);
    expect(retryFailures, isEmpty);
  });

  test('production driver는 done 없는 end 예외를 같은 drain에서 재시도한다', () async {
    final speech = _LateLifecycleSpeechToText()
      ..cancelError = StateError('native cancel failed')
      ..doneAfterSuccessfulCancel = true;
    final driver = SpeechToTextRecognitionDriver(
      speech: speech,
      lifecycleDrainTimeout: const Duration(milliseconds: 100),
    );
    final firstInput = NativeSpeechInput(driver: driver);
    final secondInput = NativeSpeechInput(driver: driver);
    final handoffFailure = Completer<SpeechInputFailure>();
    final retryReady = Completer<bool>();

    firstInput.start(onReady: () {}, onUtterance: (_, _) {}, onFailure: (_) {});
    await pumpEventQueue();

    secondInput.start(
      onReady: () {},
      onUtterance: (_, _) {},
      onFailure: handoffFailure.complete,
    );
    expect(await handoffFailure.future, SpeechInputFailure.retryRequired);
    expect(speech.cancelCount, 1);
    expect(speech.listenCount, 1);

    secondInput.start(
      onReady: () => retryReady.complete(true),
      onUtterance: (_, _) {},
      onFailure: (_) => retryReady.complete(false),
    );

    expect(await retryReady.future, isTrue);
    expect(speech.cancelCount, 2);
    expect(speech.listenCount, 2);
  });

  test('기본 production driver는 SpeechToText singleton에 맞춰 공유된다', () {
    expect(
      identical(
        SpeechToTextRecognitionDriver(),
        SpeechToTextRecognitionDriver(),
      ),
      isTrue,
    );
  });
}

Future<SpeechInputFailure> _startAndReadFailure(
  _FakeSpeechDriver driver,
) async {
  final failure = Completer<SpeechInputFailure>();
  final input = NativeSpeechInput(driver: driver);
  input.start(
    onReady: () {},
    onUtterance: (_, _) {},
    onFailure: failure.complete,
  );
  await pumpEventQueue();
  return failure.future;
}

final class _FakeSpeechDriver implements NativeSpeechRecognitionDriver {
  bool initializeResult = true;
  bool permissionGranted = true;
  Object? permissionError;
  Completer<bool>? initializeCompleter;
  Object? listenError;
  int initializeCount = 0;
  int listenCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  String? lastLocaleId;
  Completer<void>? cancelCompleter;
  Object? cancelError;
  NativeSpeechDriverStatus? statusDuringCancel;
  NativeSpeechDriverError? errorDuringCancel;
  final operations = <String>[];
  NativeSpeechDriverResultHandler? onResult;
  NativeSpeechDriverErrorHandler? onError;
  NativeSpeechDriverStatusHandler? onStatus;

  @override
  Future<bool> get hasPermission async {
    if (permissionError case final Object error) {
      throw error;
    }
    return permissionGranted;
  }

  @override
  Future<bool> initialize({
    required NativeSpeechDriverErrorHandler onError,
    required NativeSpeechDriverStatusHandler onStatus,
  }) async {
    initializeCount++;
    operations.add('initialize');
    this.onError = onError;
    this.onStatus = onStatus;
    return initializeCompleter?.future ?? initializeResult;
  }

  @override
  Future<void> listen({
    required String localeId,
    required NativeSpeechDriverResultHandler onResult,
  }) async {
    listenCount++;
    operations.add('listen');
    lastLocaleId = localeId;
    this.onResult = onResult;
    if (listenError case final Object error) {
      throw error;
    }
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    operations.add('cancel');
    if (statusDuringCancel case final status?) {
      onStatus?.call(status);
    }
    if (errorDuringCancel case final error?) {
      onError?.call(error);
    }
    await cancelCompleter?.future;
    if (cancelError case final Object error) {
      throw error;
    }
  }

  void emitResult(String transcript, {required bool isFinal}) {
    onResult?.call(
      NativeSpeechDriverResult(transcript: transcript, isFinal: isFinal),
    );
  }

  void emitError(String code, {required bool permanent}) {
    onError?.call(NativeSpeechDriverError(code: code, permanent: permanent));
  }

  void emitStatus(NativeSpeechDriverStatus status) {
    onStatus?.call(status);
  }
}

final class _ReinitializeIgnoringSpeechToText extends SpeechToText {
  _ReinitializeIgnoringSpeechToText() : super.withMethodChannel();

  SpeechStatusListener? _installedStatus;
  bool _initialized = false;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    if (_initialized) {
      return true;
    }
    _initialized = true;
    _installedStatus = onStatus;
    return true;
  }

  void emitStatus(String status) => _installedStatus?.call(status);
}

final class _LateLifecycleSpeechToText extends SpeechToText {
  _LateLifecycleSpeechToText() : super.withMethodChannel();

  SpeechErrorListener? _installedError;
  SpeechStatusListener? _installedStatus;
  bool _initialized = false;
  int listenCount = 0;
  int cancelCount = 0;
  Completer<void>? cancelCompleter;
  Object? cancelError;
  bool doneBeforeCancelError = false;
  bool errorAfterCancelError = false;
  bool doneAfterSuccessfulCancel = false;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    if (_initialized) {
      return true;
    }
    _initialized = true;
    _installedError = onError;
    _installedStatus = onStatus;
    return true;
  }

  @override
  Future<void> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    listenCount++;
    _installedStatus?.call(SpeechToText.listeningStatus);
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    await cancelCompleter?.future;
    if (cancelError case final Object error) {
      cancelError = null;
      if (doneBeforeCancelError) {
        doneBeforeCancelError = false;
        emitStatus(SpeechToText.doneStatus);
      }
      if (errorAfterCancelError) {
        errorAfterCancelError = false;
        Timer.run(
          () => _installedError?.call(
            SpeechRecognitionError('error_request_cancelled', false),
          ),
        );
      }
      throw error;
    }
    if (doneAfterSuccessfulCancel) {
      doneAfterSuccessfulCancel = false;
      emitStatus(SpeechToText.doneStatus);
    }
  }

  void emitDoneThenQueuedError() {
    emitStatus(SpeechToText.doneStatus);
    Timer.run(
      () => _installedError?.call(
        SpeechRecognitionError('error_request_cancelled', false),
      ),
    );
  }

  void emitError(String code, {required bool permanent}) {
    _installedError?.call(SpeechRecognitionError(code, permanent));
  }

  void completeCancelThenQueueError() {
    cancelCompleter?.complete();
    Timer.run(
      () => _installedError?.call(
        SpeechRecognitionError('error_request_cancelled', false),
      ),
    );
  }

  void emitStatus(String status) => _installedStatus?.call(status);
}
