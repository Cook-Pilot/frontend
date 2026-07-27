import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipe.freezed.dart';
part 'recipe.g.dart';

/// GET /api/v1/recipes 의 항목. backend `RecipeSummaryResponse`.
@freezed
class RecipeSummary with _$RecipeSummary {
  const factory RecipeSummary({
    required String id,
    required String title,
    @Default('') String description,
    @Default(false) bool hasPersonalVersion,
    String? latestPersonalVersionId,
  }) = _RecipeSummary;

  factory RecipeSummary.fromJson(Map<String, dynamic> json) =>
      _$RecipeSummaryFromJson(json);
}

/// GET /api/v1/recipes/{id}. backend `Recipe`.
@freezed
class Recipe with _$Recipe {
  const Recipe._();

  const factory Recipe({
    required String id,
    required String title,
    @Default('') String description,
    @Default(<RecipeIngredient>[]) List<RecipeIngredient> ingredients,
    @Default(<RecipeStep>[]) List<RecipeStep> steps,
  }) = _Recipe;

  factory Recipe.fromJson(Map<String, dynamic> json) => _$RecipeFromJson(json);

  /// 서버는 단계별 timerSeconds만 준다. 총 예상 시간은 클라이언트가 합산한다.
  int get estimatedMinutes {
    final seconds = steps.fold<int>(0, (sum, s) => sum + (s.timerSeconds ?? 0));
    return seconds == 0 ? 0 : (seconds / 60).ceil();
  }
}

@freezed
class RecipeIngredient with _$RecipeIngredient {
  const RecipeIngredient._();

  const factory RecipeIngredient({
    required String name,
    double? amount,
    String? unit,
    // `required`는 Dart 예약어라 필드명을 바꾸고 JSON 키만 맞춘다.
    @JsonKey(name: 'required') @Default(false) bool isRequired,
  }) = _RecipeIngredient;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      _$RecipeIngredientFromJson(json);

  String get displayAmount => scaledAmount(1);

  /// 인분 배율을 적용한 표시값. 예: 2인분 기준 500ml → 3인분이면 750ml.
  String scaledAmount(double factor) {
    if (amount == null) return unit ?? '';
    final value = amount! * factor;
    final text = value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return (unit == null || unit!.isEmpty) ? text : '$text$unit';
  }
}

@freezed
class RecipeStep with _$RecipeStep {
  const RecipeStep._();

  const factory RecipeStep({
    required int stepIndex,
    required String instruction,
    int? timerSeconds,
    String? cautionNote,
  }) = _RecipeStep;

  factory RecipeStep.fromJson(Map<String, dynamic> json) =>
      _$RecipeStepFromJson(json);

  bool get hasTimer => (timerSeconds ?? 0) > 0;

  String get timerLabel {
    final seconds = timerSeconds ?? 0;
    if (seconds == 0) return '';
    if (seconds < 60) return '$seconds초';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return rest == 0 ? '$minutes분' : '$minutes분 $rest초';
  }
}
