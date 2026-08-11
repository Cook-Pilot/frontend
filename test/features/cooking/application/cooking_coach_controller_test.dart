import 'dart:async';
import 'dart:typed_data';

import 'package:cookpilot/features/cooking/application/cooking_coach_controller.dart';
import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const recipeId = '10000000-0000-0000-0000-000000000001';
  const grant = AiLiveSessionGrant(token: 'auth_tokens/t', model: 'm');

  ({
    CookingCoachController controller,
    _FakeSessionPort sessionPort,
    _FakeAudioInput input,
    _FakeAudioOutput output,
    List<_FakeCoachSession> sessions,
    List<(CookingCoachPhase, String?)> states,
    _FakeClock clock,
  })
  build({Object? sessionPortError}) {
    final sessionPort = _FakeSessionPort(error: sessionPortError);
    final input = _FakeAudioInput();
    final output = _FakeAudioOutput();
    final sessions = <_FakeCoachSession>[];
    final states = <(CookingCoachPhase, String?)>[];
    final clock = _FakeClock(DateTime(2026, 1, 1));
    final controller = CookingCoachController(
      sessionPort: sessionPort,
      audioInput: input,
      audioOutput: output,
      sessionFactory: () {
        final session = _FakeCoachSession();
        sessions.add(session);
        return session;
      },
      onStateChanged: (phase, message) => states.add((phase, message)),
      now: () => clock.value,
    );
    return (
      controller: controller,
      sessionPort: sessionPort,
      input: input,
      output: output,
      sessions: sessions,
      states: states,
      clock: clock,
    );
  }

  test('시작하면 토큰 발급→연결→재생 준비→마이크 스트림을 세션에 잇는다', () async {
    final harness = build();

    await harness.controller.start(recipeId);

    expect(harness.controller.phase, CookingCoachPhase.live);
    expect(harness.sessionPort.requestedRecipeIds, [recipeId]);
    expect(harness.sessions.single.openedGrant, grant);
    expect(harness.output.started, isTrue);

    harness.input.emit(<int>[1, 2]);
    await Future<void>.delayed(Duration.zero);
    expect(harness.sessions.single.sentChunks, <List<int>>[
      <int>[1, 2],
    ]);
  });

  test('응답 오디오는 재생으로, interrupted는 flush로 전달한다', () async {
    final harness = build();
    await harness.controller.start(recipeId);
    final session = harness.sessions.single;

    session.onAudio!(Uint8List.fromList(<int>[9]));
    session.onInterrupted!();

    expect(harness.output.fedChunks, <List<int>>[
      <int>[9],
    ]);
    expect(harness.output.flushCount, 1);
  });

  test('코치가 말하는 동안 마이크 청크는 올리지 않는다(half-duplex 게이트)', () async {
    final harness = build();
    await harness.controller.start(recipeId);
    final session = harness.sessions.single;

    // 24kHz PCM16 모노 1초어치(48000바이트) 재생 시작.
    session.onAudio!(Uint8List(48000));

    harness.input.emit(<int>[1]);
    await Future<void>.delayed(Duration.zero);
    expect(session.sentChunks, isEmpty);

    // 재생은 끝났지만 잔향 꼬리(400ms) 안 — 여전히 게이트.
    harness.clock.advance(const Duration(milliseconds: 1300));
    harness.input.emit(<int>[2]);
    await Future<void>.delayed(Duration.zero);
    expect(session.sentChunks, isEmpty);

    // 꼬리까지 지나면 업로드 재개.
    harness.clock.advance(const Duration(milliseconds: 200));
    harness.input.emit(<int>[3]);
    await Future<void>.delayed(Duration.zero);
    expect(session.sentChunks, <List<int>>[
      <int>[3],
    ]);
  });

  test('탭 가로채기는 재생을 비우고 마이크를 열고, 턴 나머지를 버린다', () async {
    final harness = build();
    await harness.controller.start(recipeId);
    final session = harness.sessions.single;
    session.onAudio!(Uint8List(48000)); // 스트리밍 중 + 게이트 시작

    harness.controller.interrupt();

    expect(harness.output.flushCount, 1);
    // 마이크가 즉시 열린다.
    harness.input.emit(<int>[1]);
    await Future<void>.delayed(Duration.zero);
    expect(session.sentChunks, <List<int>>[
      <int>[1],
    ]);
    // 이번 턴의 나머지 오디오는 버려지고 게이트도 다시 걸리지 않는다.
    session.onAudio!(Uint8List.fromList(<int>[9, 9]));
    expect(harness.output.fedChunks.length, 1);
    // 턴 경계가 오면 다음 턴 오디오는 다시 재생된다.
    session.onTurnComplete!();
    session.onAudio!(Uint8List.fromList(<int>[7, 7]));
    expect(harness.output.fedChunks.length, 2);
  });

  test('턴이 끝난 뒤의 탭 가로채기는 다음 턴을 버리지 않는다', () async {
    final harness = build();
    await harness.controller.start(recipeId);
    final session = harness.sessions.single;
    session.onAudio!(Uint8List(48000));
    session.onTurnComplete!(); // 서버는 이미 다 보냈고 재생만 남은 상태

    harness.controller.interrupt();

    session.onAudio!(Uint8List.fromList(<int>[7, 7])); // 다음 턴 시작
    expect(harness.output.flushCount, 1);
    expect(harness.output.fedChunks.length, 2);
  });

  test('interrupted로 재생 큐를 비우면 게이트도 함께 풀린다', () async {
    final harness = build();
    await harness.controller.start(recipeId);
    final session = harness.sessions.single;

    session.onAudio!(Uint8List(48000));
    session.onInterrupted!();

    harness.input.emit(<int>[1]);
    await Future<void>.delayed(Duration.zero);
    expect(session.sentChunks, <List<int>>[
      <int>[1],
    ]);
  });

  test('stop은 마이크·세션·재생을 정리하고 idle로 돌아간다', () async {
    final harness = build();
    await harness.controller.start(recipeId);

    await harness.controller.stop();

    expect(harness.controller.phase, CookingCoachPhase.idle);
    expect(harness.input.stopped, isTrue);
    expect(harness.sessions.single.closed, isTrue);
    expect(harness.output.stoppedCount, 1);
    expect(harness.states.last, (CookingCoachPhase.idle, 'AI 코치를 껐어요.'));
  });

  test('토큰 발급 실패 메시지를 그대로 보여주고 idle로 남는다', () async {
    final harness = build(
      sessionPortError: const CoachSessionException('AI 코치가 서버에 준비되지 않았어요.'),
    );

    await harness.controller.start(recipeId);

    expect(harness.controller.phase, CookingCoachPhase.idle);
    expect(harness.states.last, (
      CookingCoachPhase.idle,
      'AI 코치가 서버에 준비되지 않았어요.',
    ));
    expect(harness.sessions, isEmpty);
  });

  test('마이크 권한 거부는 전용 안내로 번역하고 세션을 닫는다', () async {
    final harness = build();
    harness.input.permissionDenied = true;

    await harness.controller.start(recipeId);

    expect(harness.controller.phase, CookingCoachPhase.idle);
    expect(harness.states.last, (
      CookingCoachPhase.idle,
      '마이크 권한이 없어 코치를 시작할 수 없어요.',
    ));
    expect(harness.sessions.single.closed, isTrue);
    expect(harness.output.stoppedCount, greaterThan(0));
  });

  test('서버가 세션을 끝내면 정리하고 종료 안내를 보여준다', () async {
    final harness = build();
    await harness.controller.start(recipeId);

    harness.sessions.single.onEnded!();
    await Future<void>.delayed(Duration.zero);

    expect(harness.controller.phase, CookingCoachPhase.idle);
    expect(harness.states.last, (CookingCoachPhase.idle, '코치 연결이 끝났어요.'));
    expect(harness.input.stopped, isTrue);
  });

  test('dispose 후에는 어떤 콜백도 상태를 바꾸지 않는다', () async {
    final harness = build();
    await harness.controller.start(recipeId);
    final session = harness.sessions.single;
    final stateCount = harness.states.length;

    harness.controller.dispose();
    session.onAudio!(Uint8List.fromList(<int>[1]));
    session.onEnded!();
    await Future<void>.delayed(Duration.zero);

    expect(harness.states.length, stateCount);
    expect(session.closed, isTrue);
    expect(harness.input.stopped, isTrue);
  });
}

