// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'personal_recipe_version.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PersonalRecipeVersion _$PersonalRecipeVersionFromJson(
  Map<String, dynamic> json,
) {
  return _PersonalRecipeVersion.fromJson(json);
}

/// @nodoc
mixin _$PersonalRecipeVersion {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get recipeId => throw _privateConstructorUsedError;
  int get versionNumber => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get summary => throw _privateConstructorUsedError;
  Map<String, dynamic>? get adjustmentPayload =>
      throw _privateConstructorUsedError;
  String? get sourceSessionId => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this PersonalRecipeVersion to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PersonalRecipeVersion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PersonalRecipeVersionCopyWith<PersonalRecipeVersion> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PersonalRecipeVersionCopyWith<$Res> {
  factory $PersonalRecipeVersionCopyWith(
    PersonalRecipeVersion value,
    $Res Function(PersonalRecipeVersion) then,
  ) = _$PersonalRecipeVersionCopyWithImpl<$Res, PersonalRecipeVersion>;
  @useResult
  $Res call({
    String id,
    String userId,
    String recipeId,
    int versionNumber,
    String title,
    String? summary,
    Map<String, dynamic>? adjustmentPayload,
    String? sourceSessionId,
    DateTime? createdAt,
  });
}

/// @nodoc
class _$PersonalRecipeVersionCopyWithImpl<
  $Res,
  $Val extends PersonalRecipeVersion
>
    implements $PersonalRecipeVersionCopyWith<$Res> {
  _$PersonalRecipeVersionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PersonalRecipeVersion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? recipeId = null,
    Object? versionNumber = null,
    Object? title = null,
    Object? summary = freezed,
    Object? adjustmentPayload = freezed,
    Object? sourceSessionId = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            recipeId: null == recipeId
                ? _value.recipeId
                : recipeId // ignore: cast_nullable_to_non_nullable
                      as String,
            versionNumber: null == versionNumber
                ? _value.versionNumber
                : versionNumber // ignore: cast_nullable_to_non_nullable
                      as int,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            summary: freezed == summary
                ? _value.summary
                : summary // ignore: cast_nullable_to_non_nullable
                      as String?,
            adjustmentPayload: freezed == adjustmentPayload
                ? _value.adjustmentPayload
                : adjustmentPayload // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            sourceSessionId: freezed == sourceSessionId
                ? _value.sourceSessionId
                : sourceSessionId // ignore: cast_nullable_to_non_nullable
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
abstract class _$$PersonalRecipeVersionImplCopyWith<$Res>
    implements $PersonalRecipeVersionCopyWith<$Res> {
  factory _$$PersonalRecipeVersionImplCopyWith(
    _$PersonalRecipeVersionImpl value,
    $Res Function(_$PersonalRecipeVersionImpl) then,
  ) = __$$PersonalRecipeVersionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String recipeId,
    int versionNumber,
    String title,
    String? summary,
    Map<String, dynamic>? adjustmentPayload,
    String? sourceSessionId,
    DateTime? createdAt,
  });
}

