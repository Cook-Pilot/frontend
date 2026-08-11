import 'dart:convert';

import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/cooking/data/ai_live_session_api.dart';
import 'package:cookpilot/features/user/data/beta_user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseUrl = 'http://example.test';
  const userId = '90000000-0000-0000-0000-000000000001';
  const recipeId = '10000000-0000-0000-0000-000000000001';

  setUp(() {
    BetaUserSession.setCurrentUser(
      const BetaUser(id: userId, displayName: '베타 사용자', betaNumber: 1),
    );
  });

  tearDown(BetaUserSession.clear);

  HttpAiLiveSessionPort buildPort(MockClient client) =>
      HttpAiLiveSessionPort(baseUrl: baseUrl, client: client);

  test('recipeId만 보내고 토큰과 모델을 돌려받는다', () async {
    late Map<String, dynamic> requestBody;
    final port = buildPort(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), '$baseUrl/api/v1/ai-sessions');
        expect(request.headers[cookPilotUserIdHeader], userId);
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, Object?>{
            'token': 'auth_tokens/abc',
            'model': 'gemini-live-test',
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final grant = await port.openSession(recipeId);

    expect(requestBody, <String, Object?>{'recipeId': recipeId});
    expect(grant.token, 'auth_tokens/abc');
    expect(grant.model, 'gemini-live-test');
  });

  test('409는 서버 키 미설정 안내로 번역한다', () async {
    final port = buildPort(MockClient((_) async => http.Response('', 409)));

    await expectLater(
      port.openSession(recipeId),
      throwsA(
        isA<CoachSessionException>().having(
          (e) => e.message,
          'message',
          'AI 코치가 서버에 준비되지 않았어요.',
        ),
      ),
    );
  });

  test('404는 레시피 없음 안내로 번역한다', () async {
    final port = buildPort(MockClient((_) async => http.Response('', 404)));

    await expectLater(
      port.openSession(recipeId),
      throwsA(
        isA<CoachSessionException>().having(
          (e) => e.message,
          'message',
          '레시피를 찾을 수 없어 코치를 시작하지 못했어요.',
        ),
      ),
    );
  });

  test('토큰이나 모델이 빠진 응답은 형식 오류로 던진다', () async {
    final port = buildPort(
      MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object?>{'token': 'auth_tokens/abc'}),
          200,
        ),
      ),
    );

    await expectLater(
      port.openSession(recipeId),
      throwsA(
        isA<CoachSessionException>().having(
          (e) => e.message,
          'message',
          '세션 토큰 형식이 올바르지 않습니다.',
        ),
      ),
    );
  });

  test('전송 오류는 사용자 문구로 번역한다', () async {
    final port = buildPort(
      MockClient((_) async => throw http.ClientException('boom')),
    );

    await expectLater(
      port.openSession(recipeId),
      throwsA(
        isA<CoachSessionException>().having(
          (e) => e.message,
          'message',
          '서버에 연결하지 못했습니다.',
        ),
      ),
    );
  });
}
