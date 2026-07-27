// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PostCookReview _$PostCookReviewFromJson(Map<String, dynamic> json) {
  return _PostCookReview.fromJson(json);
}

/// @nodoc
mixin _$PostCookReview {
  String get id => throw _privateConstructorUsedError;
  String get cookSessionId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get recipeId => throw _privateConstructorUsedError;
  int get rating => throw _privateConstructorUsedError;
  String? get comment => throw _privateConstructorUsedError;
  String? get nextTimeNote => throw _privateConstructorUsedError;
  String? get createdPersonalVersionId => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this PostCookReview to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PostCookReview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PostCookReviewCopyWith<PostCookReview> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PostCookReviewCopyWith<$Res> {
  factory $PostCookReviewCopyWith(
    PostCookReview value,
    $Res Function(PostCookReview) then,
  ) = _$PostCookReviewCopyWithImpl<$Res, PostCookReview>;
  @useResult
  $Res call({
    String id,
    String cookSessionId,
    String userId,
    String recipeId,
    int rating,
    String? comment,
    String? nextTimeNote,
    String? createdPersonalVersionId,
    DateTime? createdAt,
  });
}

/// @nodoc
class _$PostCookReviewCopyWithImpl<$Res, $Val extends PostCookReview>
    implements $PostCookReviewCopyWith<$Res> {
  _$PostCookReviewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PostCookReview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? cookSessionId = null,
    Object? userId = null,
    Object? recipeId = null,
    Object? rating = null,
    Object? comment = freezed,
    Object? nextTimeNote = freezed,
    Object? createdPersonalVersionId = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            cookSessionId: null == cookSessionId
                ? _value.cookSessionId
                : cookSessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            recipeId: null == recipeId
                ? _value.recipeId
                : recipeId // ignore: cast_nullable_to_non_nullable
                      as String,
            rating: null == rating
                ? _value.rating
                : rating // ignore: cast_nullable_to_non_nullable
                      as int,
            comment: freezed == comment
                ? _value.comment
                : comment // ignore: cast_nullable_to_non_nullable
                      as String?,
            nextTimeNote: freezed == nextTimeNote
                ? _value.nextTimeNote
                : nextTimeNote // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdPersonalVersionId: freezed == createdPersonalVersionId
                ? _value.createdPersonalVersionId
                : createdPersonalVersionId // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PostCookReviewImplCopyWith<$Res>
    implements $PostCookReviewCopyWith<$Res> {
  factory _$$PostCookReviewImplCopyWith(
    _$PostCookReviewImpl value,
    $Res Function(_$PostCookReviewImpl) then,
  ) = __$$PostCookReviewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String cookSessionId,
    String userId,
    String recipeId,
    int rating,
    String? comment,
    String? nextTimeNote,
    String? createdPersonalVersionId,
    DateTime? createdAt,
  });
}

/// @nodoc
class __$$PostCookReviewImplCopyWithImpl<$Res>
    extends _$PostCookReviewCopyWithImpl<$Res, _$PostCookReviewImpl>
    implements _$$PostCookReviewImplCopyWith<$Res> {
  __$$PostCookReviewImplCopyWithImpl(
    _$PostCookReviewImpl _value,
    $Res Function(_$PostCookReviewImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PostCookReview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? cookSessionId = null,
    Object? userId = null,
    Object? recipeId = null,
    Object? rating = null,
    Object? comment = freezed,
    Object? nextTimeNote = freezed,
    Object? createdPersonalVersionId = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$PostCookReviewImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        cookSessionId: null == cookSessionId
            ? _value.cookSessionId
            : cookSessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        recipeId: null == recipeId
            ? _value.recipeId
            : recipeId // ignore: cast_nullable_to_non_nullable
                  as String,
        rating: null == rating
            ? _value.rating
            : rating // ignore: cast_nullable_to_non_nullable
                  as int,
        comment: freezed == comment
            ? _value.comment
            : comment // ignore: cast_nullable_to_non_nullable
                  as String?,
        nextTimeNote: freezed == nextTimeNote
            ? _value.nextTimeNote
            : nextTimeNote // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdPersonalVersionId: freezed == createdPersonalVersionId
            ? _value.createdPersonalVersionId
            : createdPersonalVersionId // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PostCookReviewImpl implements _PostCookReview {
  const _$PostCookReviewImpl({
    required this.id,
    required this.cookSessionId,
    required this.userId,
    required this.recipeId,
    required this.rating,
    this.comment,
    this.nextTimeNote,
    this.createdPersonalVersionId,
    this.createdAt,
  });

  factory _$PostCookReviewImpl.fromJson(Map<String, dynamic> json) =>
      _$$PostCookReviewImplFromJson(json);

  @override
  final String id;
  @override
  final String cookSessionId;
  @override
  final String userId;
  @override
  final String recipeId;
  @override
  final int rating;
  @override
  final String? comment;
  @override
  final String? nextTimeNote;
  @override
  final String? createdPersonalVersionId;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'PostCookReview(id: $id, cookSessionId: $cookSessionId, userId: $userId, recipeId: $recipeId, rating: $rating, comment: $comment, nextTimeNote: $nextTimeNote, createdPersonalVersionId: $createdPersonalVersionId, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PostCookReviewImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.cookSessionId, cookSessionId) ||
                other.cookSessionId == cookSessionId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.recipeId, recipeId) ||
                other.recipeId == recipeId) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.comment, comment) || other.comment == comment) &&
            (identical(other.nextTimeNote, nextTimeNote) ||
                other.nextTimeNote == nextTimeNote) &&
            (identical(
                  other.createdPersonalVersionId,
                  createdPersonalVersionId,
                ) ||
                other.createdPersonalVersionId == createdPersonalVersionId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    cookSessionId,
    userId,
    recipeId,
    rating,
    comment,
    nextTimeNote,
    createdPersonalVersionId,
    createdAt,
  );

  /// Create a copy of PostCookReview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PostCookReviewImplCopyWith<_$PostCookReviewImpl> get copyWith =>
      __$$PostCookReviewImplCopyWithImpl<_$PostCookReviewImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PostCookReviewImplToJson(this);
  }
}

abstract class _PostCookReview implements PostCookReview {
  const factory _PostCookReview({
    required final String id,
    required final String cookSessionId,
    required final String userId,
    required final String recipeId,
    required final int rating,
    final String? comment,
    final String? nextTimeNote,
    final String? createdPersonalVersionId,
    final DateTime? createdAt,
  }) = _$PostCookReviewImpl;

  factory _PostCookReview.fromJson(Map<String, dynamic> json) =
      _$PostCookReviewImpl.fromJson;

  @override
  String get id;
  @override
  String get cookSessionId;
  @override
  String get userId;
  @override
  String get recipeId;
  @override
  int get rating;
  @override
  String? get comment;
  @override
  String? get nextTimeNote;
  @override
  String? get createdPersonalVersionId;
  @override
  DateTime? get createdAt;

  /// Create a copy of PostCookReview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PostCookReviewImplCopyWith<_$PostCookReviewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
