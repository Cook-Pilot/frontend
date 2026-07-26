import 'package:flutter/foundation.dart';

import '../../recipe/domain/recipe.dart';

enum CookingRecipeSource { base, personal }

@immutable
final class CookingSetupIngredient {
  const CookingSetupIngredient({
    this.originalIngredientId,
    required this.originalName,
    required this.name,
    required this.amount,
    this.baselineAmount,
    required this.unit,
    required this.isRequired,
    this.omitted = false,
  });

  final String? originalIngredientId;
  final String originalName;
  final String name;
  final double? amount;
  final double? baselineAmount;
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
      final originalIngredientId = json['originalIngredientId'];
      final omittedValue = json['omitted'];
      if (amountValue != null && amountValue is! num) return null;
      if (baselineAmountValue != null && baselineAmountValue is! num) {
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
        baselineAmount:
            (baselineAmountValue as num?)?.toDouble() ??
            amountValue?.toDouble(),
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