final class _FakeClock {
  _FakeClock(this.value);

  DateTime value;

  void advance(Duration duration) {
    value = value.add(duration);
  }
}

final class _FakeSessionPort implements AiLiveSessionPort {
  _FakeSessionPort({this.error});

  final Object? error;
  final List<String> requestedRecipeIds = <String>[];

  @override
  Future<AiLiveSessionGrant> openSession(String recipeId) async {
    requestedRecipeIds.add(recipeId);
    if (error case final error?) {
      throw error;
    }
    return const AiLiveSessionGrant(token: 'auth_tokens/t', model: 'm');
  }
}

final class _FakeCoachSession implements CoachLiveSessionPort {
  AiLiveSessionGrant? openedGrant;
  void Function(Uint8List pcm)? onAudio;
  void Function()? onInterrupted;
  void Function()? onEnded;
  void Function()? onTurnComplete;
  final List<List<int>> sentChunks = <List<int>>[];
  bool closed = false;

  @override
  Future<void> open({
    required AiLiveSessionGrant grant,
    required void Function(Uint8List pcm) onAudio,
    required void Function() onInterrupted,
    required void Function() onEnded,
    void Function()? onTurnComplete,
  }) async {
    openedGrant = grant;
    this.onAudio = onAudio;
    this.onInterrupted = onInterrupted;
    this.onEnded = onEnded;
    this.onTurnComplete = onTurnComplete;
  }

  @override
  void sendAudioChunk(Uint8List pcm) {
    sentChunks.add(List<int>.of(pcm));
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

final class _FakeAudioInput implements CoachAudioInputPort {
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();
  bool permissionDenied = false;
  bool stopped = false;

  void emit(List<int> pcm) => _controller.add(Uint8List.fromList(pcm));

  @override
  Future<Stream<Uint8List>> start() async {
    if (permissionDenied) {
      throw const CoachMicrophonePermissionDenied();
    }
    stopped = false;
    return _controller.stream;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

final class _FakeAudioOutput implements CoachAudioOutputPort {
  bool started = false;
  int stoppedCount = 0;
  int flushCount = 0;
  final List<List<int>> fedChunks = <List<int>>[];

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> feed(Uint8List pcm) async {
    fedChunks.add(List<int>.of(pcm));
  }

  @override
  Future<void> flush() async {
    flushCount++;
  }

  @override
  Future<void> stop() async {
    stoppedCount++;
  }
}
