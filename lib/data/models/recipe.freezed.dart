// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recipe.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RecipeSummary _$RecipeSummaryFromJson(Map<String, dynamic> json) {
  return _RecipeSummary.fromJson(json);
}

/// @nodoc
mixin _$RecipeSummary {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  bool get hasPersonalVersion => throw _privateConstructorUsedError;
  String? get latestPersonalVersionId => throw _privateConstructorUsedError;

  /// Serializes this RecipeSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecipeSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecipeSummaryCopyWith<RecipeSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecipeSummaryCopyWith<$Res> {
  factory $RecipeSummaryCopyWith(
    RecipeSummary value,
    $Res Function(RecipeSummary) then,
  ) = _$RecipeSummaryCopyWithImpl<$Res, RecipeSummary>;
  @useResult
  $Res call({
    String id,
    String title,
    String description,
    bool hasPersonalVersion,
    String? latestPersonalVersionId,
  });
}

/// @nodoc
class _$RecipeSummaryCopyWithImpl<$Res, $Val extends RecipeSummary>
    implements $RecipeSummaryCopyWith<$Res> {
  _$RecipeSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecipeSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? hasPersonalVersion = null,
    Object? latestPersonalVersionId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            hasPersonalVersion: null == hasPersonalVersion
                ? _value.hasPersonalVersion
                : hasPersonalVersion // ignore: cast_nullable_to_non_nullable
                      as bool,
            latestPersonalVersionId: freezed == latestPersonalVersionId
                ? _value.latestPersonalVersionId
                : latestPersonalVersionId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecipeSummaryImplCopyWith<$Res>
    implements $RecipeSummaryCopyWith<$Res> {
  factory _$$RecipeSummaryImplCopyWith(
    _$RecipeSummaryImpl value,
    $Res Function(_$RecipeSummaryImpl) then,
  ) = __$$RecipeSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String description,
    bool hasPersonalVersion,
    String? latestPersonalVersionId,
  });
}

