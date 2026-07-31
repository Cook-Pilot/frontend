import 'package:flutter/foundation.dart';

import '../../recipe/domain/recipe.dart';

enum CookingRecipeSource { base, personal }

/// 원본 레시피와 서버가 합성한 개인 버전을 비교해 원본 기준 누적 setup 상태를 만든다.
///
/// 개인 버전 응답은 REMOVE된 원본 재료를 포함하지 않으므로 원본 목록에서 빠진 항목을
/// omitted 상태로 되살린다. 원본 ID가 없는 합성 항목은 개인 버전의 ADD로 보존한다.
List<CookingSetupIngredient> buildOriginalAnchoredSetupIngredients({
  required List<Ingredient> baseIngredients,
  required List<Ingredient> composedIngredients,
  required double scale,
}) {
  if (!scale.isFinite || scale <= 0) {
    throw ArgumentError.value(scale, 'scale', '0보다 큰 유한값이어야 합니다.');
  }

  final baseByOriginalId = <String, Ingredient>{};
  for (final ingredient in baseIngredients) {
    final originalIngredientId = ingredient.originalIngredientId;
    if (originalIngredientId == null || originalIngredientId.isEmpty) {
      throw ArgumentError.value(
        originalIngredientId,
        'baseIngredients',
        '원본 재료에는 originalIngredientId가 필요합니다.',
      );
    }
    if (baseByOriginalId.containsKey(originalIngredientId)) {
      throw ArgumentError.value(
        originalIngredientId,
        'baseIngredients',
        '원본 재료 ID가 중복되었습니다.',
      );
    }
    baseByOriginalId[originalIngredientId] = ingredient;
  }
  final matchedBaseIds = <String>{};
  final result = <CookingSetupIngredient>[];

  for (final ingredient in composedIngredients) {
    final originalIngredientId = ingredient.originalIngredientId;
    Ingredient? baseIngredient;
    if (originalIngredientId != null) {
      baseIngredient = baseByOriginalId[originalIngredientId];
      if (baseIngredient == null) {
        throw ArgumentError.value(
          originalIngredientId,
          'composedIngredients',
          '원본 레시피에 없는 재료를 참조합니다.',
        );
      }
      if (!matchedBaseIds.add(originalIngredientId)) {
        throw ArgumentError.value(
          originalIngredientId,
          'composedIngredients',
          '합성 재료 ID가 중복되었습니다.',
        );
      }
    }
    result.add(
      CookingSetupIngredient(
        originalIngredientId: originalIngredientId,
        originalName: baseIngredient?.name ?? ingredient.name,
        name: ingredient.name,
        amount: _scaledAmount(ingredient.amount, scale),
        baselineAmount: _scaledAmount(
          baseIngredient == null ? ingredient.amount : baseIngredient.amount,
          scale,
        ),
        baselineUnit: baseIngredient?.unit ?? ingredient.unit,
        baselineIsRequired: baseIngredient?.isRequired ?? ingredient.isRequired,
        unit: ingredient.unit,
        isRequired: ingredient.isRequired,
      ),
    );
  }

  for (final ingredient in baseIngredients) {
    final originalIngredientId = ingredient.originalIngredientId;
    if (matchedBaseIds.contains(originalIngredientId)) {
      continue;
    }
    final amount = _scaledAmount(ingredient.amount, scale);
    result.add(
      CookingSetupIngredient(
        originalIngredientId: originalIngredientId,
        originalName: ingredient.name,
        name: ingredient.name,
        amount: amount,
        baselineAmount: amount,
        baselineUnit: ingredient.unit,
        baselineIsRequired: ingredient.isRequired,
        unit: ingredient.unit,
        isRequired: ingredient.isRequired,
        omitted: true,
      ),
    );
  }

  return List<CookingSetupIngredient>.unmodifiable(result);
}

double? _scaledAmount(double? amount, double scale) {
  return amount == null ? null : amount * scale;
}

@immutable
final class CookingSetupIngredient {
  const CookingSetupIngredient({
    this.originalIngredientId,
    required this.originalName,
    required this.name,
    required this.amount,
    this.baselineAmount,
    this.baselineUnit,
    this.baselineIsRequired,
    required this.unit,
    required this.isRequired,
    this.omitted = false,
  });

