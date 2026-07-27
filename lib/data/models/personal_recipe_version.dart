import 'package:freezed_annotation/freezed_annotation.dart';

part 'personal_recipe_version.freezed.dart';
part 'personal_recipe_version.g.dart';

/// backend `PersonalRecipeVersion`.
/// 피드백 → 조정값 구조화는 AI 미확정이라 `adjustmentPayload.source == 'MOCK'`이다.
@freezed
class PersonalRecipeVersion with _$PersonalRecipeVersion {
  const PersonalRecipeVersion._();

  const factory PersonalRecipeVersion({
    required String id,
    required String userId,
    required String recipeId,
    required int versionNumber,
    required String title,
    String? summary,
    Map<String, dynamic>? adjustmentPayload,
    String? sourceSessionId,
    DateTime? createdAt,
  }) = _PersonalRecipeVersion;

  factory PersonalRecipeVersion.fromJson(Map<String, dynamic> json) =>
      _$PersonalRecipeVersionFromJson(json);

  bool get isMockAdjustment => adjustmentPayload?['source'] == 'MOCK';

  /// 표시용 요약. summary(리뷰 코멘트) → 다음엔 이렇게 메모 순으로 고른다.
  String get adjustmentSummary {
    final note = summary;
    if (note != null && note.trim().isNotEmpty) return note;

    final nextTime = adjustmentPayload?['rawNextTimeNote'];
    if (nextTime is String && nextTime.trim().isNotEmpty) return nextTime;

    return '기록된 조정값 없음';
  }
}