/// @nodoc
class __$$RecipeSummaryImplCopyWithImpl<$Res>
    extends _$RecipeSummaryCopyWithImpl<$Res, _$RecipeSummaryImpl>
    implements _$$RecipeSummaryImplCopyWith<$Res> {
  __$$RecipeSummaryImplCopyWithImpl(
    _$RecipeSummaryImpl _value,
    $Res Function(_$RecipeSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecipeSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? hasPersonalVersion = null,
    Object? latestPersonalVersionId = freezed,
  }) {
    return _then(
      _$RecipeSummaryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        hasPersonalVersion: null == hasPersonalVersion
            ? _value.hasPersonalVersion
            : hasPersonalVersion // ignore: cast_nullable_to_non_nullable
                  as bool,
        latestPersonalVersionId: freezed == latestPersonalVersionId
            ? _value.latestPersonalVersionId
            : latestPersonalVersionId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecipeSummaryImpl implements _RecipeSummary {
  const _$RecipeSummaryImpl({
    required this.id,
    required this.title,
    this.description = '',
    this.hasPersonalVersion = false,
    this.latestPersonalVersionId,
  });

  factory _$RecipeSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecipeSummaryImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  @JsonKey()
  final String description;
  @override
  @JsonKey()
  final bool hasPersonalVersion;
  @override
  final String? latestPersonalVersionId;

  @override
  String toString() {
    return 'RecipeSummary(id: $id, title: $title, description: $description, hasPersonalVersion: $hasPersonalVersion, latestPersonalVersionId: $latestPersonalVersionId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecipeSummaryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.hasPersonalVersion, hasPersonalVersion) ||
                other.hasPersonalVersion == hasPersonalVersion) &&
            (identical(
                  other.latestPersonalVersionId,
                  latestPersonalVersionId,
                ) ||
                other.latestPersonalVersionId == latestPersonalVersionId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    description,
    hasPersonalVersion,
    latestPersonalVersionId,
  );

  /// Create a copy of RecipeSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecipeSummaryImplCopyWith<_$RecipeSummaryImpl> get copyWith =>
      __$$RecipeSummaryImplCopyWithImpl<_$RecipeSummaryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecipeSummaryImplToJson(this);
  }
}

abstract class _RecipeSummary implements RecipeSummary {
  const factory _RecipeSummary({
    required final String id,
    required final String title,
    final String description,
    final bool hasPersonalVersion,
    final String? latestPersonalVersionId,
  }) = _$RecipeSummaryImpl;

  factory _RecipeSummary.fromJson(Map<String, dynamic> json) =
      _$RecipeSummaryImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get description;
  @override
  bool get hasPersonalVersion;
  @override
  String? get latestPersonalVersionId;

  /// Create a copy of RecipeSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecipeSummaryImplCopyWith<_$RecipeSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Recipe _$RecipeFromJson(Map<String, dynamic> json) {
  return _Recipe.fromJson(json);
}

/// @nodoc
mixin _$Recipe {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  List<RecipeIngredient> get ingredients => throw _privateConstructorUsedError;
  List<RecipeStep> get steps => throw _privateConstructorUsedError;

  /// Serializes this Recipe to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Recipe
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecipeCopyWith<Recipe> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecipeCopyWith<$Res> {
  factory $RecipeCopyWith(Recipe value, $Res Function(Recipe) then) =
      _$RecipeCopyWithImpl<$Res, Recipe>;
  @useResult
  $Res call({
    String id,
    String title,
    String description,
    List<RecipeIngredient> ingredients,
    List<RecipeStep> steps,
  });
}

/// @nodoc
class _$RecipeCopyWithImpl<$Res, $Val extends Recipe>
    implements $RecipeCopyWith<$Res> {
  _$RecipeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Recipe
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? ingredients = null,
    Object? steps = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            ingredients: null == ingredients
                ? _value.ingredients
                : ingredients // ignore: cast_nullable_to_non_nullable
                      as List<RecipeIngredient>,
            steps: null == steps
                ? _value.steps
                : steps // ignore: cast_nullable_to_non_nullable
                      as List<RecipeStep>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecipeImplCopyWith<$Res> implements $RecipeCopyWith<$Res> {
  factory _$$RecipeImplCopyWith(
    _$RecipeImpl value,
    $Res Function(_$RecipeImpl) then,
  ) = __$$RecipeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String description,
    List<RecipeIngredient> ingredients,
    List<RecipeStep> steps,
  });
}

/// @nodoc
class __$$RecipeImplCopyWithImpl<$Res>
    extends _$RecipeCopyWithImpl<$Res, _$RecipeImpl>
    implements _$$RecipeImplCopyWith<$Res> {
  __$$RecipeImplCopyWithImpl(
    _$RecipeImpl _value,
    $Res Function(_$RecipeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Recipe
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = null,
    Object? ingredients = null,
    Object? steps = null,
  }) {
    return _then(
      _$RecipeImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        ingredients: null == ingredients
            ? _value._ingredients
            : ingredients // ignore: cast_nullable_to_non_nullable
                  as List<RecipeIngredient>,
        steps: null == steps
            ? _value._steps
            : steps // ignore: cast_nullable_to_non_nullable
                  as List<RecipeStep>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecipeImpl extends _Recipe {
  const _$RecipeImpl({
    required this.id,
    required this.title,
    this.description = '',
    final List<RecipeIngredient> ingredients = const <RecipeIngredient>[],
    final List<RecipeStep> steps = const <RecipeStep>[],
  }) : _ingredients = ingredients,
       _steps = steps,
       super._();

  factory _$RecipeImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecipeImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  @JsonKey()
  final String description;
  final List<RecipeIngredient> _ingredients;
  @override
  @JsonKey()
  List<RecipeIngredient> get ingredients {
    if (_ingredients is EqualUnmodifiableListView) return _ingredients;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_ingredients);
  }

  final List<RecipeStep> _steps;
  @override
  @JsonKey()
  List<RecipeStep> get steps {
    if (_steps is EqualUnmodifiableListView) return _steps;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_steps);
  }

  @override
  String toString() {
    return 'Recipe(id: $id, title: $title, description: $description, ingredients: $ingredients, steps: $steps)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecipeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(
              other._ingredients,
              _ingredients,
            ) &&
            const DeepCollectionEquality().equals(other._steps, _steps));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    description,
    const DeepCollectionEquality().hash(_ingredients),
    const DeepCollectionEquality().hash(_steps),
  );

  /// Create a copy of Recipe
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecipeImplCopyWith<_$RecipeImpl> get copyWith =>
      __$$RecipeImplCopyWithImpl<_$RecipeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecipeImplToJson(this);
  }
}

abstract class _Recipe extends Recipe {
  const factory _Recipe({
    required final String id,
    required final String title,
    final String description,
    final List<RecipeIngredient> ingredients,
    final List<RecipeStep> steps,
  }) = _$RecipeImpl;
  const _Recipe._() : super._();

  factory _Recipe.fromJson(Map<String, dynamic> json) = _$RecipeImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get description;
  @override
  List<RecipeIngredient> get ingredients;
  @override
  List<RecipeStep> get steps;

