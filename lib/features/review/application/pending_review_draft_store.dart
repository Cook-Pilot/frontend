import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../cooking/domain/cooking_setup_snapshot.dart';

typedef PendingReviewPreferencesLoader = Future<SharedPreferences> Function();

/// 앱이 종료돼도 다시 열 수 있는 한 건의 작성 중 후기.
///
/// 후기 초안은 서버 전송값이 아니다. 사용자가 저장을 확정하기 전까지
/// 조리완료 사실과 현재 입력값을 기기 안에 보존하는 복구 스냅샷이다.
@immutable
final class PendingReviewDraft {
  factory PendingReviewDraft({
    required String clientSessionId,
    required DateTime cookedAt,
    required CookingSetupSnapshot setupSnapshot,
    required Map<int, int> timerSecondsByStep,
    required int rating,
    required String comment,
    required String nextTimeNote,
    required bool approvedPersonalVersionCreation,
  }) {
    _requireCanonicalUuid(clientSessionId, 'clientSessionId');
    _validateSetupSnapshot(setupSnapshot);
    if (rating < minimumRating || rating > maximumRating) {
      throw ArgumentError.value(
        rating,
        'rating',
        'must be between $minimumRating and $maximumRating',
      );
    }
    _validateReviewText(
      comment,
      maximumCodePoints: maximumCommentCodePoints,
      field: 'comment',
    );
    _validateReviewText(
      nextTimeNote,
      maximumCodePoints: maximumNextTimeNoteCodePoints,
      field: 'nextTimeNote',
    );
    final timers = _validatedTimerSeconds(
      timerSecondsByStep,
      stepCount: setupSnapshot.steps.length,
    );
    return PendingReviewDraft._(
      clientSessionId: clientSessionId,
      cookedAt: cookedAt.toUtc(),
      setupSnapshot: setupSnapshot,
      timerSecondsByStep: timers,
      rating: rating,
      comment: comment,
      nextTimeNote: nextTimeNote,
      approvedPersonalVersionCreation: approvedPersonalVersionCreation,
    );
  }

  const PendingReviewDraft._({
    required this.clientSessionId,
    required this.cookedAt,
    required this.setupSnapshot,
    required this.timerSecondsByStep,
    required this.rating,
    required this.comment,
    required this.nextTimeNote,
    required this.approvedPersonalVersionCreation,
  });

  static const currentSchemaVersion = 1;
  static const minimumRating = 1;
  static const maximumRating = 5;
  static const maximumCommentCodePoints = 1000;
  static const maximumNextTimeNoteCodePoints = 500;
  static const maximumTimerSeconds = 2147483647;

  static const _jsonFields = <String>{
    'schemaVersion',
    'clientSessionId',
    'cookedAt',
    'setupSnapshot',
    'timerSecondsByStep',
    'rating',
    'comment',
    'nextTimeNote',
    'approvedPersonalVersionCreation',
  };

  static const _setupSnapshotJsonFields = <String>{
    'schemaVersion',
    'recipeId',
    'title',
    'description',
    'imageUrl',
    'baseServings',
    'targetServings',
    'source',
    'personalVersionId',
    'ingredients',
    'steps',
  };

  static const _legacySetupIngredientJsonFields = <String>{
    'originalIngredientId',
    'originalName',
    'name',
    'amount',
    'baselineAmount',
    'unit',
    'isRequired',
    'omitted',
  };

  static const _currentSetupIngredientJsonFields = <String>{
    ..._legacySetupIngredientJsonFields,
    'baselineUnit',
    'baselineIsRequired',
  };

  static const _setupStepJsonFields = <String>{
    'originalStepId',
    'stepIndex',
    'instruction',
    'timerSeconds',
    'cautionNote',
    'imageUrl',
  };

  final String clientSessionId;
  final DateTime cookedAt;
  final CookingSetupSnapshot setupSnapshot;
  final Map<int, int> timerSecondsByStep;
  final int rating;
  final String comment;
  final String nextTimeNote;
  final bool approvedPersonalVersionCreation;