/// @nodoc
class __$$PersonalRecipeVersionImplCopyWithImpl<$Res>
    extends
        _$PersonalRecipeVersionCopyWithImpl<$Res, _$PersonalRecipeVersionImpl>
    implements _$$PersonalRecipeVersionImplCopyWith<$Res> {
  __$$PersonalRecipeVersionImplCopyWithImpl(
    _$PersonalRecipeVersionImpl _value,
    $Res Function(_$PersonalRecipeVersionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PersonalRecipeVersion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? recipeId = null,
    Object? versionNumber = null,
    Object? title = null,
    Object? summary = freezed,
    Object? adjustmentPayload = freezed,
    Object? sourceSessionId = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$PersonalRecipeVersionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        recipeId: null == recipeId
            ? _value.recipeId
            : recipeId // ignore: cast_nullable_to_non_nullable
                  as String,
        versionNumber: null == versionNumber
            ? _value.versionNumber
            : versionNumber // ignore: cast_nullable_to_non_nullable
                  as int,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        summary: freezed == summary
            ? _value.summary
            : summary // ignore: cast_nullable_to_non_nullable
                  as String?,
        adjustmentPayload: freezed == adjustmentPayload
            ? _value._adjustmentPayload
            : adjustmentPayload // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        sourceSessionId: freezed == sourceSessionId
            ? _value.sourceSessionId
            : sourceSessionId // ignore: cast_nullable_to_non_nullable
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
class _$PersonalRecipeVersionImpl extends _PersonalRecipeVersion {
  const _$PersonalRecipeVersionImpl({
    required this.id,
    required this.userId,
    required this.recipeId,
    required this.versionNumber,
    required this.title,
    this.summary,
    final Map<String, dynamic>? adjustmentPayload,
    this.sourceSessionId,
    this.createdAt,
  }) : _adjustmentPayload = adjustmentPayload,
       super._();

  factory _$PersonalRecipeVersionImpl.fromJson(Map<String, dynamic> json) =>
      _$$PersonalRecipeVersionImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String recipeId;
  @override
  final int versionNumber;
  @override
  final String title;
  @override
  final String? summary;
  final Map<String, dynamic>? _adjustmentPayload;
  @override
  Map<String, dynamic>? get adjustmentPayload {
    final value = _adjustmentPayload;
    if (value == null) return null;
    if (_adjustmentPayload is EqualUnmodifiableMapView)
      return _adjustmentPayload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final String? sourceSessionId;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'PersonalRecipeVersion(id: $id, userId: $userId, recipeId: $recipeId, versionNumber: $versionNumber, title: $title, summary: $summary, adjustmentPayload: $adjustmentPayload, sourceSessionId: $sourceSessionId, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PersonalRecipeVersionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.recipeId, recipeId) ||
                other.recipeId == recipeId) &&
            (identical(other.versionNumber, versionNumber) ||
                other.versionNumber == versionNumber) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            const DeepCollectionEquality().equals(
              other._adjustmentPayload,
              _adjustmentPayload,
            ) &&
            (identical(other.sourceSessionId, sourceSessionId) ||
                other.sourceSessionId == sourceSessionId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    recipeId,
    versionNumber,
    title,
    summary,
    const DeepCollectionEquality().hash(_adjustmentPayload),
    sourceSessionId,
    createdAt,
  );

  /// Create a copy of PersonalRecipeVersion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PersonalRecipeVersionImplCopyWith<_$PersonalRecipeVersionImpl>
  get copyWith =>
      __$$PersonalRecipeVersionImplCopyWithImpl<_$PersonalRecipeVersionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PersonalRecipeVersionImplToJson(this);
  }
}

abstract class _PersonalRecipeVersion extends PersonalRecipeVersion {
  const factory _PersonalRecipeVersion({
    required final String id,
    required final String userId,
    required final String recipeId,
    required final int versionNumber,
    required final String title,
    final String? summary,
    final Map<String, dynamic>? adjustmentPayload,
    final String? sourceSessionId,
    final DateTime? createdAt,
  }) = _$PersonalRecipeVersionImpl;
  const _PersonalRecipeVersion._() : super._();

  factory _PersonalRecipeVersion.fromJson(Map<String, dynamic> json) =
      _$PersonalRecipeVersionImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get recipeId;
  @override
  int get versionNumber;
  @override
  String get title;
  @override
  String? get summary;
  @override
  Map<String, dynamic>? get adjustmentPayload;
  @override
  String? get sourceSessionId;
  @override
  DateTime? get createdAt;

  /// Create a copy of PersonalRecipeVersion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PersonalRecipeVersionImplCopyWith<_$PersonalRecipeVersionImpl>
  get copyWith => throw _privateConstructorUsedError;
}
