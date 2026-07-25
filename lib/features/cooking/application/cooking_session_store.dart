import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/cooking_session_state.dart';
import 'timer_controller.dart';

/// 로컬에 저장하는 진행 중 조리 세션 스냅샷.
///
/// 타이머는 매 틱을 저장하지 않는다. 상태가 바뀐 시점의 남은 시간과 저장
/// 시각(벽시계)만 저장하고, 복원할 때 흐른 시간을 빼서 재계산한다. 앱이
/// 강제 종료돼 있던 시간까지 반영된다.
@immutable
final class PersistedCookingSession {
  const PersistedCookingSession({
    required this.recipeTitle,
    required this.servings,
    required this.stepIndex,
    required this.sessionStatus,
    required this.timerOriginalMs,
    required this.timerEffectiveMs,
    required this.timerRemainingMs,
    required this.timerStatus,
    required this.savedAtEpochMs,
  });

  final String recipeTitle;
  final int servings;
  final int stepIndex;
  final String sessionStatus;
  final int timerOriginalMs;
  final int timerEffectiveMs;
  final int timerRemainingMs;
  final String timerStatus;
  final int savedAtEpochMs;

  /// 조리 중이거나 일시정지 상태만 복원 대상이다.
  bool get isResumable =>
      sessionStatus == CookingSessionStatus.cooking.name ||
      sessionStatus == CookingSessionStatus.paused.name;

  /// [now] 기준으로 남은 시간을 재계산한 타이머 스냅샷.
  /// 실행 중이던 타이머는 저장 이후 흐른 벽시계 시간을 차감한다.
  /// 음수·초과값 보정은 [LocalTimerController.restore]가 담당한다.
  StepTimerSnapshot timerSnapshotAt(DateTime now) {
    final status = TimerStatus.values.asNameMap()[timerStatus];
    var remaining = Duration(milliseconds: timerRemainingMs);
    if (status == TimerStatus.running) {
      final sinceSaved = now.difference(
        DateTime.fromMillisecondsSinceEpoch(savedAtEpochMs),
      );
      if (sinceSaved > Duration.zero) {
        remaining -= sinceSaved;
      }
    }
    return StepTimerSnapshot(
      originalDuration: Duration(milliseconds: timerOriginalMs),
      effectiveDuration: Duration(milliseconds: timerEffectiveMs),
      remaining: remaining,
      status: status ?? TimerStatus.idle,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'recipeTitle': recipeTitle,
    'servings': servings,
    'stepIndex': stepIndex,
    'sessionStatus': sessionStatus,
    'timerOriginalMs': timerOriginalMs,
    'timerEffectiveMs': timerEffectiveMs,
    'timerRemainingMs': timerRemainingMs,
    'timerStatus': timerStatus,
    'savedAtEpochMs': savedAtEpochMs,
  };

  static PersistedCookingSession? fromJson(Map<String, Object?> json) {
    if (json case {
      'recipeTitle': final String recipeTitle,
      'servings': final int servings,
      'stepIndex': final int stepIndex,
      'sessionStatus': final String sessionStatus,
      'timerOriginalMs': final int timerOriginalMs,
      'timerEffectiveMs': final int timerEffectiveMs,
      'timerRemainingMs': final int timerRemainingMs,
      'timerStatus': final String timerStatus,
      'savedAtEpochMs': final int savedAtEpochMs,
    }) {
      return PersistedCookingSession(
        recipeTitle: recipeTitle,
        servings: servings,
        stepIndex: stepIndex,
        sessionStatus: sessionStatus,
        timerOriginalMs: timerOriginalMs,
        timerEffectiveMs: timerEffectiveMs,
        timerRemainingMs: timerRemainingMs,
        timerStatus: timerStatus,
        savedAtEpochMs: savedAtEpochMs,
      );
    }
    return null;
  }
}

/// 진행 중 조리 세션을 shared_preferences에 하나만 보관한다.
final class CookingSessionStore {
  const CookingSessionStore();

  static const _key = 'cookpilot.active_cooking_session.v1';

  Future<void> save(PersistedCookingSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(session.toJson()));
  }

  /// 저장된 세션이 없거나 값이 손상됐으면 null. 손상값은 함께 정리한다.
  Future<PersistedCookingSession?> load() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
    final raw = prefs.getString(_key);
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        final session = PersistedCookingSession.fromJson(decoded);
        if (session != null) {
          return session;
        }
      }
    } catch (_) {
      // 손상된 JSON은 아래에서 제거한다.
    }
    await prefs.remove(_key);
    return null;
  }

  Future<void> clear() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    await prefs.remove(_key);
  }
}
