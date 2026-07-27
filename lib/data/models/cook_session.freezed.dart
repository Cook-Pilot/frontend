// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cook_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CookSession _$CookSessionFromJson(Map<String, dynamic> json) {
  return _CookSession.fromJson(json);
}

/// @nodoc
mixin _$CookSession {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get recipeId => throw _privateConstructorUsedError;
  String? get personalVersionId => throw _privateConstructorUsedError;
  String get recipeTitle => throw _privateConstructorUsedError;
  SessionStatus get status => throw _privateConstructorUsedError;
  int get currentStepIndex => throw _privateConstructorUsedError;
  RecipeStep? get currentStep => throw _privateConstructorUsedError;
  int get totalSteps => throw _privateConstructorUsedError;
  List<RecipeStep> get steps => throw _privateConstructorUsedError;
  DateTime? get startedAt => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  DateTime? get abortedAt => throw _privateConstructorUsedError;

  /// Serializes this CookSession to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CookSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CookSessionCopyWith<CookSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CookSessionCopyWith<$Res> {
  factory $CookSessionCopyWith(
    CookSession value,
    $Res Function(CookSession) then,
  ) = _$CookSessionCopyWithImpl<$Res, CookSession>;
  @useResult
  $Res call({
    String id,
    String userId,
    String recipeId,
    String? personalVersionId,
    String recipeTitle,
    SessionStatus status,
    int currentStepIndex,
    RecipeStep? currentStep,
    int totalSteps,
    List<RecipeStep> steps,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? abortedAt,
  });

  $RecipeStepCopyWith<$Res>? get currentStep;
}

