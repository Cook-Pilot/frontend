import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_session.dart';
import '../application/cooking_ports.dart';

final class ExceptionAdviceApiException implements Exception {
  const ExceptionAdviceApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// F-08 조리 예외 질문을 백엔드 Gemini 프록시에 전달한다.
///
/// Gemini API 키는 앱에 포함하지 않는다. 이 어댑터는 베타 사용자 식별
/// 헤더와 질문·현재 단계 번호만 CookPilot 백엔드에 전송한다.
final class HttpExceptionAdvicePort implements ExceptionAdvicePort {
  HttpExceptionAdvicePort({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? cookPilotApiBaseUrl();

  final http.Client _client;
  final String _baseUrl;
  final Duration timeout;

  @override
  Future<ExceptionAdvice> requestAdvice(ExceptionAdviceContext context) async {
    final response = await _translateTransportErrors(
      () => _client
          .post(
            Uri.parse('$_baseUrl/api/v1/ai-feedback'),
            headers: <String, String>{
              ...AuthSession.requestHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'recipeId': context.recipeId,
              'stepIndex': context.stepIndex,
              'userSpeech': context.utterance,
            }),
          )
          .timeout(timeout),
    );

    if (response.statusCode != 200) {
      throw ExceptionAdviceApiException(
        '도움 답변을 불러오지 못했습니다. (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    return _decodeAdvice(response.bodyBytes);
  }

  Future<T> _translateTransportErrors<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on TimeoutException {
      throw const ExceptionAdviceApiException('서버 응답 시간이 초과되었습니다.');
    } on http.ClientException {
      throw const ExceptionAdviceApiException('서버에 연결하지 못했습니다.');
    }
  }
}

ExceptionAdvice _decodeAdvice(List<int> bodyBytes) {
  Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bodyBytes));
  } on FormatException {
    throw const ExceptionAdviceApiException('도움 답변 형식이 올바르지 않습니다.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const ExceptionAdviceApiException('도움 답변 형식이 올바르지 않습니다.');
  }

  final speechText = _nonBlankString(decoded['speechText']);
  if (speechText == null) {
    throw const ExceptionAdviceApiException('도움 답변 형식이 올바르지 않습니다.');
  }

  return ExceptionAdvice(
    speechText: speechText,
    isMock: decoded['mock'] == true,
  );
}

String? _nonBlankString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
