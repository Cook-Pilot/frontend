import 'dart:async';
import 'dart:convert';

import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/cooking/data/exception_advice_api.dart';
import 'package:cookpilot/features/user/data/beta_user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseUrl = 'http://example.test';
  const userId = '90000000-0000-0000-0000-000000000001';
  const recipeId = '10000000-0000-0000-0000-000000000001';

  const context = ExceptionAdviceContext(
    sessionId: '40000000-0000-0000-0000-000000000001',
    recipeId: recipeId,
    recipeVersionId: 'mvp',
    stepIndex: 1,
    requestContextVersion: 3,
    utterance: '물이 안 끓어요',
    recentEvents: <ExceptionAdviceEvent>[],
  );

  setUp(() {
    BetaUserSession.setCurrentUser(
      const BetaUser(id: userId, displayName: '베타 사용자', betaNumber: 1),
    );
  });

  tearDown(BetaUserSession.clear);

  test('베타 사용자 헤더와 질문·단계 번호만 F8 엔드포인트에 보낸다', () async {
    late Map<String, dynamic> requestBody;
    final port = HttpExceptionAdvicePort(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), '$baseUrl/api/v1/ai-feedback');
        expect(request.headers[cookPilotUserIdHeader], userId);
        expect(request.headers['content-type'], 'application/json');
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse('''
          {
            "mock": false,
            "speechText": "불을 한 단계 높여보세요."
          }
        ''');
      }),
    );

    final advice = await port.requestAdvice(context);

    expect(requestBody, <String, Object?>{
      'recipeId': recipeId,
      'stepIndex': 1,
      'userSpeech': '물이 안 끓어요',
    });
    expect(advice.speechText, '불을 한 단계 높여보세요.');
    expect(advice.isMock, isFalse);
  });

  test('화면 표시 텍스트는 speechText로 채운다', () async {
    final port = HttpExceptionAdvicePort(
      baseUrl: baseUrl,
      client: MockClient(
        (_) async => _jsonResponse('{"speechText":"불을 낮추세요."}'),
      ),
    );

    final advice = await port.requestAdvice(context);

    expect(advice.speechText, '불을 낮추세요.');
    expect(advice.screenText, '불을 낮추세요.');
  });

  test('백엔드가 아직 고정 mock 답변을 주면 mock으로 표시한다', () async {
    final port = HttpExceptionAdvicePort(
      baseUrl: baseUrl,
      client: MockClient(
        (_) async => _jsonResponse('{"mock": true, "speechText": "고정 데모 답변"}'),
      ),
    );

    final advice = await port.requestAdvice(context);

    expect(advice.isMock, isTrue);
    expect(advice.screenText, '고정 데모 답변');
  });

  test('JSON이 아니거나 답변 텍스트가 없으면 형식 오류로 처리한다', () async {
    final responses = <String>['not-json', '{"speechText":"  "}'];
    var requestIndex = 0;
    final port = HttpExceptionAdvicePort(
      baseUrl: baseUrl,
      client: MockClient((_) async => _jsonResponse(responses[requestIndex++])),
    );

    await expectLater(
      port.requestAdvice(context),
      throwsA(isA<ExceptionAdviceApiException>()),
    );
    await expectLater(
      port.requestAdvice(context),
      throwsA(isA<ExceptionAdviceApiException>()),
    );
  });

  test('200이 아닌 응답은 상태 코드를 보존한다', () async {
    final port = HttpExceptionAdvicePort(
      baseUrl: baseUrl,
      client: MockClient((_) async => http.Response('rate limited', 429)),
    );

    await expectLater(
      port.requestAdvice(context),
      throwsA(
        isA<ExceptionAdviceApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          429,
        ),
      ),
    );
  });

  test('응답 시간 초과는 API 예외로 변환한다', () async {
    final pending = Completer<http.Response>();
    final port = HttpExceptionAdvicePort(
      baseUrl: baseUrl,
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => pending.future),
    );

    await expectLater(
      port.requestAdvice(context),
      throwsA(
        isA<ExceptionAdviceApiException>().having(
          (error) => error.message,
          'message',
          contains('초과'),
        ),
      ),
    );
  });
}

http.Response _jsonResponse(String body) {
  return http.Response.bytes(
    utf8.encode(body),
    200,
    headers: const <String, String>{'Content-Type': 'application/json'},
  );
}
