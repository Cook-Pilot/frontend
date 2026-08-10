import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import '../../cooking/domain/cooking_setup_snapshot.dart';
import '../../user/data/beta_user_repository.dart';

class ReviewApiException implements Exception {
  const ReviewApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ReviewSaveResult {
  const ReviewSaveResult({
    required this.id,
    required this.createdPersonalVersionId,
  });

  factory ReviewSaveResult.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final createdVersionId = json['createdPersonalVersionId'];
    if (id is! String ||
        (createdVersionId != null && createdVersionId is! String)) {
      throw const ReviewApiException('후기 저장 응답 형식이 올바르지 않습니다.');
    }
    return ReviewSaveResult(
      id: id,
      createdPersonalVersionId: createdVersionId as String?,
    );
  }

  final String id;
  final String? createdPersonalVersionId;
}

class CookingHistoryEntry {
  const CookingHistoryEntry({
    required this.reviewId,
    required this.recipeId,
    required this.recipeTitle,
    required this.recipeImageUrl,
    required this.cookedAt,
    required this.rating,
    required this.comment,
    required this.nextTimeNote,
    required this.sourcePersonalVersionId,
    required this.createdPersonalVersionId,
    required this.createdPersonalVersionNumber,
    required this.createdPersonalVersionSummary,
  });

  factory CookingHistoryEntry.fromJson(Map<String, dynamic> json) {
    final reviewId = json['reviewId'];
    final recipeId = json['recipeId'];
    final recipeTitle = json['recipeTitle'];
    final recipeImageUrl = json['recipeImageUrl'];
    final cookedAtValue = json['cookedAt'];
    final rating = json['rating'];
    final comment = json['comment'];
    final nextTimeNote = json['nextTimeNote'];
    final sourcePersonalVersionId = json['sourcePersonalVersionId'];
    final createdPersonalVersionId = json['createdPersonalVersionId'];
    final createdPersonalVersionNumber = json['createdPersonalVersionNumber'];
    final createdPersonalVersionSummary = json['createdPersonalVersionSummary'];
    final cookedAt = cookedAtValue is String
        ? DateTime.tryParse(cookedAtValue)
        : null;
    if (reviewId is! String ||
        recipeId is! String ||
        recipeTitle is! String ||
        (recipeImageUrl != null && recipeImageUrl is! String) ||
        (rating != null && rating is! num) ||
        (comment != null && comment is! String) ||
        (nextTimeNote != null && nextTimeNote is! String) ||
        (sourcePersonalVersionId != null &&
            sourcePersonalVersionId is! String) ||
        (createdPersonalVersionId != null &&
            createdPersonalVersionId is! String) ||
        (createdPersonalVersionNumber != null &&
            createdPersonalVersionNumber is! num) ||
        (createdPersonalVersionSummary != null &&
            createdPersonalVersionSummary is! String) ||
        cookedAt == null) {
      throw const ReviewApiException('조리 이력 응답 형식이 올바르지 않습니다.');
    }
    return CookingHistoryEntry(
      reviewId: reviewId,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      recipeImageUrl: recipeImageUrl as String? ?? '',
      cookedAt: cookedAt.toLocal(),
      rating: (rating as num?)?.toInt(),
      comment: comment as String?,
      nextTimeNote: nextTimeNote as String?,
      sourcePersonalVersionId: sourcePersonalVersionId as String?,
      createdPersonalVersionId: createdPersonalVersionId as String?,
      createdPersonalVersionNumber: (createdPersonalVersionNumber as num?)
          ?.toInt(),
      createdPersonalVersionSummary: createdPersonalVersionSummary as String?,
    );
  }

  final String reviewId;
  final String recipeId;
  final String recipeTitle;
  final String recipeImageUrl;
  final DateTime cookedAt;
  final int? rating;
  final String? comment;
  final String? nextTimeNote;
  final String? sourcePersonalVersionId;
  final String? createdPersonalVersionId;
  final int? createdPersonalVersionNumber;
  final String? createdPersonalVersionSummary;
}

class ReviewRepository {
  ReviewRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? cookPilotApiBaseUrl();

  final http.Client _client;
  final String _baseUrl;

  Future<ReviewSaveResult> submit({
    required String clientSessionId,
    required DateTime cookedAt,
    required CookingSetupSnapshot snapshot,
    required int rating,
    required String comment,
    required String nextTimeNote,
    List<String> photoUrls = const [],
  }) async {
    final body = <String, Object?>{
      'clientSessionId': clientSessionId,
      'recipeId': snapshot.recipeId,
      'cookedAt': cookedAt.toUtc().toIso8601String(),
      'targetServings': snapshot.targetServings,
      'sourcePersonalVersionId': snapshot.personalVersionId,
      'rating': rating,
      'comment': _nullIfBlank(comment),
      'nextTimeNote': _nullIfBlank(nextTimeNote),
      // photoUrls는 서버 선택 필드다(openapi SubmitReviewRequest, 최대 10장,
      // 순서 보존). 사진이 없으면 기존 8필드 요청 그대로 보낸다.
      if (photoUrls.isNotEmpty) 'photoUrls': photoUrls,
    };

    final response = await _translateTransportErrors(
      () => _client
          .post(
            Uri.parse('$_baseUrl/api/v1/reviews'),
            headers: {
              ...BetaUserSession.requestHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8)),
    );
    if (response.statusCode != 201) {
      throw ReviewApiException(
        '후기를 저장하지 못했습니다. (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    final decoded = _decodeJson(response.body, '후기 저장 응답 형식이 올바르지 않습니다.');
    if (decoded is! Map<String, dynamic>) {
      throw const ReviewApiException('후기 저장 응답 형식이 올바르지 않습니다.');
    }
    return ReviewSaveResult.fromJson(decoded);
  }

  Future<List<CookingHistoryEntry>> findHistory({
    required DateTime from,
    required DateTime to,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/cooking-history').replace(
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    final response = await _translateTransportErrors(
      () => _client
          .get(uri, headers: BetaUserSession.requestHeaders)
          .timeout(const Duration(seconds: 8)),
    );
    if (response.statusCode != 200) {
      throw ReviewApiException(
        '조리 이력을 불러오지 못했습니다. (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    final decoded = _decodeJson(response.body, '조리 이력 응답 형식이 올바르지 않습니다.');
    if (decoded is! List ||
        decoded.any((item) => item is! Map<String, dynamic>)) {
      throw const ReviewApiException('조리 이력 응답 형식이 올바르지 않습니다.');
    }
    return decoded
        .map(
          (item) => CookingHistoryEntry.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<T> _translateTransportErrors<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on TimeoutException {
      throw const ReviewApiException('서버 응답 시간이 초과되었습니다.');
    } on http.ClientException {
      throw const ReviewApiException('서버에 연결하지 못했습니다.');
    }
  }
}

String? _nullIfBlank(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Object? _decodeJson(String body, String errorMessage) {
  try {
    return jsonDecode(body);
  } on FormatException {
    throw ReviewApiException(errorMessage);
  }
}
