import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import '../../user/data/beta_user_repository.dart';
import '../domain/recipe.dart';

class RecipeSummary {
  const RecipeSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.hasPersonalVersion,
    required this.latestPersonalVersionId,
  });

  factory RecipeSummary.fromJson(Map<String, dynamic> json) {
    return RecipeSummary(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      hasPersonalVersion: json['hasPersonalVersion'] as bool? ?? false,
      latestPersonalVersionId: json['latestPersonalVersionId'] as String?,
    );
  }

  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final bool hasPersonalVersion;
  final String? latestPersonalVersionId;
}

class RecipeApiException implements Exception {
  const RecipeApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RecipeRepository {
  RecipeRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? cookPilotApiBaseUrl();

  final http.Client _client;
  final String _baseUrl;

  Future<List<RecipeSummary>> findAll() async {
    return _findSummaries('/api/v1/recipes');
  }

  Future<List<RecipeSummary>> _findSummaries(String path) async {
    final response = await _get(path);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const RecipeApiException('레시피 목록 응답 형식이 올바르지 않습니다.');
    }

    return decoded
        .map((item) => RecipeSummary.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Recipe> findById(RecipeSummary summary) async {
    final response = await _get('/api/v1/recipes/${summary.id}');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const RecipeApiException('레시피 상세 응답 형식이 올바르지 않습니다.');
    }

    final ingredientsJson = decoded['ingredients'];
    final stepsJson = decoded['steps'];
    if (ingredientsJson is! List || stepsJson is! List) {
      throw const RecipeApiException('레시피 재료 또는 조리 단계가 없습니다.');
    }

    final responseId = _requiredString(decoded, 'id');
    if (responseId != summary.id) {
      throw const RecipeApiException('요청한 레시피와 다른 상세 응답을 받았습니다.');
    }

    final ingredients = ingredientsJson
        .map((item) => _ingredientFromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final steps = stepsJson
        .map((item) => _stepFromJson(item as Map<String, dynamic>))
        .toList(growable: false);

    return Recipe(
      id: responseId,
      title: _requiredString(decoded, 'title'),
      description: decoded['description'] as String? ?? '',
      baseServings: (decoded['baseServings'] as num?)?.toDouble() ?? 1,
      imageUrl: decoded['imageUrl'] as String? ?? '',
      ingredients: ingredients,
      steps: steps,
      hasPersonalVersion: summary.hasPersonalVersion,
      latestPersonalVersionId: summary.latestPersonalVersionId,
    );
  }

  Future<http.Response> _get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _client
        .get(uri, headers: BetaUserSession.requestHeaders)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw RecipeApiException('서버 요청에 실패했습니다. (${response.statusCode})');
    }
    return response;
  }
}

Ingredient _ingredientFromJson(Map<String, dynamic> json) {
  final amount = json['amount'];
  final unit = json['unit'] as String? ?? '';
  return Ingredient(
    name: _requiredString(json, 'name'),
    amount: (amount as num?)?.toDouble(),
    unit: unit,
    isRequired: json['required'] as bool? ?? false,
  );
}

CookStep _stepFromJson(Map<String, dynamic> json) {
  final stepIndex = (json['stepIndex'] as num?)?.toInt() ?? 0;
  final seconds = (json['timerSeconds'] as num?)?.toInt() ?? 0;
  final caution = json['cautionNote'] as String?;
  final instruction = _requiredString(json, 'instruction');
  return CookStep(
    stepIndex: stepIndex,
    instruction: instruction,
    timerSeconds: json['timerSeconds'] == null ? null : seconds,
    cautionNote: caution,
    imageUrl: json['imageUrl'] as String? ?? '',
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw RecipeApiException('$key 값이 없습니다.');
  }
  return value;
}
