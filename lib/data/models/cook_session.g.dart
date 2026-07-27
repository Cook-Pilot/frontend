// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cook_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CookSessionImpl _$$CookSessionImplFromJson(Map<String, dynamic> json) =>
    _$CookSessionImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      recipeId: json['recipeId'] as String,
      personalVersionId: json['personalVersionId'] as String?,
      recipeTitle: json['recipeTitle'] as String,
      status: $enumDecode(_$SessionStatusEnumMap, json['status']),
      currentStepIndex: (json['currentStepIndex'] as num).toInt(),
      currentStep: json['currentStep'] == null
          ? null
          : RecipeStep.fromJson(json['currentStep'] as Map<String, dynamic>),
      totalSteps: (json['totalSteps'] as num).toInt(),
      steps:
          (json['steps'] as List<dynamic>?)
              ?.map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <RecipeStep>[],
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      abortedAt: json['abortedAt'] == null
          ? null
          : DateTime.parse(json['abortedAt'] as String),
    );

Map<String, dynamic> _$$CookSessionImplToJson(_$CookSessionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'recipeId': instance.recipeId,
      'personalVersionId': instance.personalVersionId,
      'recipeTitle': instance.recipeTitle,
      'status': _$SessionStatusEnumMap[instance.status]!,
      'currentStepIndex': instance.currentStepIndex,
      'currentStep': instance.currentStep,
      'totalSteps': instance.totalSteps,
      'steps': instance.steps,
      'startedAt': instance.startedAt?.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'abortedAt': instance.abortedAt?.toIso8601String(),
    };

const _$SessionStatusEnumMap = {
  SessionStatus.ready: 'READY',
  SessionStatus.cooking: 'COOKING',
  SessionStatus.paused: 'PAUSED',
  SessionStatus.review: 'REVIEW',
  SessionStatus.completed: 'COMPLETED',
  SessionStatus.aborted: 'ABORTED',
};

_$CookSessionEventImpl _$$CookSessionEventImplFromJson(
  Map<String, dynamic> json,
) => _$CookSessionEventImpl(
  id: json['id'] as String,
  cookSessionId: json['cookSessionId'] as String,
  eventType: json['eventType'] as String,
  stepIndex: (json['stepIndex'] as num?)?.toInt(),
  source: json['source'] as String?,
  payload: json['payload'] as Map<String, dynamic>?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$$CookSessionEventImplToJson(
  _$CookSessionEventImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'cookSessionId': instance.cookSessionId,
  'eventType': instance.eventType,
  'stepIndex': instance.stepIndex,
  'source': instance.source,
  'payload': instance.payload,
  'createdAt': instance.createdAt?.toIso8601String(),
};