/// @nodoc
class _$CookSessionCopyWithImpl<$Res, $Val extends CookSession>
    implements $CookSessionCopyWith<$Res> {
  _$CookSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CookSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? recipeId = null,
    Object? personalVersionId = freezed,
    Object? recipeTitle = null,
    Object? status = null,
    Object? currentStepIndex = null,
    Object? currentStep = freezed,
    Object? totalSteps = null,
    Object? steps = null,
    Object? startedAt = freezed,
    Object? completedAt = freezed,
    Object? abortedAt = freezed,
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
            personalVersionId: freezed == personalVersionId
                ? _value.personalVersionId
                : personalVersionId // ignore: cast_nullable_to_non_nullable
                      as String?,
            recipeTitle: null == recipeTitle
                ? _value.recipeTitle
                : recipeTitle // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as SessionStatus,
            currentStepIndex: null == currentStepIndex
                ? _value.currentStepIndex
                : currentStepIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            currentStep: freezed == currentStep
                ? _value.currentStep
                : currentStep // ignore: cast_nullable_to_non_nullable
                      as RecipeStep?,
            totalSteps: null == totalSteps
                ? _value.totalSteps
                : totalSteps // ignore: cast_nullable_to_non_nullable
                      as int,
            steps: null == steps
                ? _value.steps
                : steps // ignore: cast_nullable_to_non_nullable
                      as List<RecipeStep>,
            startedAt: freezed == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            completedAt: freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            abortedAt: freezed == abortedAt
                ? _value.abortedAt
                : abortedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }

  /// Create a copy of CookSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RecipeStepCopyWith<$Res>? get currentStep {
    if (_value.currentStep == null) {
      return null;
    }

    return $RecipeStepCopyWith<$Res>(_value.currentStep!, (value) {
      return _then(_value.copyWith(currentStep: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CookSessionImplCopyWith<$Res>
    implements $CookSessionCopyWith<$Res> {
  factory _$$CookSessionImplCopyWith(
    _$CookSessionImpl value,
    $Res Function(_$CookSessionImpl) then,
  ) = __$$CookSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String recipeId,
    String? personalVersionId,
    String recipeTitle,
    SessionStatus status,
    int currentStepIndex,
    RecipeStep? currentStep,
    int totalSteps,
    List<RecipeStep> steps,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? abortedAt,
  });

  @override
  $RecipeStepCopyWith<$Res>? get currentStep;
}

/// @nodoc
class __$$CookSessionImplCopyWithImpl<$Res>
    extends _$CookSessionCopyWithImpl<$Res, _$CookSessionImpl>
    implements _$$CookSessionImplCopyWith<$Res> {
  __$$CookSessionImplCopyWithImpl(
    _$CookSessionImpl _value,
    $Res Function(_$CookSessionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CookSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? recipeId = null,
    Object? personalVersionId = freezed,
    Object? recipeTitle = null,
    Object? status = null,
    Object? currentStepIndex = null,
    Object? currentStep = freezed,
    Object? totalSteps = null,
    Object? steps = null,
    Object? startedAt = freezed,
    Object? completedAt = freezed,
    Object? abortedAt = freezed,
  }) {
    return _then(
      _$CookSessionImpl(
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
        personalVersionId: freezed == personalVersionId
            ? _value.personalVersionId
            : personalVersionId // ignore: cast_nullable_to_non_nullable
                  as String?,
        recipeTitle: null == recipeTitle
            ? _value.recipeTitle
            : recipeTitle // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as SessionStatus,
        currentStepIndex: null == currentStepIndex
            ? _value.currentStepIndex
            : currentStepIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        currentStep: freezed == currentStep
            ? _value.currentStep
            : currentStep // ignore: cast_nullable_to_non_nullable
                  as RecipeStep?,
        totalSteps: null == totalSteps
            ? _value.totalSteps
            : totalSteps // ignore: cast_nullable_to_non_nullable
                  as int,
        steps: null == steps
            ? _value._steps
            : steps // ignore: cast_nullable_to_non_nullable
                  as List<RecipeStep>,
        startedAt: freezed == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        completedAt: freezed == completedAt
            ? _value.completedAt
            : completedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        abortedAt: freezed == abortedAt
            ? _value.abortedAt
            : abortedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CookSessionImpl extends _CookSession {
  const _$CookSessionImpl({
    required this.id,
    required this.userId,
    required this.recipeId,
    this.personalVersionId,
    required this.recipeTitle,
    required this.status,
    required this.currentStepIndex,
    this.currentStep,
    required this.totalSteps,
    final List<RecipeStep> steps = const <RecipeStep>[],
    this.startedAt,
    this.completedAt,
    this.abortedAt,
  }) : _steps = steps,
       super._();

  factory _$CookSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$CookSessionImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String recipeId;
  @override
  final String? personalVersionId;
  @override
  final String recipeTitle;
  @override
  final SessionStatus status;
  @override
  final int currentStepIndex;
  @override
  final RecipeStep? currentStep;
  @override
  final int totalSteps;
  final List<RecipeStep> _steps;
  @override
  @JsonKey()
  List<RecipeStep> get steps {
    if (_steps is EqualUnmodifiableListView) return _steps;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_steps);
  }

  @override
  final DateTime? startedAt;
  @override
  final DateTime? completedAt;
  @override
  final DateTime? abortedAt;

  @override
  String toString() {
    return 'CookSession(id: $id, userId: $userId, recipeId: $recipeId, personalVersionId: $personalVersionId, recipeTitle: $recipeTitle, status: $status, currentStepIndex: $currentStepIndex, currentStep: $currentStep, totalSteps: $totalSteps, steps: $steps, startedAt: $startedAt, completedAt: $completedAt, abortedAt: $abortedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CookSessionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.recipeId, recipeId) ||
                other.recipeId == recipeId) &&
            (identical(other.personalVersionId, personalVersionId) ||
                other.personalVersionId == personalVersionId) &&
            (identical(other.recipeTitle, recipeTitle) ||
                other.recipeTitle == recipeTitle) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.currentStepIndex, currentStepIndex) ||
                other.currentStepIndex == currentStepIndex) &&
            (identical(other.currentStep, currentStep) ||
                other.currentStep == currentStep) &&
            (identical(other.totalSteps, totalSteps) ||
                other.totalSteps == totalSteps) &&
            const DeepCollectionEquality().equals(other._steps, _steps) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.abortedAt, abortedAt) ||
                other.abortedAt == abortedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    recipeId,
    personalVersionId,
    recipeTitle,
    status,
    currentStepIndex,
    currentStep,
    totalSteps,
    const DeepCollectionEquality().hash(_steps),
    startedAt,
    completedAt,
    abortedAt,
  );

  /// Create a copy of CookSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CookSessionImplCopyWith<_$CookSessionImpl> get copyWith =>
      __$$CookSessionImplCopyWithImpl<_$CookSessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CookSessionImplToJson(this);
  }
}