  PendingReviewDraft copyWith({
    int? rating,
    String? comment,
    String? nextTimeNote,
    bool? approvedPersonalVersionCreation,
  }) {
    return PendingReviewDraft(
      clientSessionId: clientSessionId,
      cookedAt: cookedAt,
      setupSnapshot: setupSnapshot,
      timerSecondsByStep: timerSecondsByStep,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      nextTimeNote: nextTimeNote ?? this.nextTimeNote,
      approvedPersonalVersionCreation:
          approvedPersonalVersionCreation ??
          this.approvedPersonalVersionCreation,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'clientSessionId': clientSessionId,
    'cookedAt': cookedAt.toUtc().toIso8601String(),
    'setupSnapshot': setupSnapshot.toJson(),
    'timerSecondsByStep': timerSecondsByStep.map(
      (stepIndex, seconds) => MapEntry(stepIndex.toString(), seconds),
    ),
    'rating': rating,
    'comment': comment,
    'nextTimeNote': nextTimeNote,
    'approvedPersonalVersionCreation': approvedPersonalVersionCreation,
  };

  /// 저장소 입력을 엄격히 읽는다. 현재 최상위 스키마의 필드가 빠지거나
  /// 추가돼도, 또는 중첩 실행 스냅샷이 유효하지 않아도 복구값으로 사용하지
  /// 않는다.
  static PendingReviewDraft? fromJson(Map<String, Object?> json) {
    if (json.length != _jsonFields.length ||
        !_jsonFields.every(json.containsKey) ||
        json['schemaVersion'] != currentSchemaVersion) {
      return null;
    }
    if (json case {
      'clientSessionId': final String clientSessionId,
      'cookedAt': final String cookedAtValue,
      'setupSnapshot': final Map setupSnapshotValue,
      'timerSecondsByStep': final Map timerValues,
      'rating': final int rating,
      'comment': final String comment,
      'nextTimeNote': final String nextTimeNote,
      'approvedPersonalVersionCreation': final bool approved,
    }) {
      try {
        final cookedAt = DateTime.tryParse(cookedAtValue);
        if (cookedAt == null ||
            !cookedAt.isUtc ||
            cookedAt.toIso8601String() != cookedAtValue) {
          return null;
        }
        final setupSnapshotJson = _normalizeSetupSnapshotJson(
          Map<String, Object?>.from(setupSnapshotValue),
        );
        if (setupSnapshotJson == null) {
          return null;
        }
        final setupSnapshot = CookingSetupSnapshot.fromJson(setupSnapshotJson);
        if (setupSnapshot == null) {
          return null;
        }
        final timerSecondsByStep = <int, int>{};
        for (final MapEntry(key: key, value: value) in timerValues.entries) {
          if (key is! String || value is! int) {
            return null;
          }
          final stepIndex = int.tryParse(key);
          if (stepIndex == null || key != stepIndex.toString()) {
            return null;
          }
          timerSecondsByStep[stepIndex] = value;
        }
        return PendingReviewDraft(
          clientSessionId: clientSessionId,
          cookedAt: cookedAt,
          setupSnapshot: setupSnapshot,
          timerSecondsByStep: timerSecondsByStep,
          rating: rating,
          comment: comment,
          nextTimeNote: nextTimeNote,
          approvedPersonalVersionCreation: approved,
        );
      } on Object {
        return null;
      }
    }
    return null;
  }

  static Map<String, Object?>? _normalizeSetupSnapshotJson(
    Map<String, Object?> json,
  ) {
    if (!_hasExactFields(json, _setupSnapshotJsonFields) ||
        json['schemaVersion'] != CookingSetupSnapshot.currentSchemaVersion) {
      return null;
    }
    final ingredientValues = json['ingredients'];
    final stepValues = json['steps'];
    if (ingredientValues is! List || stepValues is! List) {
      return null;
    }
    // PR #35 used the same outer schema and storage key, but every ingredient
    // omitted these two baseline fields. Accept only that complete legacy shape.
    bool? usesLegacyIngredientShape;
    final normalizedIngredientValues = <Object?>[];
    for (final value in ingredientValues) {
      if (value is! Map) {
        return null;
      }
      final ingredientJson = Map<String, Object?>.from(value);
      final isCurrent = _hasExactFields(
        ingredientJson,
        _currentSetupIngredientJsonFields,
      );
      final isLegacy = _hasExactFields(
        ingredientJson,
        _legacySetupIngredientJsonFields,
      );
      if ((!isCurrent && !isLegacy) || ingredientJson['omitted'] is! bool) {
        return null;
      }
      if (usesLegacyIngredientShape != null &&
          usesLegacyIngredientShape != isLegacy) {
        return null;
      }
      usesLegacyIngredientShape ??= isLegacy;
      normalizedIngredientValues.add(
        isLegacy
            ? <String, Object?>{
                ...ingredientJson,
                'baselineUnit': null,
                'baselineIsRequired': null,
              }
            : ingredientJson,
      );
    }
    for (final value in stepValues) {
      if (value is! Map ||
          !_hasExactFields(
            Map<String, Object?>.from(value),
            _setupStepJsonFields,
          )) {
        return null;
      }
    }
    return <String, Object?>{
      ...json,
      'ingredients': normalizedIngredientValues,
    };
  }

  static bool _hasExactFields(
    Map<String, Object?> json,
    Set<String> expectedFields,
  ) =>
      json.length == expectedFields.length &&
      expectedFields.every(json.containsKey);
}

/// 데모에서 작성 중인 후기 한 건만 보관하는 SharedPreferences 저장소.
///
/// 모든 인스턴스가 같은 직렬화 큐를 공유한다. 앞선 저장이 늦게 끝나더라도
/// 뒤에 요청한 저장보다 나중에 디스크에 반영되어 최신 초안을 덮어쓸 수 없다.
final class PendingReviewDraftStore {
  PendingReviewDraftStore({PendingReviewPreferencesLoader? preferencesLoader})
    : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const storageKey = 'cookpilot.pending_review_draft.v1';

