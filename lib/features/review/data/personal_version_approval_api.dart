import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import '../../cooking/domain/cooking_setup_snapshot.dart';
import '../../auth/data/auth_session.dart';

enum PersonalVersionIngredientAdjustmentType {
  add('ADD'),
  modify('MODIFY'),
  remove('REMOVE');

  const PersonalVersionIngredientAdjustmentType(this.apiValue);

  final String apiValue;
}

@immutable
final class PersonalVersionIngredientAdjustment {
  const PersonalVersionIngredientAdjustment({
    required this.type,
    required this.sortOrder,
    this.originalIngredientId,
    this.name,
    this.amount,
    required this.includeAmount,
    this.unit,
    this.required,
  });

  final String? originalIngredientId;
  final PersonalVersionIngredientAdjustmentType type;
  final String? name;
  final double? amount;

  /// `amount` 값이 null이어도 JSON 키를 명시할지 구분한다.
  final bool includeAmount;
  final String? unit;
  final bool? required;
  final int sortOrder;

  Map<String, Object?> toJson() => <String, Object?>{
    if (originalIngredientId != null)
      'originalIngredientId': originalIngredientId,
    'type': type.apiValue,
    if (name != null) 'name': name,
    if (includeAmount) 'amount': amount,
    if (unit != null) 'unit': unit,
    if (required != null) 'required': required,
    'sortOrder': sortOrder,
  };
}

sealed class PersonalVersionApprovalPreflightResult {
  const PersonalVersionApprovalPreflightResult();
}

final class PersonalVersionApprovalReady
    extends PersonalVersionApprovalPreflightResult {
  const PersonalVersionApprovalReady();
}

final class PersonalVersionApprovalRequiresReanchor
    extends PersonalVersionApprovalPreflightResult {
  const PersonalVersionApprovalRequiresReanchor();

  String get message => '이전 앱 버전에서 저장한 개인 레시피 후기는 원본 재료를 다시 확인한 뒤 승인해야 합니다.';
}

/// 개인 버전 요청이 안전한지 후기 저장 전에 동기적으로 판정한다.
///
/// 이 결과는 네트워크 상태와 무관하다. UI는 차단 결과를 후기 POST 전에
/// 안내해 사용자가 개인 버전 동의를 끄고 후기만 저장할 수 있게 해야 한다.
PersonalVersionApprovalPreflightResult preflightPersonalVersionApproval(
  CookingSetupSnapshot snapshot,
) {
  if (snapshot.source != CookingRecipeSource.personal) {
    return const PersonalVersionApprovalReady();
  }

  // PR #35의 schema-v1 초안은 개인 버전의 합성 재료만 저장했다. 원본의
  // unit/required baseline과 REMOVE된 재료가 없으므로 여기서 ADD/MODIFY를
  // 추측하면 다음 개인 버전이 부모 diff를 잃는다. 새 스냅샷은 원본에
  // re-anchor하면서 모든 재료(ADD/REMOVE 포함)에 두 baseline을 채운다.
  final requiresReanchor =
      snapshot.ingredients.isEmpty ||
      snapshot.ingredients.any(
        (ingredient) =>
            ingredient.baselineUnit == null ||
            ingredient.baselineIsRequired == null,
      );
  return requiresReanchor
      ? const PersonalVersionApprovalRequiresReanchor()
      : const PersonalVersionApprovalReady();
}

/// PR #37의 개인 레시피 생성 요청을 조리 시작 시점 snapshot에서 만든다.
///
/// 재료 diff는 원본 레시피 기준 누적 결과다. 현재 조리 준비 UI에는 단계 편집이
/// 없으므로 stepAdjustments는 항상 비어 있다. 조리 중 타이머 변경 역시 setup
/// 편집이 아니므로 이 요청에 포함하지 않는다.
@immutable
final class PersonalVersionApprovalRequest {
  PersonalVersionApprovalRequest._({
    required List<PersonalVersionIngredientAdjustment> ingredientAdjustments,
    required this.cookingTranscript,
  }) : ingredientAdjustments = List.unmodifiable(ingredientAdjustments);

  factory PersonalVersionApprovalRequest.fromSnapshot({
    required CookingSetupSnapshot snapshot,
    String? cookingTranscript,
  }) {
    if (preflightPersonalVersionApproval(snapshot)
        case PersonalVersionApprovalRequiresReanchor(:final message)) {
      throw PersonalVersionApprovalApiException(message);
    }
    final adjustments = <PersonalVersionIngredientAdjustment>[];
    for (final (sortOrder, ingredient) in snapshot.ingredients.indexed) {
      final adjustment = _mapIngredient(ingredient, sortOrder);
      if (adjustment != null) {
        adjustments.add(adjustment);
      }
    }
    final trimmedTranscript = cookingTranscript?.trim();
    return PersonalVersionApprovalRequest._(
      ingredientAdjustments: adjustments,
      cookingTranscript: trimmedTranscript == null || trimmedTranscript.isEmpty
          ? null
          : trimmedTranscript,
    );
  }

  final List<PersonalVersionIngredientAdjustment> ingredientAdjustments;
  final String? cookingTranscript;

  Map<String, Object?> toJson() => <String, Object?>{
    'setup': <String, Object?>{
      'ingredientAdjustments': ingredientAdjustments
          .map((adjustment) => adjustment.toJson())
          .toList(growable: false),
      'stepAdjustments': const <Object?>[],
    },
    'cooking': <String, Object?>{'transcript': cookingTranscript},
  };
}

