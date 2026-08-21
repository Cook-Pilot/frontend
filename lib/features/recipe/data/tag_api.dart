import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import '../domain/recipe_tag.dart';

/// 태그 사전을 읽는다. 로그인이 필요 없다 — 사전은 개인 데이터가 아니다.
class TagRepository {
  TagRepository({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? cookPilotApiBaseUrl();

  static const _timeout = Duration(seconds: 8);

  final http.Client _client;
  final String _baseUrl;

  Future<List<RecipeTag>> findAll() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/api/v1/tags'))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw TagApiException('태그를 불러오지 못했습니다. (${response.statusCode})');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const TagApiException('태그 응답 형식이 올바르지 않습니다.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(RecipeTag.fromJson)
        .toList();
  }
}

class TagApiException implements Exception {
  const TagApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
