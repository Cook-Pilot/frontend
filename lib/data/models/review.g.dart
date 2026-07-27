// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PostCookReviewImpl _$$PostCookReviewImplFromJson(Map<String, dynamic> json) =>
    _$PostCookReviewImpl(
      id: json['id'] as String,
      cookSessionId: json['cookSessionId'] as String,
      userId: json['userId'] as String,
      recipeId: json['recipeId'] as String,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      nextTimeNote: json['nextTimeNote'] as String?,
      createdPersonalVersionId: json['createdPersonalVersionId'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$PostCookReviewImplToJson(
  _$PostCookReviewImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'cookSessionId': instance.cookSessionId,
  'userId': instance.userId,
  'recipeId': instance.recipeId,
  'rating': instance.rating,
  'comment': instance.comment,
  'nextTimeNote': instance.nextTimeNote,
  'createdPersonalVersionId': instance.createdPersonalVersionId,
  'createdAt': instance.createdAt?.toIso8601String(),
};
