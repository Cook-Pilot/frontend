import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_feedback.freezed.dart';
part 'ai_feedback.g.dart';

/// backend `AiFeedbackResponse` (docs/06 §9 구조).
/// AI 파트 미확정 — 서버는 `mock: true` 고정 응답을 준다.
@freezed
class AiFeedback with _$AiFeedback {
  const factory AiFeedback({
    @Default(false) bool mock,
    @Default('') String speechText,
    @Default('') String screenText,
    SuggestedAction? suggestedAction,
    Map<String, dynamic>? eventPayload,
  }) = _AiFeedback;

  factory AiFeedback.fromJson(Map<String, dynamic> json) =>
      _$AiFeedbackFromJson(json);
}

@freezed
class SuggestedAction with _$SuggestedAction {
  const SuggestedAction._();

  const factory SuggestedAction({required String type, int? seconds}) =
      _SuggestedAction;

  factory SuggestedAction.fromJson(Map<String, dynamic> json) =>
      _$SuggestedActionFromJson(json);

  /// 목 응답은 EXTEND_TIMER를 돌려준다. 타이머 연장 버튼을 띄울지 판단.
  bool get extendsTimer => type == 'EXTEND_TIMER' && (seconds ?? 0) > 0;
}
