// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_recipe_version.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PersonalRecipeVersionImpl _$$PersonalRecipeVersionImplFromJson(
  Map<String, dynamic> json,
) => _$PersonalRecipeVersionImpl(
  id: json['id'] as String,
  userId: json['userId'] as String,
  recipeId: json['recipeId'] as String,
  versionNumber: (json['versionNumber'] as num).toInt(),
  title: json['title'] as String,
  summary: json['summary'] as String?,
  adjustmentPayload: json['adjustmentPayload'] as Map<String, dynamic>?,
  sourceSessionId: json['sourceSessionId'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$$PersonalRecipeVersionImplToJson(
  _$PersonalRecipeVersionImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'recipeId': instance.recipeId,
  'versionNumber': instance.versionNumber,
  'title': instance.title,
  'summary': instance.summary,
  'adjustmentPayload': instance.adjustmentPayload,
  'sourceSessionId': instance.sourceSessionId,
  'createdAt': instance.createdAt?.toIso8601String(),
};