abstract class _CookSession extends CookSession {
  const factory _CookSession({
    required final String id,
    required final String userId,
    required final String recipeId,
    final String? personalVersionId,
    required final String recipeTitle,
    required final SessionStatus status,
    required final int currentStepIndex,
    final RecipeStep? currentStep,
    required final int totalSteps,
    final List<RecipeStep> steps,
    final DateTime? startedAt,
    final DateTime? completedAt,
    final DateTime? abortedAt,
  }) = _$CookSessionImpl;
  const _CookSession._() : super._();

  factory _CookSession.fromJson(Map<String, dynamic> json) =
      _$CookSessionImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get recipeId;
  @override
  String? get personalVersionId;
  @override
  String get recipeTitle;
  @override
  SessionStatus get status;
  @override
  int get currentStepIndex;
  @override
  RecipeStep? get currentStep;
  @override
  int get totalSteps;
  @override
  List<RecipeStep> get steps;
  @override
  DateTime? get startedAt;
  @override
  DateTime? get completedAt;
  @override
  DateTime? get abortedAt;

  /// Create a copy of CookSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CookSessionImplCopyWith<_$CookSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CookSessionEvent _$CookSessionEventFromJson(Map<String, dynamic> json) {
  return _CookSessionEvent.fromJson(json);
}

/// @nodoc
mixin _$CookSessionEvent {
  String get id => throw _privateConstructorUsedError;
  String get cookSessionId => throw _privateConstructorUsedError;
  String get eventType => throw _privateConstructorUsedError;
  int? get stepIndex => throw _privateConstructorUsedError;
  String? get source => throw _privateConstructorUsedError;
  Map<String, dynamic>? get payload => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this CookSessionEvent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CookSessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CookSessionEventCopyWith<CookSessionEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CookSessionEventCopyWith<$Res> {
  factory $CookSessionEventCopyWith(
    CookSessionEvent value,
    $Res Function(CookSessionEvent) then,
  ) = _$CookSessionEventCopyWithImpl<$Res, CookSessionEvent>;
  @useResult
  $Res call({
    String id,
    String cookSessionId,
    String eventType,
    int? stepIndex,
    String? source,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
  });
}

/// @nodoc
class _$CookSessionEventCopyWithImpl<$Res, $Val extends CookSessionEvent>
    implements $CookSessionEventCopyWith<$Res> {
  _$CookSessionEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CookSessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? cookSessionId = null,
    Object? eventType = null,
    Object? stepIndex = freezed,
    Object? source = freezed,
    Object? payload = freezed,
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
            eventType: null == eventType
                ? _value.eventType
                : eventType // ignore: cast_nullable_to_non_nullable
                      as String,
            stepIndex: freezed == stepIndex
                ? _value.stepIndex
                : stepIndex // ignore: cast_nullable_to_non_nullable
                      as int?,
            source: freezed == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as String?,
            payload: freezed == payload
                ? _value.payload
                : payload // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
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
abstract class _$$CookSessionEventImplCopyWith<$Res>
    implements $CookSessionEventCopyWith<$Res> {
  factory _$$CookSessionEventImplCopyWith(
    _$CookSessionEventImpl value,
    $Res Function(_$CookSessionEventImpl) then,
  ) = __$$CookSessionEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String cookSessionId,
    String eventType,
    int? stepIndex,
    String? source,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
  });
}

