import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/cooking_setup_snapshot.dart';
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
    this.sessionId,
    this.recipeId,
    required this.recipeTitle,
    required this.servings,
    this.setupSnapshot,
    required this.stepIndex,
    required this.sessionStatus,
    required this.timerOriginalMs,
    required this.timerEffectiveMs,
    required this.timerRemainingMs,
    required this.timerStatus,
    required this.savedAtEpochMs,
    this.timerSecondsByStep = const {},
  });

  final String? sessionId;
  final String? recipeId;
  final String recipeTitle;
  final int servings;
  final CookingSetupSnapshot? setupSnapshot;
  final int stepIndex;
  final String sessionStatus;
  final int timerOriginalMs;
  final int timerEffectiveMs;
  final int timerRemainingMs;
  final String timerStatus;
  final int savedAtEpochMs;
  final Map<int, int> timerSecondsByStep;

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

  PersistedCookingSession copyWith({String? recipeId, String? recipeTitle}) {
    return PersistedCookingSession(
      sessionId: sessionId,
      recipeId: recipeId ?? this.recipeId,
      recipeTitle: recipeTitle ?? this.recipeTitle,
      servings: servings,
      setupSnapshot: setupSnapshot,
      stepIndex: stepIndex,
      sessionStatus: sessionStatus,
      timerOriginalMs: timerOriginalMs,
      timerEffectiveMs: timerEffectiveMs,
      timerRemainingMs: timerRemainingMs,
      timerStatus: timerStatus,
      savedAtEpochMs: savedAtEpochMs,
      timerSecondsByStep: timerSecondsByStep,
    );
  }

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'recipeTitle': recipeTitle,
      'servings': servings,
      'stepIndex': stepIndex,
      'sessionStatus': sessionStatus,
      'timerOriginalMs': timerOriginalMs,
      'timerEffectiveMs': timerEffectiveMs,
      'timerRemainingMs': timerRemainingMs,
      'timerStatus': timerStatus,
      'savedAtEpochMs': savedAtEpochMs,
      'timerSecondsByStep': timerSecondsByStep.map(
        (stepIndex, seconds) => MapEntry(stepIndex.toString(), seconds),
      ),
    };
    if (sessionId != null) {
      json['sessionId'] = sessionId!;
    }
    if (recipeId != null) {
      json['recipeId'] = recipeId!;
    }
    if (setupSnapshot != null) {
      json['setupSnapshot'] = setupSnapshot!.toJson();
    }
    return json;
  }

  static PersistedCookingSession? fromJson(Map<String, Object?> json) {
    final sessionId = json['sessionId'];
    if (sessionId != null && sessionId is! String) {
      return null;
    }
    final recipeId = json['recipeId'];
    if (recipeId != null && recipeId is! String) {
      return null;
    }
    final setupSnapshotValue = json['setupSnapshot'];
    CookingSetupSnapshot? setupSnapshot;
    if (setupSnapshotValue is Map) {
      setupSnapshot = CookingSetupSnapshot.fromJson(
        Map<String, Object?>.from(setupSnapshotValue),
      );
    }
    // 실행 설정만 손상된 경우 단계·타이머 세션은 유지한다.
    // 홈에서 recipeId 기반 기본 레시피로 다시 조회할 수 있다.
    final timerSecondsByStep = <int, int>{};
    final timerValues = json['timerSecondsByStep'];
    if (timerValues != null) {
      if (timerValues is! Map) return null;
      for (final MapEntry(key: key, value: value) in timerValues.entries) {
        final stepIndex = int.tryParse(key.toString());
        if (stepIndex == null || value is! int || value < 0) return null;
        timerSecondsByStep[stepIndex] = value;
      }
    }
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
        sessionId: sessionId as String?,
        recipeId: recipeId as String?,
        recipeTitle: recipeTitle,
        servings: servings,
        setupSnapshot: setupSnapshot,
        stepIndex: stepIndex,
        sessionStatus: sessionStatus,
        timerOriginalMs: timerOriginalMs,
        timerEffectiveMs: timerEffectiveMs,
        timerRemainingMs: timerRemainingMs,
        timerStatus: timerStatus,
        savedAtEpochMs: savedAtEpochMs,
        timerSecondsByStep: Map.unmodifiable(timerSecondsByStep),
      );
    }
    return null;
  }
}

abstract interface class CookingSessionGateway {
  Future<void> save(PersistedCookingSession session);

  Future<PersistedCookingSession?> load();

  Future<void> clear();
}

typedef CookingSessionPreferencesLoader = Future<SharedPreferences> Function();

/// 진행 중 조리 세션을 shared_preferences에 하나만 보관한다.
final class CookingSessionStore implements CookingSessionGateway {
  const CookingSessionStore({this.preferencesLoader});

  static const _key = 'cookpilot.active_cooking_session.v1';

  final CookingSessionPreferencesLoader? preferencesLoader;

  Future<SharedPreferences> _loadPreferences() =>
      (preferencesLoader ?? SharedPreferences.getInstance)();

  @override
  Future<void> save(PersistedCookingSession session) async {
    final prefs = await _loadPreferences();
    Object? writeError;
    StackTrace? writeStackTrace;
    try {
      final saved = await prefs.setString(_key, jsonEncode(session.toJson()));
      if (saved) {
        return;
      }
    } on Object catch (error, stackTrace) {
      writeError = error;
      writeStackTrace = stackTrace;
    }

    // SharedPreferences는 플랫폼 저장 결과보다 먼저 메모리 캐시를 갱신한다.
    // 실패 뒤 디스크 상태를 다시 읽어 미저장 세션이 복구값처럼 보이지 않게 한다.
    await prefs.reload();
    if (writeError != null) {
      Error.throwWithStackTrace(writeError, writeStackTrace!);
    }
    throw StateError('진행 중 조리 세션을 로컬에 저장하지 못했습니다.');
  }

  /// 저장된 세션이 없거나 값이 손상됐으면 null. 손상값은 함께 정리한다.
  /// 저장소를 열지 못한 오류는 복구 UI가 안내할 수 있도록 호출자에게 전달한다.
  @override
  Future<PersistedCookingSession?> load() async {
    final prefs = await _loadPreferences();
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
    await _removeBestEffort(prefs);
    return null;
  }

  @override
  Future<void> clear() async {
    final prefs = await _loadPreferences();
    Object? removeError;
    StackTrace? removeStackTrace;
    try {
      final removed = await prefs.remove(_key);
      if (removed) {
        return;
      }
    } on Object catch (error, stackTrace) {
      removeError = error;
      removeStackTrace = stackTrace;
    }

    // remove도 플랫폼 결과보다 먼저 캐시를 지우므로 실패 시 실제 저장값을 복원한다.
    await prefs.reload();
    if (removeError != null) {
      Error.throwWithStackTrace(removeError, removeStackTrace!);
    }
    throw StateError('진행 중 조리 세션을 로컬에서 정리하지 못했습니다.');
  }

  static Future<void> _removeBestEffort(SharedPreferences prefs) async {
    try {
      final removed = await prefs.remove(_key);
      if (removed) {
        return;
      }
    } on Object {
      // 손상값은 반환하지 않되, 아래 reload로 다음 load의 정리 재시도를 보장한다.
    }
    try {
      await prefs.reload();
    } on Object {
      // 손상값 정리는 best effort다. 다음 앱 시작이나 load에서 다시 시도한다.
    }
  }
}
