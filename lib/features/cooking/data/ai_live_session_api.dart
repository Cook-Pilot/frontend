import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import '../../user/data/beta_user_repository.dart';
import '../application/cooking_ports.dart';

/// Gemini Live 세션 토큰을 백엔드에서 발급받는다.
///
/// 진짜 Gemini API 키는 서버에만 있다. 이 어댑터는 recipeId만 보내고
/// 1회용 ephemeral token과 토큰에 잠긴 모델 이름을 돌려받는다.
final class HttpAiLiveSessionPort implements AiLiveSessionPort {
  HttpAiLiveSessionPort({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? cookPilotApiBaseUrl();

  final http.Client _client;
  final String _baseUrl;
  final Duration timeout;

  @override
  Future<AiLiveSessionGrant> openSession(String recipeId) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/ai-sessions'),
            headers: <String, String>{
              ...BetaUserSession.requestHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object?>{'recipeId': recipeId}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const CoachSessionException('서버 응답 시간이 초과되었습니다.');
    } on http.ClientException {
      throw const CoachSessionException('서버에 연결하지 못했습니다.');
    }

    // 409는 서버에 키가 없다는 뜻 — 백엔드 설계상 조용한 fallback 없이
    // 실패를 그대로 보여준다.
    switch (response.statusCode) {
      case 200:
        return _decodeGrant(response.bodyBytes);
      case 404:
        throw const CoachSessionException('레시피를 찾을 수 없어 코치를 시작하지 못했어요.');
      case 409:
        throw const CoachSessionException('AI 코치가 서버에 준비되지 않았어요.');
      default:
        throw CoachSessionException(
          'AI 코치를 시작하지 못했어요. (${response.statusCode})',
        );
    }
  }
}

AiLiveSessionGrant _decodeGrant(List<int> bodyBytes) {
  Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bodyBytes));
  } on FormatException {
    throw const CoachSessionException('세션 토큰 형식이 올바르지 않습니다.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const CoachSessionException('세션 토큰 형식이 올바르지 않습니다.');
  }
  final token = decoded['token'];
  final model = decoded['model'];
  if (token is! String ||
      token.trim().isEmpty ||
      model is! String ||
      model.trim().isEmpty) {
    throw const CoachSessionException('세션 토큰 형식이 올바르지 않습니다.');
  }
  return AiLiveSessionGrant(token: token, model: model);
}
