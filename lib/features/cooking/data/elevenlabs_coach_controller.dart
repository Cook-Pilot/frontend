import 'dart:async';

import 'package:elevenlabs_agents/elevenlabs_agents.dart';

import '../application/cooking_coach_controller.dart';

/// ElevenLabs Agents로 붙는 코치 엔진(PoC). 마이크·재생·에코 캔슬·음성
/// barge-in을 SDK(WebRTC/LiveKit)가 전부 처리하므로 오디오 포트가 없고,
/// [interrupt]도 no-op이다 — 말하는 도중 목소리로 끊는 게 기본 동작이다.
///
/// 레시피 컨텍스트는 세션 overrides의 시스템 프롬프트로 넣는다. 대시보드
/// 에이전트 설정에서 prompt override가 허용돼 있어야 한다(docs 참고).
final class ElevenLabsCoachController implements CookingCoachEngine {
  ElevenLabsCoachController({
    required this.agentId,
    required this.buildRecipePrompt,
    required this.onStateChanged,
    ConversationClient Function(ConversationCallbacks callbacks)? clientFactory,
  }) : _clientFactory =
           clientFactory ??
           ((callbacks) => ConversationClient(callbacks: callbacks));

  final String agentId;

  /// 이번 요리의 재료·단계 전문을 담은 시스템 프롬프트를 만든다.
  final String Function() buildRecipePrompt;
  final CookingCoachStateHandler onStateChanged;

  final ConversationClient Function(ConversationCallbacks callbacks)
  _clientFactory;

  CookingCoachPhase _phase = CookingCoachPhase.idle;
  ConversationClient? _client;
  int _generation = 0;
  bool _disposed = false;

  @override
  CookingCoachPhase get phase => _phase;

  @override
  bool get isActive => _phase != CookingCoachPhase.idle;

  @override
  Future<void> start(String recipeId) async {
    if (_disposed || _phase != CookingCoachPhase.idle) {
      return;
    }
    if (agentId.trim().isEmpty) {
      _emit(CookingCoachPhase.idle, 'ELEVENLABS_AGENT_ID가 설정되지 않았어요.');
      return;
    }
    final generation = ++_generation;
    _emit(CookingCoachPhase.connecting, 'AI 코치를 연결하고 있어요.');

    final client = _clientFactory(
      ConversationCallbacks(
        onDisconnect: (details) {
          if (_isCurrent(generation) && _phase != CookingCoachPhase.stopping) {
            unawaited(_teardown(generation, message: '코치 연결이 끝났어요.'));
          }
        },
        onError: (message, [context]) {
          if (_isCurrent(generation)) {
            unawaited(_teardown(generation, message: 'AI 코치 연결에 문제가 생겼어요.'));
          }
        },
      ),
    );
    _client = client;

    try {
      await client.startSession(
        agentId: agentId,
        overrides: ConversationOverrides(
          agent: AgentOverrides(prompt: buildRecipePrompt(), language: 'ko'),
        ),
      );
      if (!_isCurrent(generation)) {
        return;
      }
      _emit(CookingCoachPhase.live, '코치가 듣고 있어요. 말하는 중에 끼어들어도 돼요.');
    } catch (_) {
      if (_isCurrent(generation)) {
        await _teardown(generation, message: 'AI 코치를 시작하지 못했어요.');
      }
    }
  }

  /// 음성 barge-in이 SDK에 내장돼 있어 탭 가로채기가 필요 없다.
  @override
  void interrupt() {}

  @override
  Future<void> stop() async {
    if (_phase == CookingCoachPhase.idle ||
        _phase == CookingCoachPhase.stopping) {
      return;
    }
    final generation = _generation;
    _emit(CookingCoachPhase.stopping, null);
    await _teardown(generation, message: 'AI 코치를 껐어요.');
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _generation++;
    final client = _client;
    _client = null;
    if (client != null) {
      unawaited(_swallow(client.endSession));
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  Future<void> _teardown(int generation, {String? message}) async {
    if (!_isCurrent(generation)) {
      return;
    }
    _generation++;
    final client = _client;
    _client = null;
    if (client != null) {
      await _swallow(client.endSession);
    }
    if (!_disposed) {
      _emit(CookingCoachPhase.idle, message);
    }
  }

  Future<void> _swallow(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // 정리 실패가 화면 흐름을 막지 않게 한다.
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