  static Future<void> _operationTail = Future<void>.value();

  final PendingReviewPreferencesLoader _preferencesLoader;

  Future<void> save(PendingReviewDraft draft) {
    return _serialize(() async {
      final preferences = await _preferencesLoader();
      final encodedDraft = jsonEncode(draft.toJson());
      final cachedBeforeWrite = _copyCachedValue(preferences.get(storageKey));
      late final Object writeError;
      late final StackTrace writeStackTrace;
      try {
        final saved = await preferences.setString(storageKey, encodedDraft);
        if (saved) {
          return;
        }
        writeError = StateError('후기 초안을 로컬에 저장하지 못했습니다.');
        writeStackTrace = StackTrace.current;
      } on Object catch (error, stackTrace) {
        writeError = error;
        writeStackTrace = stackTrace;
      }

      // SharedPreferences는 플랫폼 저장 결과를 기다리기 전에 메모리 캐시를
      // 갱신한다. 디스크 reload까지 실패하면 작업 전 캐시를 best-effort로
      // 되돌리고, 복구 오류가 최초 저장 오류와 stack을 가리지 않게 한다.
      await _recoverCacheAfterFailedMutation(preferences, cachedBeforeWrite);
      Error.throwWithStackTrace(writeError, writeStackTrace);
    });
  }

