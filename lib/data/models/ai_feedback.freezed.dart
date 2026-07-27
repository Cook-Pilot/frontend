// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_feedback.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AiFeedback _$AiFeedbackFromJson(Map<String, dynamic> json) {
  return _AiFeedback.fromJson(json);
}

/// @nodoc
mixin _$AiFeedback {
  bool get mock => throw _privateConstructorUsedError;
  String get speechText => throw _privateConstructorUsedError;
  String get screenText => throw _privateConstructorUsedError;
  SuggestedAction? get suggestedAction => throw _privateConstructorUsedError;
  Map<String, dynamic>? get eventPayload => throw _privateConstructorUsedError;

  /// Serializes this AiFeedback to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AiFeedback
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AiFeedbackCopyWith<AiFeedback> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AiFeedbackCopyWith<$Res> {
  factory $AiFeedbackCopyWith(
    AiFeedback value,
    $Res Function(AiFeedback) then,
  ) = _$AiFeedbackCopyWithImpl<$Res, AiFeedback>;
  @useResult
  $Res call({
    bool mock,
    String speechText,
    String screenText,
    SuggestedAction? suggestedAction,
    Map<String, dynamic>? eventPayload,
  });

  $SuggestedActionCopyWith<$Res>? get suggestedAction;
}

/// @nodoc
class _$AiFeedbackCopyWithImpl<$Res, $Val extends AiFeedback>
    implements $AiFeedbackCopyWith<$Res> {
  _$AiFeedbackCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AiFeedback
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mock = null,
    Object? speechText = null,
    Object? screenText = null,
    Object? suggestedAction = freezed,
    Object? eventPayload = freezed,
  }) {
    return _then(
      _value.copyWith(
            mock: null == mock
                ? _value.mock
                : mock // ignore: cast_nullable_to_non_nullable
                      as bool,
            speechText: null == speechText
                ? _value.speechText
                : speechText // ignore: cast_nullable_to_non_nullable
                      as String,
            screenText: null == screenText
                ? _value.screenText
                : screenText // ignore: cast_nullable_to_non_nullable
                      as String,
            suggestedAction: freezed == suggestedAction
                ? _value.suggestedAction
                : suggestedAction // ignore: cast_nullable_to_non_nullable
                      as SuggestedAction?,
            eventPayload: freezed == eventPayload
                ? _value.eventPayload
                : eventPayload // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
          )
          as $Val,
    );
  }

  /// Create a copy of AiFeedback
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SuggestedActionCopyWith<$Res>? get suggestedAction {
    if (_value.suggestedAction == null) {
      return null;
    }

    return $SuggestedActionCopyWith<$Res>(_value.suggestedAction!, (value) {
      return _then(_value.copyWith(suggestedAction: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AiFeedbackImplCopyWith<$Res>
    implements $AiFeedbackCopyWith<$Res> {
  factory _$$AiFeedbackImplCopyWith(
    _$AiFeedbackImpl value,
    $Res Function(_$AiFeedbackImpl) then,
  ) = __$$AiFeedbackImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool mock,
    String speechText,
    String screenText,
    SuggestedAction? suggestedAction,
    Map<String, dynamic>? eventPayload,
  });

  @override
  $SuggestedActionCopyWith<$Res>? get suggestedAction;
}

/// @nodoc
class __$$AiFeedbackImplCopyWithImpl<$Res>
    extends _$AiFeedbackCopyWithImpl<$Res, _$AiFeedbackImpl>
    implements _$$AiFeedbackImplCopyWith<$Res> {
  __$$AiFeedbackImplCopyWithImpl(
    _$AiFeedbackImpl _value,
    $Res Function(_$AiFeedbackImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AiFeedback
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mock = null,
    Object? speechText = null,
    Object? screenText = null,
    Object? suggestedAction = freezed,
    Object? eventPayload = freezed,
  }) {
    return _then(
      _$AiFeedbackImpl(
        mock: null == mock
            ? _value.mock
            : mock // ignore: cast_nullable_to_non_nullable
                  as bool,
        speechText: null == speechText
            ? _value.speechText
            : speechText // ignore: cast_nullable_to_non_nullable
                  as String,
        screenText: null == screenText
            ? _value.screenText
            : screenText // ignore: cast_nullable_to_non_nullable
                  as String,
        suggestedAction: freezed == suggestedAction
            ? _value.suggestedAction
            : suggestedAction // ignore: cast_nullable_to_non_nullable
                  as SuggestedAction?,
        eventPayload: freezed == eventPayload
            ? _value._eventPayload
            : eventPayload // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AiFeedbackImpl implements _AiFeedback {
  const _$AiFeedbackImpl({
    this.mock = false,
    this.speechText = '',
    this.screenText = '',
    this.suggestedAction,
    final Map<String, dynamic>? eventPayload,
  }) : _eventPayload = eventPayload;

  factory _$AiFeedbackImpl.fromJson(Map<String, dynamic> json) =>
      _$$AiFeedbackImplFromJson(json);

  @override
  @JsonKey()
  final bool mock;
  @override
  @JsonKey()
  final String speechText;
  @override
  @JsonKey()
  final String screenText;
  @override
  final SuggestedAction? suggestedAction;
  final Map<String, dynamic>? _eventPayload;
  @override
  Map<String, dynamic>? get eventPayload {
    final value = _eventPayload;
    if (value == null) return null;
    if (_eventPayload is EqualUnmodifiableMapView) return _eventPayload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'AiFeedback(mock: $mock, speechText: $speechText, screenText: $screenText, suggestedAction: $suggestedAction, eventPayload: $eventPayload)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiFeedbackImpl &&
            (identical(other.mock, mock) || other.mock == mock) &&
            (identical(other.speechText, speechText) ||
                other.speechText == speechText) &&
            (identical(other.screenText, screenText) ||
                other.screenText == screenText) &&
            (identical(other.suggestedAction, suggestedAction) ||
                other.suggestedAction == suggestedAction) &&
            const DeepCollectionEquality().equals(
              other._eventPayload,
              _eventPayload,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    mock,
    speechText,
    screenText,
    suggestedAction,
    const DeepCollectionEquality().hash(_eventPayload),
  );

  /// Create a copy of AiFeedback
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiFeedbackImplCopyWith<_$AiFeedbackImpl> get copyWith =>
      __$$AiFeedbackImplCopyWithImpl<_$AiFeedbackImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AiFeedbackImplToJson(this);
  }
}

abstract class _AiFeedback implements AiFeedback {
  const factory _AiFeedback({
    final bool mock,
    final String speechText,
    final String screenText,
    final SuggestedAction? suggestedAction,
    final Map<String, dynamic>? eventPayload,
  }) = _$AiFeedbackImpl;

  factory _AiFeedback.fromJson(Map<String, dynamic> json) =
      _$AiFeedbackImpl.fromJson;

  @override
  bool get mock;
  @override
  String get speechText;
  @override
  String get screenText;
  @override
  SuggestedAction? get suggestedAction;
  @override
  Map<String, dynamic>? get eventPayload;

  /// Create a copy of AiFeedback
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiFeedbackImplCopyWith<_$AiFeedbackImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SuggestedAction _$SuggestedActionFromJson(Map<String, dynamic> json) {
  return _SuggestedAction.fromJson(json);
}

/// @nodoc
mixin _$SuggestedAction {
  String get type => throw _privateConstructorUsedError;
  int? get seconds => throw _privateConstructorUsedError;

  /// Serializes this SuggestedAction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SuggestedAction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SuggestedActionCopyWith<SuggestedAction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SuggestedActionCopyWith<$Res> {
  factory $SuggestedActionCopyWith(
    SuggestedAction value,
    $Res Function(SuggestedAction) then,
  ) = _$SuggestedActionCopyWithImpl<$Res, SuggestedAction>;
  @useResult
  $Res call({String type, int? seconds});
}

/// @nodoc
class _$SuggestedActionCopyWithImpl<$Res, $Val extends SuggestedAction>
    implements $SuggestedActionCopyWith<$Res> {
  _$SuggestedActionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SuggestedAction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? seconds = freezed}) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            seconds: freezed == seconds
                ? _value.seconds
                : seconds // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SuggestedActionImplCopyWith<$Res>
    implements $SuggestedActionCopyWith<$Res> {
  factory _$$SuggestedActionImplCopyWith(
    _$SuggestedActionImpl value,
    $Res Function(_$SuggestedActionImpl) then,
  ) = __$$SuggestedActionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String type, int? seconds});
}

/// @nodoc
class __$$SuggestedActionImplCopyWithImpl<$Res>
    extends _$SuggestedActionCopyWithImpl<$Res, _$SuggestedActionImpl>
    implements _$$SuggestedActionImplCopyWith<$Res> {
  __$$SuggestedActionImplCopyWithImpl(
    _$SuggestedActionImpl _value,
    $Res Function(_$SuggestedActionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SuggestedAction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? type = null, Object? seconds = freezed}) {
    return _then(
      _$SuggestedActionImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        seconds: freezed == seconds
            ? _value.seconds
            : seconds // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SuggestedActionImpl extends _SuggestedAction {
  const _$SuggestedActionImpl({required this.type, this.seconds}) : super._();

  factory _$SuggestedActionImpl.fromJson(Map<String, dynamic> json) =>
      _$$SuggestedActionImplFromJson(json);

  @override
  final String type;
  @override
  final int? seconds;

  @override
  String toString() {
    return 'SuggestedAction(type: $type, seconds: $seconds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SuggestedActionImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.seconds, seconds) || other.seconds == seconds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, seconds);

  /// Create a copy of SuggestedAction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SuggestedActionImplCopyWith<_$SuggestedActionImpl> get copyWith =>
      __$$SuggestedActionImplCopyWithImpl<_$SuggestedActionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SuggestedActionImplToJson(this);
  }
}

abstract class _SuggestedAction extends SuggestedAction {
  const factory _SuggestedAction({
    required final String type,
    final int? seconds,
  }) = _$SuggestedActionImpl;
  const _SuggestedAction._() : super._();

  factory _SuggestedAction.fromJson(Map<String, dynamic> json) =
      _$SuggestedActionImpl.fromJson;

  @override
  String get type;
  @override
  int? get seconds;

  /// Create a copy of SuggestedAction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SuggestedActionImplCopyWith<_$SuggestedActionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
