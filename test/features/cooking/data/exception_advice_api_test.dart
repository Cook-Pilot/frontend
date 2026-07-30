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
    instruction: '물을 끓이고 면을 넣으세요.',
    remaining: Duration(seconds: 42),
    utterance: '물이 안 끓어요',
    recentEvents: <ExceptionAdviceEvent>[],
  );

  setUp(() {
    BetaUserSession.setCurrentUser(
      const BetaUser(id: userId, displayName: '베타 사용자', betaNumber: 1),
    );
  });

  tearDown(BetaUserSession.clear);

  test('베타 사용자 헤더와 현재 단계 문맥을 F8 엔드포인트에 보낸다', () async {
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
            "speechText": "불을 한 단계 높여보세요.",
            "screenText": "불을 높이고 30초 뒤 기포를 확인하세요.",
            "suggestedAction": {
              "type": "EXTEND_TIMER",
              "seconds": 30
            },
            "eventPayload": {
              "problem": "WATER_NOT_BOILING",
              "currentStepIndex": 1
            }
          }
        ''');
      }),
    );

    final advice = await port.requestAdvice(context);

    expect(requestBody, <String, Object?>{
      'recipeId': recipeId,
      'stepIndex': 1,
      'userSpeech': '물이 안 끓어요',
      'instruction': '물을 끓이고 면을 넣으세요.',
      'remainingSeconds': 42,
    });
    expect(advice.speechText, '불을 한 단계 높여보세요.');
    expect(advice.screenText, '불을 높이고 30초 뒤 기포를 확인하세요.');
    expect(advice.suggestedAction?.type, ExceptionAdviceActionType.extendTimer);
    expect(advice.suggestedAction?.seconds, 30);
    expect(advice.isMock, isFalse);
    expect(advice.eventPayload['problem'], 'WATER_NOT_BOILING');
  });

  test('한쪽 답변 텍스트만 있어도 다른 표시 용도로 안전하게 보완한다', () async {
    final port = HttpExceptionAdvicePort(
      baseUrl: baseUrl,
      client: MockClient(
        (_) async => _jsonResponse('{"screenText":"불을 낮추세요."}'),
      ),
    );

    final advice = await port.requestAdvice(context);

    expect(advice.screenText, '불을 낮추세요.');
    expect(advice.speechText, '불을 낮추세요.');
    expect(advice.eventPayload, isEmpty);
  });

  test('허용하지 않은 행동은 답변 전체를 버리지 않고 무시한다', () async {
    final responses = <String>[
      '''
        {
          "speechText": "확인하세요.",
          "screenText": "확인하세요.",
          "suggestedAction": {"type": "NEXT_STEP", "seconds": 30}
        }
      ''',
      '''
        {
          "speechText": "확인하세요.",
          "screenText": "확인하세요.",
          "suggestedAction": {"type": "EXTEND_TIMER", "seconds": 90}
        }
      ''',
    ];
    var requestIndex = 0;
    final port = HttpExceptionAdvicePort(
      baseUrl: baseUrl,
      client: MockClient((_) async => _jsonResponse(responses[requestIndex++])),
    );

    expect((await port.requestAdvice(context)).suggestedAction, isNull);
    expect((await port.requestAdvice(context)).suggestedAction, isNull);
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
