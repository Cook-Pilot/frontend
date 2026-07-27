// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecipeSummaryImpl _$$RecipeSummaryImplFromJson(Map<String, dynamic> json) =>
    _$RecipeSummaryImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      hasPersonalVersion: json['hasPersonalVersion'] as bool? ?? false,
      latestPersonalVersionId: json['latestPersonalVersionId'] as String?,
    );

Map<String, dynamic> _$$RecipeSummaryImplToJson(_$RecipeSummaryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'hasPersonalVersion': instance.hasPersonalVersion,
      'latestPersonalVersionId': instance.latestPersonalVersionId,
    };

_$RecipeImpl _$$RecipeImplFromJson(Map<String, dynamic> json) => _$RecipeImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String? ?? '',
  ingredients:
      (json['ingredients'] as List<dynamic>?)
          ?.map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <RecipeIngredient>[],
  steps:
      (json['steps'] as List<dynamic>?)
          ?.map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <RecipeStep>[],
);

Map<String, dynamic> _$$RecipeImplToJson(_$RecipeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'ingredients': instance.ingredients,
      'steps': instance.steps,
    };

_$RecipeIngredientImpl _$$RecipeIngredientImplFromJson(
  Map<String, dynamic> json,
) => _$RecipeIngredientImpl(
  name: json['name'] as String,
  amount: (json['amount'] as num?)?.toDouble(),
  unit: json['unit'] as String?,
  isRequired: json['required'] as bool? ?? false,
);

Map<String, dynamic> _$$RecipeIngredientImplToJson(
  _$RecipeIngredientImpl instance,
) => <String, dynamic>{
  'name': instance.name,
  'amount': instance.amount,
  'unit': instance.unit,
  'required': instance.isRequired,
};

_$RecipeStepImpl _$$RecipeStepImplFromJson(Map<String, dynamic> json) =>
    _$RecipeStepImpl(
      stepIndex: (json['stepIndex'] as num).toInt(),
      instruction: json['instruction'] as String,
      timerSeconds: (json['timerSeconds'] as num?)?.toInt(),
      cautionNote: json['cautionNote'] as String?,
    );

Map<String, dynamic> _$$RecipeStepImplToJson(_$RecipeStepImpl instance) =>
    <String, dynamic>{
      'stepIndex': instance.stepIndex,
      'instruction': instance.instruction,
      'timerSeconds': instance.timerSeconds,
      'cautionNote': instance.cautionNote,
    };