/// @nodoc
class __$$CookSessionEventImplCopyWithImpl<$Res>
    extends _$CookSessionEventCopyWithImpl<$Res, _$CookSessionEventImpl>
    implements _$$CookSessionEventImplCopyWith<$Res> {
  __$$CookSessionEventImplCopyWithImpl(
    _$CookSessionEventImpl _value,
    $Res Function(_$CookSessionEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CookSessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? cookSessionId = null,
    Object? eventType = null,
    Object? stepIndex = freezed,
    Object? source = freezed,
    Object? payload = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(
      _$CookSessionEventImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        cookSessionId: null == cookSessionId
            ? _value.cookSessionId
            : cookSessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        eventType: null == eventType
            ? _value.eventType
            : eventType // ignore: cast_nullable_to_non_nullable
                  as String,
        stepIndex: freezed == stepIndex
            ? _value.stepIndex
            : stepIndex // ignore: cast_nullable_to_non_nullable
                  as int?,
        source: freezed == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as String?,
        payload: freezed == payload
            ? _value._payload
            : payload // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
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
class _$CookSessionEventImpl implements _CookSessionEvent {
  const _$CookSessionEventImpl({
    required this.id,
    required this.cookSessionId,
    required this.eventType,
    this.stepIndex,
    this.source,
    final Map<String, dynamic>? payload,
    this.createdAt,
  }) : _payload = payload;

  factory _$CookSessionEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$CookSessionEventImplFromJson(json);

  @override
  final String id;
  @override
  final String cookSessionId;
  @override
  final String eventType;
  @override
  final int? stepIndex;
  @override
  final String? source;
  final Map<String, dynamic>? _payload;
  @override
  Map<String, dynamic>? get payload {
    final value = _payload;
    if (value == null) return null;
    if (_payload is EqualUnmodifiableMapView) return _payload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'CookSessionEvent(id: $id, cookSessionId: $cookSessionId, eventType: $eventType, stepIndex: $stepIndex, source: $source, payload: $payload, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CookSessionEventImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.cookSessionId, cookSessionId) ||
                other.cookSessionId == cookSessionId) &&
            (identical(other.eventType, eventType) ||
                other.eventType == eventType) &&
            (identical(other.stepIndex, stepIndex) ||
                other.stepIndex == stepIndex) &&
            (identical(other.source, source) || other.source == source) &&
            const DeepCollectionEquality().equals(other._payload, _payload) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    cookSessionId,
    eventType,
    stepIndex,
    source,
    const DeepCollectionEquality().hash(_payload),
    createdAt,
  );

  /// Create a copy of CookSessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CookSessionEventImplCopyWith<_$CookSessionEventImpl> get copyWith =>
      __$$CookSessionEventImplCopyWithImpl<_$CookSessionEventImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CookSessionEventImplToJson(this);
  }
}

abstract class _CookSessionEvent implements CookSessionEvent {
  const factory _CookSessionEvent({
    required final String id,
    required final String cookSessionId,
    required final String eventType,
    final int? stepIndex,
    final String? source,
    final Map<String, dynamic>? payload,
    final DateTime? createdAt,
  }) = _$CookSessionEventImpl;

  factory _CookSessionEvent.fromJson(Map<String, dynamic> json) =
      _$CookSessionEventImpl.fromJson;

  @override
  String get id;
  @override
  String get cookSessionId;
  @override
  String get eventType;
  @override
  int? get stepIndex;
  @override
  String? get source;
  @override
  Map<String, dynamic>? get payload;
  @override
  DateTime? get createdAt;

  /// Create a copy of CookSessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CookSessionEventImplCopyWith<_$CookSessionEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
