import 'dart:convert';

import 'package:cookpilot/features/user/data/user_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../helpers/auth_fakes.dart';

void main() {
  const userId = '90000000-0000-0000-0000-000000000001';

  setUp(signInForTest);

  tearDown(resetAuthForTest);

  UserProfileRepository repositoryReturning(
    Map<String, dynamic> body, {
    void Function(http.Request request)? onRequest,
  }) {
    return UserProfileRepository(
      baseUrl: 'http://example.test',
      client: MockClient((request) async {
        onRequest?.call(request);
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  test('profileAskedAt이 null일 때만 온보딩 대상이다', () async {
    final pending = repositoryReturning(
      {'id': userId, 'profileAskedAt': null},
      onRequest: (request) {
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], testAuthHeader);
      },
    );
    final asked = repositoryReturning({
      'id': userId,
      'profileAskedAt': '2026-08-18T00:00:00Z',
    });
    // 필드 자체가 없는 구버전 서버 응답에는 온보딩을 띄우지 않는다.
    final legacy = repositoryReturning({'id': userId});

    expect(await pending.needsOnboarding(), isTrue);
    expect(await asked.needsOnboarding(), isFalse);
    expect(await legacy.needsOnboarding(), isFalse);
  });

  test('updateProfile은 고른 값만, 건너뛰기는 빈 body를 보낸다', () async {
    final bodies = <Object?>[];
    final repository = repositoryReturning(
      {'id': userId, 'profileAskedAt': '2026-08-18T00:00:00Z'},
      onRequest: (request) {
        expect(request.method, 'PATCH');
        expect(request.headers['content-type'], startsWith('application/json'));
        bodies.add(jsonDecode(request.body));
      },
    );

    await repository.updateProfile(gender: 'F');
    await repository.updateProfile(gender: 'M', ageGroup: 30);
    await repository.updateProfile();

    expect(bodies, [
      {'gender': 'F'},
      {'gender': 'M', 'ageGroup': 30},
      <String, dynamic>{},
    ]);
  });
}
