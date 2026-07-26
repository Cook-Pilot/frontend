import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import '../../user/data/beta_user_repository.dart';

class PantryIngredientCatalogItem {
  const PantryIngredientCatalogItem({
    required this.name,
    required this.emoji,
    required this.defaultShelfLifeDays,
  });

  factory PantryIngredientCatalogItem.fromJson(Map<String, dynamic> json) {
    return PantryIngredientCatalogItem(
      name: _requiredString(json, 'name'),
      emoji: json['emoji'] as String? ?? '',
      defaultShelfLifeDays: _requiredInt(json, 'defaultShelfLifeDays'),
    );
  }

  final String name;
  final String emoji;
  final int defaultShelfLifeDays;
}

class PantryItem {
  const PantryItem({
    required this.id,
    required this.ingredientName,
    required this.emoji,
    required this.daysUntilExpiry,
  });

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      id: _requiredString(json, 'id'),
      ingredientName: _requiredString(json, 'ingredientName'),
      emoji: json['emoji'] as String? ?? '',
      daysUntilExpiry: _requiredInt(json, 'daysUntilExpiry'),
    );
  }

  final String id;
  final String ingredientName;
  final String emoji;
  final int daysUntilExpiry;
}

class PantryMatchedIngredient {
  const PantryMatchedIngredient({
    required this.ingredientName,
    required this.emoji,
    required this.daysUntilExpiry,
  });

  factory PantryMatchedIngredient.fromJson(Map<String, dynamic> json) {
    return PantryMatchedIngredient(
      ingredientName: _requiredString(json, 'ingredientName'),
      emoji: json['emoji'] as String? ?? '',
      daysUntilExpiry: _requiredInt(json, 'daysUntilExpiry'),
    );
  }

  final String ingredientName;
  final String emoji;
  final int daysUntilExpiry;
}

class PantryRecipeSuggestion {
  const PantryRecipeSuggestion({
    required this.recipeId,
    required this.recipeTitle,
    required this.recipeImageUrl,
    required this.matchedIngredients,
    required this.mostUrgentDaysUntilExpiry,
  });

  factory PantryRecipeSuggestion.fromJson(Map<String, dynamic> json) {
    final matchedJson = json['matchedIngredients'];
    if (matchedJson is! List ||
        matchedJson.any((item) => item is! Map<String, dynamic>)) {
      throw const PantryApiException('추천 근거 재료 형식이 올바르지 않습니다.');
    }
    return PantryRecipeSuggestion(
      recipeId: _requiredString(json, 'recipeId'),
      recipeTitle: _requiredString(json, 'recipeTitle'),
      recipeImageUrl: json['recipeImageUrl'] as String? ?? '',
      matchedIngredients: matchedJson
          .map(
            (item) => PantryMatchedIngredient.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      mostUrgentDaysUntilExpiry: _requiredInt(
        json,
        'mostUrgentDaysUntilExpiry',
      ),
    );
  }

  final String recipeId;
  final String recipeTitle;
  final String recipeImageUrl;
  final List<PantryMatchedIngredient> matchedIngredients;
  final int mostUrgentDaysUntilExpiry;
}

class PantryApiException implements Exception {
  const PantryApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract interface class PantryDataSource {
  Future<List<PantryIngredientCatalogItem>> findCatalog();

  Future<List<PantryItem>> findItems();

  Future<PantryItem> addItem(String ingredientName);

  Future<void> removeItem(String itemId);

  Future<List<PantryRecipeSuggestion>> findRecipeSuggestions();
}

class PantryRepository implements PantryDataSource {
  PantryRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? cookPilotApiBaseUrl();

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<List<PantryIngredientCatalogItem>> findCatalog() async {
    final response = await _request(
      'GET',
      '/api/v1/pantry/ingredient-catalog',
      const {200},
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const PantryApiException('재료 카탈로그 형식이 올바르지 않습니다.');
    }
    return decoded
        .map(
          (item) => PantryIngredientCatalogItem.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<PantryItem>> findItems() async {
    final response = await _request('GET', '/api/v1/pantry/items', const {
      200,
    });
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const PantryApiException('보유 재료 형식이 올바르지 않습니다.');
    }
    return decoded
        .map((item) => PantryItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<PantryItem> addItem(String ingredientName) async {
    final response = await _request(
      'POST',
      '/api/v1/pantry/items',
      const {201},
      body: {'ingredientName': ingredientName, 'useByDate': null},
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const PantryApiException('재료 담기 응답 형식이 올바르지 않습니다.');
    }
    return PantryItem.fromJson(decoded);
  }

  @override
  Future<void> removeItem(String itemId) async {
    await _request('DELETE', '/api/v1/pantry/items/$itemId', const {204});
  }

  @override
  Future<List<PantryRecipeSuggestion>> findRecipeSuggestions() async {
    final response = await _request(
      'GET',
      '/api/v1/pantry/recipe-suggestions',
      const {200},
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const PantryApiException('추천 응답 형식이 올바르지 않습니다.');
    }
    final suggestionsJson = decoded['suggestions'];
    if (suggestionsJson is! List ||
        suggestionsJson.any((item) => item is! Map<String, dynamic>)) {
      throw const PantryApiException('추천 목록 형식이 올바르지 않습니다.');
    }
    return suggestionsJson
        .map(
          (item) =>
              PantryRecipeSuggestion.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<http.Response> _request(
    String method,
    String path,
    Set<int> successCodes, {
    Map<String, Object?>? body,
  }) async {
    try {
      final request = http.Request(method, Uri.parse('$_baseUrl$path'));
      request.headers.addAll(BetaUserSession.requestHeaders);
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
        throw PantryApiException(
          '냉장고 서버 요청에 실패했습니다. (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
      return response;
    } on TimeoutException {
      throw const PantryApiException('냉장고 서버 응답 시간이 초과되었습니다.');
    } on http.ClientException {
      throw const PantryApiException('냉장고 서버에 연결하지 못했습니다.');
    }
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw PantryApiException('$key 값이 없습니다.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw PantryApiException('$key 값이 없습니다.');
  }
  return value.toInt();
}