  /// 저장값이 없거나 손상됐으면 null을 반환한다.
  ///
  /// 손상된 타입·JSON·스키마·도메인 값은 같은 직렬화 큐 안에서 제거해 다음
  /// 실행에서 반복해서 복구를 시도하지 않게 한다.
  Future<PendingReviewDraft?> load() {
    return _serialize(() async {
      final preferences = await _preferencesLoader();
      final raw = preferences.get(storageKey);
      if (raw == null) {
        return null;
      }
      PendingReviewDraft? draft;
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            draft = PendingReviewDraft.fromJson(
              Map<String, Object?>.from(decoded),
            );
          }
        } on Object {
          draft = null;
        }
      }
      if (draft != null) {
        return draft;
      }
      await _removeBestEffort(preferences);
      return null;
    });
  }

  Future<void> clear() {
    return _serialize(() async {
      final preferences = await _preferencesLoader();
      final cachedBeforeRemove = _copyCachedValue(preferences.get(storageKey));
      late final Object removeError;
      late final StackTrace removeStackTrace;
      try {
        final removed = await preferences.remove(storageKey);
        if (removed) {
          return;
        }
        removeError = StateError('후기 초안을 로컬에서 정리하지 못했습니다.');
        removeStackTrace = StackTrace.current;
      } on Object catch (error, stackTrace) {
        removeError = error;
        removeStackTrace = stackTrace;
      }

      // remove도 플랫폼 결과보다 먼저 메모리 캐시를 지운다. false 반환과
      // 예외를 같은 경로에서 복구하고, reload 실패 시에는 작업 전 캐시를
      // 되돌린 뒤 최초 remove 오류와 stack을 그대로 전달한다.
      await _recoverCacheAfterFailedMutation(preferences, cachedBeforeRemove);
      Error.throwWithStackTrace(removeError, removeStackTrace);
    });
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operationTail.then((_) => operation());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  static Future<void> _removeBestEffort(SharedPreferences preferences) async {
    final cachedBeforeRemove = _copyCachedValue(preferences.get(storageKey));
    try {
      final removed = await preferences.remove(storageKey);
      if (removed) {
        return;
      }
    } on Object {
      // false 반환과 예외 모두 아래에서 디스크 상태를 다시 읽는다.
    }

    // remove는 플랫폼 결과보다 먼저 메모리 캐시를 지운다. reload까지
    // 실패해도 손상값을 작업 전 캐시에 복원해 다음 load가 정리를 재시도한다.
    await _recoverCacheAfterFailedMutation(preferences, cachedBeforeRemove);
  }

  static Object? _copyCachedValue(Object? value) {
    return value is List<String> ? List<String>.of(value) : value;
  }

  static Future<void> _recoverCacheAfterFailedMutation(
    SharedPreferences preferences,
    Object? cachedBeforeMutation,
  ) async {
    try {
      await preferences.reload();
      return;
    } on Object {
      // reload가 성공하면 디스크 상태를 신뢰한다. 실패한 경우에만 아래의
      // eager cache 변이를 이용해 작업 전 상태를 best-effort로 되돌린다.
    }

    try {
      if (cachedBeforeMutation == null) {
        await preferences.remove(storageKey);
      } else if (cachedBeforeMutation is bool) {
        await preferences.setBool(storageKey, cachedBeforeMutation);
      } else if (cachedBeforeMutation is int) {
        await preferences.setInt(storageKey, cachedBeforeMutation);
      } else if (cachedBeforeMutation is double) {
        await preferences.setDouble(storageKey, cachedBeforeMutation);
      } else if (cachedBeforeMutation is String) {
        await preferences.setString(storageKey, cachedBeforeMutation);
      } else if (cachedBeforeMutation is List<String>) {
        await preferences.setStringList(storageKey, cachedBeforeMutation);
      }
    } on Object {
      // setter/remove는 플랫폼 Future를 만들기 전에 캐시를 바꾼다. 반환값과
      // 예외는 복구에 영향을 주지 않으며 최초 save/clear 오류도 가리지 않는다.
    }
  }
}

final _canonicalUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-'
  r'[0-9a-f]{4}-[0-9a-f]{12}$',
);

const _nilUuid = '00000000-0000-0000-0000-000000000000';

void _requireCanonicalUuid(String value, String field) {
  if (!_canonicalUuidPattern.hasMatch(value) || value == _nilUuid) {
    throw ArgumentError.value(value, field, 'must be a canonical UUID');
  }
}