  final String? originalIngredientId;
  final String originalName;
  final String name;
  final double? amount;
  final double? baselineAmount;
  final String? baselineUnit;
  final bool? baselineIsRequired;
  final String unit;
  final bool isRequired;
  final bool omitted;

  bool get isSubstituted => originalName != name;

  Map<String, Object?> toJson() => {
    'originalIngredientId': originalIngredientId,
    'originalName': originalName,
    'name': name,
    'amount': amount,
    'baselineAmount': baselineAmount,
    'baselineUnit': baselineUnit,
    'baselineIsRequired': baselineIsRequired,
    'unit': unit,
    'isRequired': isRequired,
    'omitted': omitted,
  };

  static CookingSetupIngredient? fromJson(Map<String, Object?> json) {
    if (json case {
      'originalName': final String originalName,
      'name': final String name,
      'unit': final String unit,
      'isRequired': final bool isRequired,
    }) {
      final amountValue = json['amount'];
      final baselineAmountValue = json['baselineAmount'];
      final baselineUnitValue = json['baselineUnit'];
      final baselineIsRequiredValue = json['baselineIsRequired'];
      final originalIngredientId = json['originalIngredientId'];
      final omittedValue = json['omitted'];
      if (amountValue != null && amountValue is! num) return null;
      if (baselineAmountValue != null && baselineAmountValue is! num) {
        return null;
      }
      if (baselineUnitValue != null && baselineUnitValue is! String) {
        return null;
      }
      if (baselineIsRequiredValue != null && baselineIsRequiredValue is! bool) {
        return null;
      }
      if (originalIngredientId != null && originalIngredientId is! String) {
        return null;
      }
      if (omittedValue != null && omittedValue is! bool) return null;
      return CookingSetupIngredient(
        originalIngredientId: originalIngredientId as String?,
        originalName: originalName,
        name: name,
        amount: (amountValue as num?)?.toDouble(),
        baselineAmount: json.containsKey('baselineAmount')
            ? (baselineAmountValue as num?)?.toDouble()
            : amountValue?.toDouble(),
        baselineUnit: baselineUnitValue as String?,
        baselineIsRequired: baselineIsRequiredValue as bool?,
        unit: unit,
        isRequired: isRequired,
        omitted: omittedValue as bool? ?? false,
      );
    }
    return null;
  }
}

@immutable
final class CookingSetupStep {
  const CookingSetupStep({
    this.originalStepId,
    required this.stepIndex,
    required this.instruction,
    required this.timerSeconds,
    required this.cautionNote,
    required this.imageUrl,
  });

  final String? originalStepId;
  final int stepIndex;
  final String instruction;
  final int? timerSeconds;
  final String? cautionNote;
  final String imageUrl;

  Map<String, Object?> toJson() => {
    'originalStepId': originalStepId,
    'stepIndex': stepIndex,
    'instruction': instruction,
    'timerSeconds': timerSeconds,
    'cautionNote': cautionNote,
    'imageUrl': imageUrl,
  };

  static CookingSetupStep? fromJson(Map<String, Object?> json) {
    if (json case {
      'stepIndex': final int stepIndex,
      'instruction': final String instruction,
      'imageUrl': final String imageUrl,
    }) {
      final timerSeconds = json['timerSeconds'];
      final cautionNote = json['cautionNote'];
      final originalStepId = json['originalStepId'];
      if (timerSeconds != null && timerSeconds is! int) return null;
      if (cautionNote != null && cautionNote is! String) return null;
      if (originalStepId != null && originalStepId is! String) return null;
      return CookingSetupStep(
        originalStepId: originalStepId as String?,
        stepIndex: stepIndex,
        instruction: instruction,
        timerSeconds: timerSeconds as int?,
        cautionNote: cautionNote as String?,
        imageUrl: imageUrl,
      );
    }
    return null;
  }
}

/// 조리 시작 버튼을 누른 시점의 최종 실행 레시피.
///
/// 원본 레시피나 개인 버전이 이후 변경돼도 진행 중인 조리는 이 값을 사용한다.
@immutable
final class CookingSetupSnapshot {
  static const currentSchemaVersion = 1;

