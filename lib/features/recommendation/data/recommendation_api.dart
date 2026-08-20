import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_session.dart';

enum RecommendationDecision {
  accepted('ACCEPTED'),
  rejected('REJECTED'),
  modified('MODIFIED');

  const RecommendationDecision(this.apiValue);

  final String apiValue;
}

class RecommendationEvidence {
  const RecommendationEvidence({
    required this.reviewId,
    required this.recipeId,
    required this.recipeTitle,
    required this.cookedAt,
    required this.rating,
  });

  factory RecommendationEvidence.fromJson(Map<String, dynamic> json) {
    return RecommendationEvidence(
      reviewId: _requiredString(json, 'reviewId'),
      recipeId: _requiredString(json, 'recipeId'),
      recipeTitle: _requiredString(json, 'recipeTitle'),
      cookedAt: _requiredDateTime(json, 'cookedAt'),
      rating: _requiredInt(json, 'rating'),
    );
  }

  final String reviewId;
  final String recipeId;
  final String recipeTitle;
  final DateTime cookedAt;
  final int rating;
}

class NextCookRecommendation {
  const NextCookRecommendation({
    required this.recommendationId,
    required this.type,
    required this.originalIngredientId,
    required this.ingredientName,
    required this.originalAmount,
    required this.suggestedAmount,
    required this.unit,
    required this.changePercent,
    required this.confidence,
    required this.reason,
    required this.explanationSource,
    required this.model,
    required this.promptVersion,
    required this.evidence,
  });

  factory NextCookRecommendation.fromJson(Map<String, dynamic> json) {
    final evidenceJson = json['evidence'];
    if (evidenceJson is! List ||
        evidenceJson.any((item) => item is! Map<String, dynamic>)) {
      throw const RecommendationApiException('추천 근거 형식이 올바르지 않습니다.');
    }
    return NextCookRecommendation(
      recommendationId: _requiredString(json, 'recommendationId'),
      type: _requiredString(json, 'type'),
      originalIngredientId: _requiredString(json, 'originalIngredientId'),
      ingredientName: _requiredString(json, 'ingredientName'),
      originalAmount: _requiredDouble(json, 'originalAmount'),
      suggestedAmount: _requiredDouble(json, 'suggestedAmount'),
      unit: json['unit'] as String? ?? '',
      changePercent: _requiredInt(json, 'changePercent'),
      confidence: _requiredDouble(json, 'confidence'),
      reason: _requiredString(json, 'reason'),
      explanationSource: _requiredString(json, 'explanationSource'),
      model: json['model'] as String?,
      promptVersion: _requiredString(json, 'promptVersion'),
      evidence: evidenceJson
          .map(
            (item) =>
                RecommendationEvidence.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final String recommendationId;
  final String type;
  final String originalIngredientId;
  final String ingredientName;
  final double originalAmount;
  final double suggestedAmount;
  final String unit;
  final int changePercent;
  final double confidence;
  final String reason;
  final String explanationSource;
  final String? model;
  final String promptVersion;
  final List<RecommendationEvidence> evidence;
}

class NextCookRecommendationResponse {
  const NextCookRecommendationResponse({
    required this.recipeId,
    required this.generatedAt,
    required this.recommendations,
  });

  factory NextCookRecommendationResponse.fromJson(Map<String, dynamic> json) {
    final recommendationsJson = json['recommendations'];
    if (recommendationsJson is! List ||
        recommendationsJson.any((item) => item is! Map<String, dynamic>)) {
      throw const RecommendationApiException('추천 목록 형식이 올바르지 않습니다.');
    }
    return NextCookRecommendationResponse(
      recipeId: _requiredString(json, 'recipeId'),
      generatedAt: _requiredDateTime(json, 'generatedAt'),
      recommendations: recommendationsJson
          .map(
            (item) =>
                NextCookRecommendation.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final String recipeId;
  final DateTime generatedAt;
  final List<NextCookRecommendation> recommendations;
}

class RecommendationApiException implements Exception {
  const RecommendationApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract interface class RecommendationDataSource {
  Future<NextCookRecommendationResponse> findForRecipe(String recipeId);

  Future<void> recordFeedback({
    required String recipeId,
    required NextCookRecommendation recommendation,
    required RecommendationDecision decision,
    double? appliedAmount,
  });
}

class RecommendationRepository implements RecommendationDataSource {
  RecommendationRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? cookPilotApiBaseUrl();

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<NextCookRecommendationResponse> findForRecipe(String recipeId) async {
    final response = await _request(
      'GET',
      '/api/v1/recipes/$recipeId/next-cook-recommendations',
      const {200},
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const RecommendationApiException('추천 응답 형식이 올바르지 않습니다.');
    }
    final result = NextCookRecommendationResponse.fromJson(decoded);
    if (result.recipeId != recipeId) {
      throw const RecommendationApiException('요청한 레시피와 다른 추천을 받았습니다.');
    }
    return result;
  }

  @override
  Future<void> recordFeedback({
    required String recipeId,
    required NextCookRecommendation recommendation,
    required RecommendationDecision decision,
    double? appliedAmount,
  }) async {
    await _request(
      'PUT',
      '/api/v1/recipes/$recipeId/recommendation-feedback/'
          '${recommendation.recommendationId}',
      const {200},
      body: {
        'originalIngredientId': recommendation.originalIngredientId,
        'decision': decision.apiValue,
        'originalAmount': recommendation.originalAmount,
        'suggestedAmount': recommendation.suggestedAmount,
        'appliedAmount': appliedAmount,
        'unit': recommendation.unit,
        'reason': recommendation.reason,
        'explanationSource': recommendation.explanationSource,
        'model': recommendation.model,
        'promptVersion': recommendation.promptVersion,
        'evidenceReviewIds': recommendation.evidence
            .map((item) => item.reviewId)
            .toList(growable: false),
      },
    );
  }

  Future<http.Response> _request(
    String method,
    String path,
    Set<int> successCodes, {
    Map<String, Object?>? body,
  }) async {
    try {
      final request = http.Request(method, Uri.parse('$_baseUrl$path'));
      request.headers.addAll(AuthSession.requestHeaders);
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 8));
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(const Duration(seconds: 8));
      if (!successCodes.contains(response.statusCode)) {
        throw RecommendationApiException(
          '추천 서버 요청에 실패했습니다. (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
      return response;
    } on TimeoutException {
      throw const RecommendationApiException('추천 서버 응답 시간이 초과되었습니다.');
    } on http.ClientException {
      throw const RecommendationApiException('추천 서버에 연결하지 못했습니다.');
    }
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw RecommendationApiException('$key 값이 없습니다.');
  }
  return value;
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw RecommendationApiException('$key 값이 없습니다.');
  }
  return value.toDouble();
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw RecommendationApiException('$key 값이 없습니다.');
  }
  return value.toInt();
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw RecommendationApiException('$key 값이 없습니다.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw RecommendationApiException('$key 형식이 올바르지 않습니다.');
  }
  return parsed;
}
