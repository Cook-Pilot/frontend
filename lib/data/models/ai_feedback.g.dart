// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_feedback.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AiFeedbackImpl _$$AiFeedbackImplFromJson(Map<String, dynamic> json) =>
    _$AiFeedbackImpl(
      mock: json['mock'] as bool? ?? false,
      speechText: json['speechText'] as String? ?? '',
      screenText: json['screenText'] as String? ?? '',
      suggestedAction: json['suggestedAction'] == null
          ? null
          : SuggestedAction.fromJson(
              json['suggestedAction'] as Map<String, dynamic>,
            ),
      eventPayload: json['eventPayload'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$AiFeedbackImplToJson(_$AiFeedbackImpl instance) =>
    <String, dynamic>{
      'mock': instance.mock,
      'speechText': instance.speechText,
      'screenText': instance.screenText,
      'suggestedAction': instance.suggestedAction,
      'eventPayload': instance.eventPayload,
    };

_$SuggestedActionImpl _$$SuggestedActionImplFromJson(
  Map<String, dynamic> json,
) => _$SuggestedActionImpl(
  type: json['type'] as String,
  seconds: (json['seconds'] as num?)?.toInt(),
);

Map<String, dynamic> _$$SuggestedActionImplToJson(
  _$SuggestedActionImpl instance,
) => <String, dynamic>{'type': instance.type, 'seconds': instance.seconds};