  /// Create a copy of Recipe
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecipeImplCopyWith<_$RecipeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RecipeIngredient _$RecipeIngredientFromJson(Map<String, dynamic> json) {
  return _RecipeIngredient.fromJson(json);
}

/// @nodoc
mixin _$RecipeIngredient {
  String get name => throw _privateConstructorUsedError;
  double? get amount => throw _privateConstructorUsedError;
  String? get unit =>
      throw _privateConstructorUsedError; // `required`는 Dart 예약어라 필드명을 바꾸고 JSON 키만 맞춘다.
  @JsonKey(name: 'required')
  bool get isRequired => throw _privateConstructorUsedError;

  /// Serializes this RecipeIngredient to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecipeIngredient
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecipeIngredientCopyWith<RecipeIngredient> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecipeIngredientCopyWith<$Res> {
  factory $RecipeIngredientCopyWith(
    RecipeIngredient value,
    $Res Function(RecipeIngredient) then,
  ) = _$RecipeIngredientCopyWithImpl<$Res, RecipeIngredient>;
  @useResult
  $Res call({
    String name,
    double? amount,
    String? unit,
    @JsonKey(name: 'required') bool isRequired,
  });
}

/// @nodoc
class _$RecipeIngredientCopyWithImpl<$Res, $Val extends RecipeIngredient>
    implements $RecipeIngredientCopyWith<$Res> {
  _$RecipeIngredientCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecipeIngredient
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? amount = freezed,
    Object? unit = freezed,
    Object? isRequired = null,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            amount: freezed == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as double?,
            unit: freezed == unit
                ? _value.unit
                : unit // ignore: cast_nullable_to_non_nullable
                      as String?,
            isRequired: null == isRequired
                ? _value.isRequired
                : isRequired // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecipeIngredientImplCopyWith<$Res>
    implements $RecipeIngredientCopyWith<$Res> {
  factory _$$RecipeIngredientImplCopyWith(
    _$RecipeIngredientImpl value,
    $Res Function(_$RecipeIngredientImpl) then,
  ) = __$$RecipeIngredientImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    double? amount,
    String? unit,
    @JsonKey(name: 'required') bool isRequired,
  });
}

/// @nodoc
class __$$RecipeIngredientImplCopyWithImpl<$Res>
    extends _$RecipeIngredientCopyWithImpl<$Res, _$RecipeIngredientImpl>
    implements _$$RecipeIngredientImplCopyWith<$Res> {
  __$$RecipeIngredientImplCopyWithImpl(
    _$RecipeIngredientImpl _value,
    $Res Function(_$RecipeIngredientImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecipeIngredient
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? amount = freezed,
    Object? unit = freezed,
    Object? isRequired = null,
  }) {
    return _then(
      _$RecipeIngredientImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        amount: freezed == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as double?,
        unit: freezed == unit
            ? _value.unit
            : unit // ignore: cast_nullable_to_non_nullable
                  as String?,
        isRequired: null == isRequired
            ? _value.isRequired
            : isRequired // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecipeIngredientImpl extends _RecipeIngredient {
  const _$RecipeIngredientImpl({
    required this.name,
    this.amount,
    this.unit,
    @JsonKey(name: 'required') this.isRequired = false,
  }) : super._();

  factory _$RecipeIngredientImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecipeIngredientImplFromJson(json);

  @override
  final String name;
  @override
  final double? amount;
  @override
  final String? unit;
  // `required`는 Dart 예약어라 필드명을 바꾸고 JSON 키만 맞춘다.
  @override
  @JsonKey(name: 'required')
  final bool isRequired;

  @override
  String toString() {
    return 'RecipeIngredient(name: $name, amount: $amount, unit: $unit, isRequired: $isRequired)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecipeIngredientImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.isRequired, isRequired) ||
                other.isRequired == isRequired));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, amount, unit, isRequired);

  /// Create a copy of RecipeIngredient
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecipeIngredientImplCopyWith<_$RecipeIngredientImpl> get copyWith =>
      __$$RecipeIngredientImplCopyWithImpl<_$RecipeIngredientImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RecipeIngredientImplToJson(this);
  }
}

abstract class _RecipeIngredient extends RecipeIngredient {
  const factory _RecipeIngredient({
    required final String name,
    final double? amount,
    final String? unit,
    @JsonKey(name: 'required') final bool isRequired,
  }) = _$RecipeIngredientImpl;
  const _RecipeIngredient._() : super._();

  factory _RecipeIngredient.fromJson(Map<String, dynamic> json) =
      _$RecipeIngredientImpl.fromJson;

  @override
  String get name;
  @override
  double? get amount;
  @override
  String? get unit; // `required`는 Dart 예약어라 필드명을 바꾸고 JSON 키만 맞춘다.
  @override
  @JsonKey(name: 'required')
  bool get isRequired;

