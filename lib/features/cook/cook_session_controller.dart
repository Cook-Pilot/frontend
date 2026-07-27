import 'dart:async';
import 'package:cookpilot/core/network/api_exception.dart';
import 'package:cookpilot/data/models/ai_feedback.dart';
import 'package:cookpilot/data/models/cook_session.dart';
import 'package:cookpilot/data/repositories/cook_session_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cook_session_controller.freezed.dart';

@freezed
class CookSessionState with _$CookSessionState {
  const CookSessionState._();

  const factory CookSessionState({
    required CookSession session,
    @Default(0) int remainingSeconds,
    @Default(false) bool timerRunning,
    @Default(false) bool busy,
    AiFeedback? feedback,
  }) = _CookSessionState;

  bool get hasTimer => (session.currentStep?.timerSeconds ?? 0) > 0;
  bool get timerFinished => hasTimer && remainingSeconds == 0;

  String get timerLabel {
    if (!hasTimer) return '--:--';
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// 조리 세션 화면의 상태. 타이머는 클라이언트가 돌리고, 서버에는 이벤트만 기록한다
/// (backend docs/08: "타이머 - 클라이언트 로컬 진행. 서버는 세션 이벤트로만 기록").
class CookSessionController
    extends AutoDisposeFamilyNotifier<CookSessionState, CookSession> {
  Timer? _ticker;

  CookSessionRepository get _repo => ref.read(cookSessionRepositoryProvider);

  @override
  CookSessionState build(CookSession arg) {
    ref.onDispose(() => _ticker?.cancel());
    return CookSessionState(
      session: arg,
      remainingSeconds: arg.currentStep?.timerSeconds ?? 0,
    );
  }

  void toggleTimer() {
    if (!state.hasTimer || state.remainingSeconds == 0) return;

    if (state.timerRunning) {
      _ticker?.cancel();
      state = state.copyWith(timerRunning: false);
      _record(CookEventType.timerPaused, {
        'remainingSeconds': state.remainingSeconds,
      });
      return;
    }

    state = state.copyWith(timerRunning: true);
    _record(CookEventType.timerStarted, {
      'remainingSeconds': state.remainingSeconds,
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = state.remainingSeconds - 1;
      if (left <= 0) {
        timer.cancel();
        state = state.copyWith(remainingSeconds: 0, timerRunning: false);
        _record(CookEventType.timerCompleted, null);
        return;
      }
      state = state.copyWith(remainingSeconds: left);
    });
  }

  /// AI가 제안한 타이머 연장(EXTEND_TIMER)을 적용한다.
  void extendTimer(int seconds) {
    state = state.copyWith(remainingSeconds: state.remainingSeconds + seconds);
    _record(CookEventType.timerExtended, {'seconds': seconds});
  }

  /// POST /cook-sessions/{id}/step
  Future<void> moveStep({required bool next}) async {
    state = state.copyWith(busy: true);
    try {
      final updated = await _repo.moveStep(state.session.id, next: next);
      _ticker?.cancel();
      state = CookSessionState(
        session: updated,
        remainingSeconds: updated.currentStep?.timerSeconds ?? 0,
      );
    } finally {
      if (state.busy) state = state.copyWith(busy: false);
    }
  }

  /// POST /cook-sessions/{id}/complete — 세션이 REVIEW 상태가 된다.
  Future<CookSession> complete() async {
    state = state.copyWith(busy: true);
    try {
      final completed = await _repo.complete(state.session.id);
      _ticker?.cancel();
      state = state.copyWith(session: completed, timerRunning: false);
      return completed;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  /// POST /cook-sessions/{id}/abort
  Future<void> abort() async {
    _ticker?.cancel();
    final aborted = await _repo.abort(state.session.id);
    state = state.copyWith(session: aborted, timerRunning: false);
  }

  /// POST /cook-sessions/{id}/ai-feedback — 서버가 목데이터를 돌려준다.
  Future<void> askAi(String userSpeech) async {
    state = state.copyWith(busy: true);
    try {
      final feedback = await _repo.aiFeedback(state.session.id, userSpeech);
      state = state.copyWith(feedback: feedback);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  /// 이벤트 기록은 조리를 막지 않는다. 실패해도 삼킨다.
  Future<void> _record(String eventType, Map<String, dynamic>? payload) async {
    try {
      await _repo.addEvent(
        state.session.id,
        eventType: eventType,
        stepIndex: state.session.currentStepIndex,
        payload: payload,
      );
    } on ApiException {
      // 기록용 이벤트 — 실패는 무시한다.
    }
  }
}

final cookSessionControllerProvider =
    NotifierProvider.autoDispose
        .family<CookSessionController, CookSessionState, CookSession>(
          CookSessionController.new,
        );