  CookingSetupSnapshot({
    required this.recipeId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.baseServings,
    required this.targetServings,
    required this.source,
    required this.personalVersionId,
    required List<CookingSetupIngredient> ingredients,
    required List<CookingSetupStep> steps,
  }) : ingredients = List.unmodifiable(ingredients),
       steps = List.unmodifiable(steps);

  final String recipeId;
  final String title;
  final String description;
  final String imageUrl;
  final double baseServings;
  final int targetServings;
  final CookingRecipeSource source;
  final String? personalVersionId;
  final List<CookingSetupIngredient> ingredients;
  final List<CookingSetupStep> steps;

  /// 이미 [targetServings] 기준으로 수량 조정이 끝난 조리 실행용 레시피를 만든다.
  ///
  /// 카탈로그의 개인 버전 보유 여부는 실행 정보가 아니므로 포함하지 않는다.
  Recipe toExecutionRecipe() {
    return Recipe(
      id: recipeId,
      title: title,
      description: description,
      baseServings: targetServings.toDouble(),
      imageUrl: imageUrl,
      ingredients: ingredients
          .where((ingredient) => !ingredient.omitted)
          .map(
            (ingredient) => Ingredient(
              originalIngredientId: ingredient.originalIngredientId,
              name: ingredient.name,
              amount: ingredient.amount,
              unit: ingredient.unit,
              isRequired: ingredient.isRequired,
            ),
          )
          .toList(growable: false),
      steps: steps
          .map(
            (step) => CookStep(
              originalStepId: step.originalStepId,
              stepIndex: step.stepIndex,
              instruction: step.instruction,
              timerSeconds: step.timerSeconds,
              cautionNote: step.cautionNote,
              imageUrl: step.imageUrl,
            ),
          )
          .toList(growable: false),
      hasPersonalVersion: false,
      latestPersonalVersionId: null,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'recipeId': recipeId,
    'title': title,
    'description': description,
    'imageUrl': imageUrl,
    'baseServings': baseServings,
    'targetServings': targetServings,
    'source': source.name,
    'personalVersionId': personalVersionId,
    'ingredients': ingredients
        .map((ingredient) => ingredient.toJson())
        .toList(growable: false),
    'steps': steps.map((step) => step.toJson()).toList(growable: false),
  };

  static CookingSetupSnapshot? fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != null &&
        (schemaVersion is! int ||
            schemaVersion < 1 ||
            schemaVersion > currentSchemaVersion)) {
      return null;
    }
    if (json case {
      'recipeId': final String recipeId,
      'title': final String title,
      'description': final String description,
      'imageUrl': final String imageUrl,
      'targetServings': final int targetServings,
      'source': final String sourceName,
      'ingredients': final List<Object?> ingredientValues,
      'steps': final List<Object?> stepValues,
    }) {
      final baseServingsValue = json['baseServings'];
      final personalVersionId = json['personalVersionId'];
      if (baseServingsValue is! num ||
          baseServingsValue <= 0 ||
          targetServings < 1 ||
          (personalVersionId != null && personalVersionId is! String)) {
        return null;
      }
      final source = CookingRecipeSource.values.asNameMap()[sourceName];
      if (source == null) return null;

      final ingredients = <CookingSetupIngredient>[];
      for (final value in ingredientValues) {
        if (value is! Map) return null;
        final ingredient = CookingSetupIngredient.fromJson(
          Map<String, Object?>.from(value),
        );
        if (ingredient == null) return null;
        ingredients.add(ingredient);
      }

      final steps = <CookingSetupStep>[];
      for (final value in stepValues) {
        if (value is! Map) return null;
        final step = CookingSetupStep.fromJson(
          Map<String, Object?>.from(value),
        );
        if (step == null) return null;
        steps.add(step);
      }
      if (steps.isEmpty) return null;

      return CookingSetupSnapshot(
        recipeId: recipeId,
        title: title,
        description: description,
        imageUrl: imageUrl,
        baseServings: baseServingsValue.toDouble(),
        targetServings: targetServings,
        source: source,
        personalVersionId: personalVersionId as String?,
        ingredients: ingredients,
        steps: steps,
      );
    }
    return null;
  }
}