  /// Create a copy of RecipeIngredient
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecipeIngredientImplCopyWith<_$RecipeIngredientImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RecipeStep _$RecipeStepFromJson(Map<String, dynamic> json) {
  return _RecipeStep.fromJson(json);
}

/// @nodoc
mixin _$RecipeStep {
  int get stepIndex => throw _privateConstructorUsedError;
  String get instruction => throw _privateConstructorUsedError;
  int? get timerSeconds => throw _privateConstructorUsedError;
  String? get cautionNote => throw _privateConstructorUsedError;

  /// Serializes this RecipeStep to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecipeStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecipeStepCopyWith<RecipeStep> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecipeStepCopyWith<$Res> {
  factory $RecipeStepCopyWith(
    RecipeStep value,
    $Res Function(RecipeStep) then,
  ) = _$RecipeStepCopyWithImpl<$Res, RecipeStep>;
  @useResult
  $Res call({
    int stepIndex,
    String instruction,
    int? timerSeconds,
    String? cautionNote,
  });
}

/// @nodoc
class _$RecipeStepCopyWithImpl<$Res, $Val extends RecipeStep>
    implements $RecipeStepCopyWith<$Res> {
  _$RecipeStepCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecipeStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stepIndex = null,
    Object? instruction = null,
    Object? timerSeconds = freezed,
    Object? cautionNote = freezed,
  }) {
    return _then(
      _value.copyWith(
            stepIndex: null == stepIndex
                ? _value.stepIndex
                : stepIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            instruction: null == instruction
                ? _value.instruction
                : instruction // ignore: cast_nullable_to_non_nullable
                      as String,
            timerSeconds: freezed == timerSeconds
                ? _value.timerSeconds
                : timerSeconds // ignore: cast_nullable_to_non_nullable
                      as int?,
            cautionNote: freezed == cautionNote
                ? _value.cautionNote
                : cautionNote // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecipeStepImplCopyWith<$Res>
    implements $RecipeStepCopyWith<$Res> {
  factory _$$RecipeStepImplCopyWith(
    _$RecipeStepImpl value,
    $Res Function(_$RecipeStepImpl) then,
  ) = __$$RecipeStepImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int stepIndex,
    String instruction,
    int? timerSeconds,
    String? cautionNote,
  });
}

/// @nodoc
class __$$RecipeStepImplCopyWithImpl<$Res>
    extends _$RecipeStepCopyWithImpl<$Res, _$RecipeStepImpl>
    implements _$$RecipeStepImplCopyWith<$Res> {
  __$$RecipeStepImplCopyWithImpl(
    _$RecipeStepImpl _value,
    $Res Function(_$RecipeStepImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecipeStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stepIndex = null,
    Object? instruction = null,
    Object? timerSeconds = freezed,
    Object? cautionNote = freezed,
  }) {
    return _then(
      _$RecipeStepImpl(
        stepIndex: null == stepIndex
            ? _value.stepIndex
            : stepIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        instruction: null == instruction
            ? _value.instruction
            : instruction // ignore: cast_nullable_to_non_nullable
                  as String,
        timerSeconds: freezed == timerSeconds
            ? _value.timerSeconds
            : timerSeconds // ignore: cast_nullable_to_non_nullable
                  as int?,
        cautionNote: freezed == cautionNote
            ? _value.cautionNote
            : cautionNote // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecipeStepImpl extends _RecipeStep {
  const _$RecipeStepImpl({
    required this.stepIndex,
    required this.instruction,
    this.timerSeconds,
    this.cautionNote,
  }) : super._();

  factory _$RecipeStepImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecipeStepImplFromJson(json);

  @override
  final int stepIndex;
  @override
  final String instruction;
  @override
  final int? timerSeconds;
  @override
  final String? cautionNote;

  @override
  String toString() {
    return 'RecipeStep(stepIndex: $stepIndex, instruction: $instruction, timerSeconds: $timerSeconds, cautionNote: $cautionNote)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecipeStepImpl &&
            (identical(other.stepIndex, stepIndex) ||
                other.stepIndex == stepIndex) &&
            (identical(other.instruction, instruction) ||
                other.instruction == instruction) &&
            (identical(other.timerSeconds, timerSeconds) ||
                other.timerSeconds == timerSeconds) &&
            (identical(other.cautionNote, cautionNote) ||
                other.cautionNote == cautionNote));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    stepIndex,
    instruction,
    timerSeconds,
    cautionNote,
  );

  /// Create a copy of RecipeStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecipeStepImplCopyWith<_$RecipeStepImpl> get copyWith =>
      __$$RecipeStepImplCopyWithImpl<_$RecipeStepImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecipeStepImplToJson(this);
  }
}

abstract class _RecipeStep extends RecipeStep {
  const factory _RecipeStep({
    required final int stepIndex,
    required final String instruction,
    final int? timerSeconds,
    final String? cautionNote,
  }) = _$RecipeStepImpl;
  const _RecipeStep._() : super._();

  factory _RecipeStep.fromJson(Map<String, dynamic> json) =
      _$RecipeStepImpl.fromJson;

  @override
  int get stepIndex;
  @override
  String get instruction;
  @override
  int? get timerSeconds;
  @override
  String? get cautionNote;

  /// Create a copy of RecipeStep
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecipeStepImplCopyWith<_$RecipeStepImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
