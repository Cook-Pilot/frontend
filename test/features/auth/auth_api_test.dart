import 'dart:convert';

import 'package:cookpilot/features/auth/data/auth_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseUrl = 'http://test.local';

  AuthApi apiReturning(http.Response Function(http.Request) handler) {
    return AuthApi(
      client: MockClient((request) async => handler(request)),
      baseUrl: baseUrl,
    );
  }

  test('개발자 로그인은 토큰을 파싱한다', () async {
    final api = apiReturning(
      (request) => http.Response(
        jsonEncode({
          'token': 'jwt-token',
          'expiresAt': '2099-01-01T00:00:00Z',
          'userId': 'user-1',
          'displayName': '개발자',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    final session = await api.loginAsDeveloper('secret');

    expect(session.token, 'jwt-token');
    expect(session.displayName, '개발자');
    expect(session.isExpired, isFalse);
  });

  test('제공자 로그인은 경로에 provider 를 넣는다', () async {
    late Uri requested;
    final api = apiReturning((request) {
      requested = request.url;
      return http.Response(
        jsonEncode({
          'token': 't',
          'expiresAt': '2099-01-01T00:00:00Z',
          'userId': 'u',
          'displayName': 'n',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await api.loginWithProvider('kakao', 'provider-token');

    expect(requested.path, '/api/v1/auth/kakao');
  });

  test('표시 이름은 있을 때만 본문에 실린다', () async {
    final bodies = <Map<String, dynamic>>[];
    final api = apiReturning((request) {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode({
          'token': 't',
          'expiresAt': '2099-01-01T00:00:00Z',
          'userId': 'u',
          'displayName': 'n',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await api.loginWithProvider('apple', 'id-token', displayName: '홍길동');
    await api.loginWithProvider('apple', 'id-token');

    expect(bodies[0], {'token': 'id-token', 'displayName': '홍길동'});
    expect(bodies[1], {'token': 'id-token'});
  });

  test('401 은 안내 문구로 바뀐다', () async {
    final api = apiReturning((_) => http.Response('{}', 401));

    await expectLater(
      api.loginAsDeveloper('wrong'),
      throwsA(
        isA<AuthException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', contains('올바르지 않습니다')),
      ),
    );
  });

  test('429 는 재시도 안내로 바뀐다', () async {
    final api = apiReturning((_) => http.Response('{}', 429));

    await expectLater(
      api.loginAsDeveloper('secret'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('너무 많'),
        ),
      ),
    );
  });

  test('만료 시각이 지났으면 isExpired 가 참이다', () {
    final expired = AuthSessionToken(
      token: 't',
      expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      userId: 'u',
      displayName: 'n',
    );

    expect(expired.isExpired, isTrue);
  });
}
