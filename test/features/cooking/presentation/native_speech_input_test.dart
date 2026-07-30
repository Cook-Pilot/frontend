import 'dart:async';

import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/cooking/presentation/native_speech_input.dart';
import 'package:flutter_test/flutter_test.dart';
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

    expect(
      await _startAndReadFailure(unavailableDriver),
      SpeechInputFailure.unavailable,
    );
    expect(
      await _startAndReadFailure(permissionDriver),
      SpeechInputFailure.permissionDenied,
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
  Completer<bool>? initializeCompleter;
  Object? listenError;
  int initializeCount = 0;
  int listenCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  String? lastLocaleId;
  NativeSpeechDriverResultHandler? onResult;
  NativeSpeechDriverErrorHandler? onError;
  NativeSpeechDriverStatusHandler? onStatus;

  @override
  Future<bool> get hasPermission async => permissionGranted;

  @override
  Future<bool> initialize({
    required NativeSpeechDriverErrorHandler onError,
    required NativeSpeechDriverStatusHandler onStatus,
  }) async {
    initializeCount++;
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
