import 'dart:async';
import 'dart:typed_data';

import 'cooking_ports.dart';

enum CookingCoachPhase { idle, connecting, live, stopping }

typedef CookingCoachStateHandler =
    void Function(CookingCoachPhase phase, String? message);

/// AI 코치 세션 하나의 수명을 소유한다: 토큰 발급 → Live 연결 → 마이크
/// 스트림 업로드 → 응답 재생. barge-in(interrupted)이 오면 재생 큐를 비운다.
///
/// 토큰이 1회용이라 세션도 1회용이다 — start마다 [sessionFactory]로 새
/// 세션을 만든다. 마이크는 하나뿐이므로 호출자(조리 화면)가 코치 활성 중
/// 명령 STT를 끄는 책임을 진다.
final class CookingCoachController {
  CookingCoachController({
    required this.sessionPort,
    required this.audioInput,
    required this.audioOutput,
    required this.onStateChanged,
    required this.sessionFactory,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AiLiveSessionPort sessionPort;
  final CoachAudioInputPort audioInput;
  final CoachAudioOutputPort audioOutput;
  final CookingCoachStateHandler onStateChanged;

  /// 세션은 토큰처럼 1회용 — start마다 새로 만든다.
  final CoachLiveSessionPort Function() sessionFactory;

  final DateTime Function() _now;

  /// 수신 오디오 포맷(24kHz PCM16 모노, docs/only-api.md 와이어 포맷) 기준으로
  /// 재생 잔량을 시간으로 환산한다.
  static const int _outputBytesPerSecond = 24000 * 2;

  /// 재생이 끝난 뒤에도 스피커 잔향이 마이크에 남는 동안 게이트를 유지한다.
  static const Duration _gateTail = Duration(milliseconds: 400);

  CookingCoachPhase _phase = CookingCoachPhase.idle;
  CoachLiveSessionPort? _session;
  StreamSubscription<Uint8List>? _micSubscription;
  int _generation = 0;
  bool _disposed = false;

  /// 코치 발화가 스피커에서 끝나는 예상 시각. 이 시각 + 꼬리까지 마이크
  /// 업로드를 멈춘다(half-duplex) — 하드웨어 에코 캔슬만으로는 코치 음성이
  /// 마이크로 되돌아 서버 VAD가 barge-in으로 오판하는 것을 못 막았고,
  /// 레벨 기반 판별도 불가능했다(A52 실측: 에코 잔여 RMS가 목소리의 3배).
  /// 가로채기는 [interrupt] 탭으로 제공한다.
  DateTime? _speakingUntil;

  /// 서버가 이번 턴 오디오를 아직 스트리밍 중인지(onAudio 후 ~ 턴 경계 전).
  bool _serverTurnStreaming = false;

  /// 탭 가로채기 후 턴 경계(interrupted/turnComplete)까지 수신 오디오를 버린다
  /// — 버리지 않으면 서버가 이어 보내는 나머지가 다시 재생돼 말이 되살아난다.
  bool _dropAudioUntilTurnBoundary = false;

  CookingCoachPhase get phase => _phase;

  bool get isActive => _phase != CookingCoachPhase.idle;

  Future<void> start(String recipeId) async {
    if (_disposed || _phase != CookingCoachPhase.idle) {
      return;
    }
    final generation = ++_generation;
    _speakingUntil = null;
    _serverTurnStreaming = false;
    _dropAudioUntilTurnBoundary = false;
    _emit(CookingCoachPhase.connecting, 'AI 코치를 연결하고 있어요.');

    try {
      // 토큰은 발급 후 1분 안에 연결을 시작해야 한다 — 발급과 연결 사이에
      // 다른 일을 끼워 넣지 않는다.
      final grant = await sessionPort.openSession(recipeId);
      if (!_isCurrent(generation)) {
        return;
      }
      final session = sessionFactory();
      _session = session;
      await session.open(
        grant: grant,
        onAudio: (pcm) {
          if (!_isCurrent(generation)) {
            return;
          }
          _serverTurnStreaming = true;
          if (_dropAudioUntilTurnBoundary) {
            return;
          }
          _extendSpeakingGate(pcm.length);
          unawaited(audioOutput.feed(pcm));
        },
        onInterrupted: () {
          if (_isCurrent(generation)) {
            // 재생 큐를 비우므로 게이트도 함께 푼다.
            _speakingUntil = null;
            _serverTurnStreaming = false;
            _dropAudioUntilTurnBoundary = false;
            unawaited(audioOutput.flush());
          }
        },
        onTurnComplete: () {
          if (_isCurrent(generation)) {
            _serverTurnStreaming = false;
            _dropAudioUntilTurnBoundary = false;
          }
        },
        onEnded: () {
          if (_isCurrent(generation)) {
            unawaited(_teardown(generation, message: '코치 연결이 끝났어요.'));
          }
        },
      );
      if (!_isCurrent(generation)) {
        unawaited(session.close());
        return;
      }
      await audioOutput.start();
      final micStream = await audioInput.start();
      if (!_isCurrent(generation)) {
        return;
      }
      _micSubscription = micStream.listen(
        (chunk) {
          if (!_micGated) {
            session.sendAudioChunk(chunk);
          }
        },
        onError: (Object _) {
          if (_isCurrent(generation)) {
            unawaited(_teardown(generation, message: '마이크 입력이 끊어졌어요.'));
          }
        },
        onDone: () {
          if (_isCurrent(generation)) {
            unawaited(_teardown(generation, message: '마이크 입력이 끝났어요.'));
          }
        },
      );
      _emit(CookingCoachPhase.live, '코치가 듣고 있어요. 편하게 말씀하세요.');
    } on CoachSessionException catch (exception) {
      await _failStart(generation, exception.message);
    } on CoachMicrophonePermissionDenied {
      await _failStart(generation, '마이크 권한이 없어 코치를 시작할 수 없어요.');
    } catch (_) {
      await _failStart(generation, 'AI 코치를 시작하지 못했어요.');
    }
  }

  /// 탭 가로채기: 코치 발화를 즉시 멈추고 마이크를 연다. 서버가 아직 이번
  /// 턴을 스트리밍 중이면 턴 경계까지 수신 오디오를 버린다.
  void interrupt() {
    if (_disposed || _phase != CookingCoachPhase.live) {
      return;
    }
    _speakingUntil = null;
    if (_serverTurnStreaming) {
      _dropAudioUntilTurnBoundary = true;
    }
    unawaited(audioOutput.flush());
  }

  Future<void> stop() async {
    if (_phase == CookingCoachPhase.idle ||
        _phase == CookingCoachPhase.stopping) {
      return;
    }
    final generation = _generation;
    _emit(CookingCoachPhase.stopping, null);
    await _teardown(generation, message: 'AI 코치를 껐어요.');
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _generation++;
    final micSubscription = _micSubscription;
    _micSubscription = null;
    final session = _session;
    _session = null;
    unawaited(micSubscription?.cancel());
    unawaited(_swallow(() => audioInput.stop()));
    unawaited(_swallow(() => audioOutput.stop()));
    if (session != null) {
      unawaited(_swallow(session.close));
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  bool get _micGated {
    final until = _speakingUntil;
    return until != null && _now().isBefore(until.add(_gateTail));
  }

  void _extendSpeakingGate(int pcmByteLength) {
    final chunkDuration = Duration(
      microseconds:
          pcmByteLength *
          Duration.microsecondsPerSecond ~/
          _outputBytesPerSecond,
    );
    final now = _now();
    final until = _speakingUntil;
    // 재생 큐는 순차 소진되므로, 아직 재생 중이면 그 끝에 이어 붙는다.
    final base = (until != null && until.isAfter(now)) ? until : now;
    _speakingUntil = base.add(chunkDuration);
  }

  Future<void> _failStart(int generation, String message) async {
    if (!_isCurrent(generation)) {
      return;
    }
    await _cleanupResources();
    if (_isCurrent(generation)) {
      _emit(CookingCoachPhase.idle, message);
    }
  }

  Future<void> _teardown(int generation, {String? message}) async {
    if (!_isCurrent(generation)) {
      return;
    }
    _generation++;
    _speakingUntil = null;
    _serverTurnStreaming = false;
    _dropAudioUntilTurnBoundary = false;
    await _cleanupResources();
    if (!_disposed) {
      _emit(CookingCoachPhase.idle, message);
    }
  }

  Future<void> _cleanupResources() async {
    final micSubscription = _micSubscription;
    _micSubscription = null;
    if (micSubscription != null) {
      await micSubscription.cancel();
    }
    final session = _session;
    _session = null;
    await _swallow(() => audioInput.stop());
    if (session != null) {
      await _swallow(session.close);
    }
    await _swallow(() => audioOutput.stop());
  }

  Future<void> _swallow(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // 정리 실패가 화면 흐름(버튼·타이머)을 막지 않게 한다.
    }
  }

  void _emit(CookingCoachPhase phase, String? message) {
    if (_disposed) {
      return;
    }
    _phase = phase;
    onStateChanged(phase, message);
  }
}
