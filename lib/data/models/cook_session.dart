import 'package:cookpilot/data/models/recipe.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cook_session.freezed.dart';
part 'cook_session.g.dart';

/// backend `SessionStatus`.
enum SessionStatus {
  @JsonValue('READY')
  ready,
  @JsonValue('COOKING')
  cooking,
  @JsonValue('PAUSED')
  paused,
  @JsonValue('REVIEW')
  review,
  @JsonValue('COMPLETED')
  completed,
  @JsonValue('ABORTED')
  aborted;

  String get label => switch (this) {
    SessionStatus.ready => '준비',
    SessionStatus.cooking => '조리 중',
    SessionStatus.paused => '일시정지',
    SessionStatus.review => '리뷰 대기',
    SessionStatus.completed => '완료',
    SessionStatus.aborted => '중단',
  };
}

/// backend `CookSessionResponse`.
@freezed
class CookSession with _$CookSession {
  const CookSession._();

  const factory CookSession({
    required String id,
    required String userId,
    required String recipeId,
    String? personalVersionId,
    required String recipeTitle,
    required SessionStatus status,
    required int currentStepIndex,
    RecipeStep? currentStep,
    required int totalSteps,
    @Default(<RecipeStep>[]) List<RecipeStep> steps,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? abortedAt,
  }) = _CookSession;

  factory CookSession.fromJson(Map<String, dynamic> json) =>
      _$CookSessionFromJson(json);

  bool get isFirstStep => currentStepIndex <= 0;
  bool get isLastStep => currentStepIndex >= totalSteps - 1;
  bool get isPersonalized => personalVersionId != null;

  Duration? get elapsed =>
      startedAt == null ? null : DateTime.now().difference(startedAt!);
}

/// backend `CookSessionEvent`.
@freezed
class CookSessionEvent with _$CookSessionEvent {
  const factory CookSessionEvent({
    required String id,
    required String cookSessionId,
    required String eventType,
    int? stepIndex,
    String? source,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
  }) = _CookSessionEvent;

  factory CookSessionEvent.fromJson(Map<String, dynamic> json) =>
      _$CookSessionEventFromJson(json);
}

/// 세션 이벤트 타입. 서버는 자유 문자열을 받지만 클라이언트 오타를 막는다.
class CookEventType {
  const CookEventType._();

  static const timerStarted = 'TIMER_STARTED';
  static const timerPaused = 'TIMER_PAUSED';
  static const timerCompleted = 'TIMER_COMPLETED';
  static const timerExtended = 'TIMER_EXTENDED';
  static const servingsChanged = 'SERVINGS_CHANGED';
}
