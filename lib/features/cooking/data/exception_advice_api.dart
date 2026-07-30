import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import '../../user/data/beta_user_repository.dart';
import '../application/cooking_ports.dart';

const _maxRemainingSeconds = 86_400;

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
/// 헤더와 현재 조리 문맥만 CookPilot 백엔드에 전송한다.
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
              ...BetaUserSession.requestHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'recipeId': context.recipeId,
              'stepIndex': context.stepIndex,
              'userSpeech': context.utterance,
              'instruction': context.instruction,
              'remainingSeconds': context.remaining.inSeconds.clamp(
                0,
                _maxRemainingSeconds,
              ),
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
  final screenText = _nonBlankString(decoded['screenText']);
  if (speechText == null && screenText == null) {
    throw const ExceptionAdviceApiException('도움 답변 형식이 올바르지 않습니다.');
  }
  final isMock = decoded['mock'] == true;

  return ExceptionAdvice(
    speechText: speechText ?? screenText,
    screenText: screenText ?? speechText,
    // 프론트가 백엔드보다 먼저 배포되어 기존 고정 mock 응답을 받더라도
    // 데모 행동을 실제 사용자 타이머에 적용하지 않는다.
    suggestedAction: isMock
        ? null
        : _decodeSuggestedAction(decoded['suggestedAction']),
    isMock: isMock,
    eventPayload: _decodeEventPayload(decoded['eventPayload']),
  );
}

ExceptionAdviceSuggestedAction? _decodeSuggestedAction(Object? value) {
  if (value is! Map<String, dynamic> ||
      value['type'] != 'EXTEND_TIMER' ||
      value['seconds'] is! int) {
    return null;
  }
  final seconds = value['seconds'] as int;
  if (seconds != 30 && seconds != 60) {
    return null;
  }
  return ExceptionAdviceSuggestedAction(
    type: ExceptionAdviceActionType.extendTimer,
    seconds: seconds,
  );
}

Map<String, Object?> _decodeEventPayload(Object? value) {
  if (value is! Map<String, dynamic>) {
    return const <String, Object?>{};
  }
  return Map<String, Object?>.unmodifiable(value);
}

String? _nonBlankString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