void _validateSetupSnapshot(CookingSetupSnapshot snapshot) {
  _requireCanonicalUuid(snapshot.recipeId, 'setupSnapshot.recipeId');
  if (!snapshot.baseServings.isFinite || snapshot.baseServings <= 0) {
    throw ArgumentError.value(
      snapshot.baseServings,
      'setupSnapshot.baseServings',
      'must be a positive finite number',
    );
  }
  if (snapshot.targetServings < 1) {
    throw ArgumentError.value(
      snapshot.targetServings,
      'setupSnapshot.targetServings',
      'must be at least 1',
    );
  }
  if (snapshot.steps.isEmpty) {
    throw ArgumentError.value(
      snapshot.steps,
      'setupSnapshot.steps',
      'must contain at least one step',
    );
  }
  final personalVersionId = snapshot.personalVersionId;
  if (personalVersionId != null) {
    _requireCanonicalUuid(personalVersionId, 'setupSnapshot.personalVersionId');
  }
  if ((snapshot.source == CookingRecipeSource.personal) !=
      (personalVersionId != null)) {
    throw ArgumentError.value(
      snapshot.source,
      'setupSnapshot.source',
      'must agree with personalVersionId',
    );
  }
  for (final ingredient in snapshot.ingredients) {
    final originalIngredientId = ingredient.originalIngredientId;
    if (originalIngredientId != null) {
      _requireCanonicalUuid(
        originalIngredientId,
        'setupSnapshot.ingredients.originalIngredientId',
      );
    }
    _validateDatabaseText(
      ingredient.name,
      field: 'setupSnapshot.ingredients.name',
    );
    _validateDatabaseText(
      ingredient.unit,
      field: 'setupSnapshot.ingredients.unit',
    );
    final amount = ingredient.amount;
    if (amount != null && (!amount.isFinite || amount < 0)) {
      throw ArgumentError.value(
        amount,
        'setupSnapshot.ingredients.amount',
        'must be nonnegative and finite when present',
      );
    }
    final baselineAmount = ingredient.baselineAmount;
    if (baselineAmount != null &&
        (!baselineAmount.isFinite || baselineAmount < 0)) {
      throw ArgumentError.value(
        baselineAmount,
        'setupSnapshot.ingredients.baselineAmount',
        'must be nonnegative and finite when present',
      );
    }
  }
  for (final (index, step) in snapshot.steps.indexed) {
    if (step.stepIndex != index) {
      throw ArgumentError.value(
        step.stepIndex,
        'setupSnapshot.steps.stepIndex',
        'must be zero-based and contiguous',
      );
    }
    final originalStepId = step.originalStepId;
    if (originalStepId != null) {
      _requireCanonicalUuid(
        originalStepId,
        'setupSnapshot.steps.originalStepId',
      );
    }
    _validateDatabaseText(
      step.instruction,
      field: 'setupSnapshot.steps.instruction',
    );
    final cautionNote = step.cautionNote;
    if (cautionNote != null) {
      _validateDatabaseText(
        cautionNote,
        field: 'setupSnapshot.steps.cautionNote',
      );
    }
    final timerSeconds = step.timerSeconds;
    if (timerSeconds != null &&
        (timerSeconds < 0 ||
            timerSeconds > PendingReviewDraft.maximumTimerSeconds)) {
      throw ArgumentError.value(
        timerSeconds,
        'setupSnapshot.steps.timerSeconds',
        'must be within the supported integer range',
      );
    }
  }
}

Map<int, int> _validatedTimerSeconds(
  Map<int, int> value, {
  required int stepCount,
}) {
  final keys = value.keys.toList(growable: false)..sort();
  final result = <int, int>{};
  for (final stepIndex in keys) {
    final seconds = value[stepIndex]!;
    if (stepIndex < 0 || stepIndex >= stepCount) {
      throw ArgumentError.value(
        stepIndex,
        'timerSecondsByStep',
        'contains a step outside the setup snapshot',
      );
    }
    if (seconds < 0 || seconds > PendingReviewDraft.maximumTimerSeconds) {
      throw ArgumentError.value(
        seconds,
        'timerSecondsByStep',
        'contains seconds outside the supported integer range',
      );
    }
    result[stepIndex] = seconds;
  }
  return Map<int, int>.unmodifiable(result);
}

void _validateReviewText(
  String value, {
  required int maximumCodePoints,
  required String field,
}) {
  _validateDatabaseText(
    value,
    field: field,
    maximumCodePoints: maximumCodePoints,
  );
}

void _validateDatabaseText(
  String value, {
  required String field,
  int? maximumCodePoints,
}) {
  var codePointCount = 0;
  for (var index = 0; index < value.length; index += 1) {
    final codeUnit = value.codeUnitAt(index);
    if (codeUnit == 0) {
      throw ArgumentError.value(value, field, 'cannot contain NUL');
    }
    if (codeUnit >= 0xd800 && codeUnit <= 0xdbff) {
      if (index + 1 >= value.length) {
        throw ArgumentError.value(value, field, 'contains invalid Unicode');
      }
      final next = value.codeUnitAt(index + 1);
      if (next < 0xdc00 || next > 0xdfff) {
        throw ArgumentError.value(value, field, 'contains invalid Unicode');
      }
      index += 1;
    } else if (codeUnit >= 0xdc00 && codeUnit <= 0xdfff) {
      throw ArgumentError.value(value, field, 'contains invalid Unicode');
    }
    codePointCount += 1;
    if (maximumCodePoints != null && codePointCount > maximumCodePoints) {
      throw ArgumentError.value(
        value,
        field,
        'must be at most $maximumCodePoints characters',
      );
    }
  }
}