sealed class PersonalVersionApprovalResult {
  const PersonalVersionApprovalResult();
}

final class PersonalVersionCreated extends PersonalVersionApprovalResult {
  const PersonalVersionCreated();
}

final class PersonalVersionNoChange extends PersonalVersionApprovalResult {
  const PersonalVersionNoChange();
}

final class PersonalVersionApprovalApiException implements Exception {
  const PersonalVersionApprovalApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract interface class PersonalVersionApprovalGateway {
  Future<PersonalVersionApprovalResult> createFromApprovedReview({
    required String reviewId,
    required CookingSetupSnapshot snapshot,
    String? cookingTranscript,
  });
}

/// 사용자가 개인 버전 적용을 승인한 뒤 호출하는 PR #37 HTTP 어댑터.
///
/// 승인 여부는 UI/application caller가 결정한다. 이 클래스는 호출되면 별도의
/// 자동 판정 없이 요청을 전송한다.
final class PersonalVersionApprovalApi
    implements PersonalVersionApprovalGateway {
  PersonalVersionApprovalApi({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? cookPilotApiBaseUrl();

  final http.Client _client;
  final String _baseUrl;
  final Duration timeout;

  @override
  Future<PersonalVersionApprovalResult> createFromApprovedReview({
    required String reviewId,
    required CookingSetupSnapshot snapshot,
    String? cookingTranscript,
  }) async {
    final normalizedReviewId = reviewId.trim();
    if (normalizedReviewId.isEmpty) {
      throw const PersonalVersionApprovalApiException('reviewId는 필수입니다.');
    }
    final request = PersonalVersionApprovalRequest.fromSnapshot(
      snapshot: snapshot,
      cookingTranscript: cookingTranscript,
    );
    final response = await _translateTransportErrors(
      () => _client
          .post(
            Uri.parse(
              '$_baseUrl/api/v1/reviews/$normalizedReviewId/'
              'personal-versions',
            ),
            headers: <String, String>{
              ...AuthSession.requestHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(timeout),
    );

    if (response.statusCode == 204) {
      return const PersonalVersionNoChange();
    }
    if (response.statusCode != 201) {
      throw PersonalVersionApprovalApiException(
        _statusMessage(response.statusCode),
        statusCode: response.statusCode,
      );
    }

    // PR #37의 생성 성공 body는 현재 createdAt이 null일 수 있고, caller는
    // 별도의 버전 상세가 아니라 생성 여부만 필요하다. 201 status만 신뢰한다.
    return const PersonalVersionCreated();
  }

  Future<T> _translateTransportErrors<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on TimeoutException {
      throw const PersonalVersionApprovalApiException('서버 응답 시간이 초과되었습니다.');
    } on http.ClientException {
      throw const PersonalVersionApprovalApiException('서버에 연결하지 못했습니다.');
    }
  }
}

PersonalVersionIngredientAdjustment? _mapIngredient(
  CookingSetupIngredient ingredient,
  int sortOrder,
) {
  final originalIngredientId = ingredient.originalIngredientId;
  if (originalIngredientId == null) {
    if (ingredient.omitted) {
      return null;
    }
    return PersonalVersionIngredientAdjustment(
      type: PersonalVersionIngredientAdjustmentType.add,
      name: ingredient.name,
      amount: ingredient.amount,
      includeAmount: true,
      unit: ingredient.unit,
      required: ingredient.isRequired,
      sortOrder: sortOrder,
    );
  }
  if (ingredient.omitted) {
    return PersonalVersionIngredientAdjustment(
      originalIngredientId: originalIngredientId,
      type: PersonalVersionIngredientAdjustmentType.remove,
      includeAmount: false,
      sortOrder: sortOrder,
    );
  }

  final changedName = ingredient.name != ingredient.originalName;
  final changedAmount = !_sameAmount(
    ingredient.amount,
    ingredient.baselineAmount,
  );
  final changedUnit =
      ingredient.unit != (ingredient.baselineUnit ?? ingredient.unit);
  final changedRequired =
      ingredient.isRequired !=
      (ingredient.baselineIsRequired ?? ingredient.isRequired);
  if (!changedName && !changedAmount && !changedUnit && !changedRequired) {
    return null;
  }
  return PersonalVersionIngredientAdjustment(
    originalIngredientId: originalIngredientId,
    type: PersonalVersionIngredientAdjustmentType.modify,
    name: changedName ? ingredient.name : null,
    amount: changedAmount ? ingredient.amount : null,
    includeAmount: changedAmount,
    unit: changedUnit ? ingredient.unit : null,
    required: changedRequired ? ingredient.isRequired : null,
    sortOrder: sortOrder,
  );
}

bool _sameAmount(double? left, double? right) {
  if (left == null || right == null) {
    return left == right;
  }
  return (left - right).abs() < 0.0001;
}

String _statusMessage(int statusCode) => switch (statusCode) {
  400 => '개인 레시피 생성 요청 정보가 올바르지 않습니다.',
  401 => '사용자 세션을 확인할 수 없습니다.',
  404 => '개인 레시피를 만들 후기 기록을 찾지 못했습니다.',
  409 => '개인 레시피 생성 요청이 현재 상태와 충돌합니다.',
  _ => '개인 레시피를 만들지 못했습니다. ($statusCode)',
};
