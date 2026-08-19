import 'dart:async';

import 'package:cookpilot/features/user/data/beta_user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const baseUrl = 'http://example.test';
  const userId = '90000000-0000-0000-0000-000000000001';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BetaUserSession.clear();
  });

  test('사용자 세션이 없으면 개인화 요청 헤더 생성을 거부한다', () {
    expect(
      () => BetaUserSession.requestHeaders,
      throwsA(
        isA<BetaUserException>().having(
          (exception) => exception.message,
          'message',
          contains('세션이 준비되지 않았습니다'),
        ),
      ),
    );
  });

  test('처음 진입하면 익명 사용자를 발급하고 ID를 저장한다', () async {
    final repository = BetaUserRepository(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), '$baseUrl/api/v1/users/anonymous');
        expect(request.headers[anonymousUserIdempotencyHeader], isNotEmpty);
        return _userResponse(201);
      }),
    );

    final user = await repository.ensureUser();
    final preferences = await SharedPreferences.getInstance();

    expect(user.id, userId);
    expect(user.betaNumber, 1);
    expect(preferences.getString('cookpilot_beta_user_id'), userId);
    expect(BetaUserSession.requestHeaders[cookPilotUserIdHeader], userId);
  });

  test('저장된 ID가 있으면 서버에서 확인하고 같은 사용자를 유지한다', () async {
    SharedPreferences.setMockInitialValues({'cookpilot_beta_user_id': userId});
    final repository = BetaUserRepository(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers[cookPilotUserIdHeader], userId);
        return _userResponse(200);
      }),
    );

    final user = await repository.ensureUser();

    expect(user.id, userId);
    expect(BetaUserSession.userId, userId);
  });

  test('동시에 여러 번 진입해도 사용자는 한 번만 발급한다', () async {
    var postCount = 0;
    final repository = BetaUserRepository(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        postCount++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _userResponse(201);
      }),
    );

    final users = await Future.wait([
      repository.ensureUser(),
      repository.ensureUser(),
    ]);

    expect(postCount, 1);
    expect(users.first.id, users.last.id);
  });

  test('사용자 ID 저장에 실패하면 세션을 공개하지 않는다', () async {
    final storage = _MemoryBetaUserStorage(userIdWriteSucceeds: false);
    final repository = BetaUserRepository(
      baseUrl: baseUrl,
      storage: storage,
      client: MockClient((_) async => _userResponse(201)),
    );

    await expectLater(
      repository.ensureUser(),
      throwsA(
        isA<BetaUserException>().having(
          (exception) => exception.message,
          'message',
          contains('저장하지 못했습니다'),
        ),
      ),
    );

    expect(BetaUserSession.currentUser, isNull);
    expect(storage.userId, isNull);
  });

  test('정확한 USER_NOT_FOUND 응답일 때만 기존 사용자를 복구한다', () async {
    const installationId = '91000000-0000-4000-8000-000000000001';
    final storage = _MemoryBetaUserStorage(
      userId: '90000000-0000-0000-0000-000000000099',
      installationId: installationId,
    );
    var requestCount = 0;
    final repository = BetaUserRepository(
      baseUrl: baseUrl,
      storage: storage,
      client: MockClient((request) async {
        requestCount++;
        if (request.method == 'GET') {
          return _problemResponse(404, 'USER_NOT_FOUND');
        }
        expect(storage.userId, '90000000-0000-0000-0000-000000000099');
        expect(request.headers[anonymousUserIdempotencyHeader], installationId);
        return _userResponse(201);
      }),
    );

    final user = await repository.ensureUser();

    expect(requestCount, 2);
    expect(user.id, userId);
    expect(storage.userId, userId);
    expect(storage.installationId, installationId);
  });

  test('경로 오류 형태의 일반 404는 기존 사용자 ID를 유지한다', () async {
    const savedId = '90000000-0000-0000-0000-000000000099';
    final storage = _MemoryBetaUserStorage(userId: savedId);
    var requestCount = 0;
    final repository = BetaUserRepository(
      baseUrl: baseUrl,
      storage: storage,
      client: MockClient((_) async {
        requestCount++;
        return http.Response('route not found', 404);
      }),
    );

    await expectLater(
      repository.ensureUser(),
      throwsA(isA<BetaUserException>()),
    );

    expect(requestCount, 1);
    expect(storage.userId, savedId);
    expect(BetaUserSession.currentUser, isNull);
  });

  test('사용자 복구 POST가 실패해도 기존 사용자와 설치 ID를 유지한다', () async {
    const savedId = '90000000-0000-0000-0000-000000000099';
    const installationId = '91000000-0000-4000-8000-000000000001';
    final storage = _MemoryBetaUserStorage(
      userId: savedId,
      installationId: installationId,
    );
    final repository = BetaUserRepository(
      baseUrl: baseUrl,
      storage: storage,
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return _problemResponse(404, 'USER_NOT_FOUND');
        }
        return http.Response('temporary failure', 503);
      }),
    );

    await expectLater(
      repository.ensureUser(),
      throwsA(isA<BetaUserException>()),
    );

    expect(storage.userId, savedId);
    expect(storage.installationId, installationId);
    expect(BetaUserSession.currentUser, isNull);
  });

  for (final damagedId in ['', 'broken-id', '90000000-0000-0000']) {
    test('손상된 사용자 ID "$damagedId"는 GET 없이 복구한다', () async {
      const installationId = '91000000-0000-4000-8000-000000000001';
      final storage = _MemoryBetaUserStorage(
        userId: damagedId,
        installationId: installationId,
      );
      var getCount = 0;
      var postCount = 0;
      final repository = BetaUserRepository(
        baseUrl: baseUrl,
        storage: storage,
        client: MockClient((request) async {
          if (request.method == 'GET') {
            getCount++;
          } else {
            postCount++;
          }
          return _userResponse(201);
        }),
      );

      await repository.ensureUser();

      expect(getCount, 0);
      expect(postCount, 1);
      expect(storage.userId, userId);
      expect(storage.installationId, installationId);
    });
  }

  test('복구된 사용자 ID 저장 실패 시 기존 ID와 설치 ID를 유지한다', () async {
    const savedId = '90000000-0000-0000-0000-000000000099';
    const installationId = '91000000-0000-4000-8000-000000000001';
    final storage = _MemoryBetaUserStorage(
      userId: savedId,
      installationId: installationId,
      userIdWriteSucceeds: false,
    );
    final repository = BetaUserRepository(
      baseUrl: baseUrl,
      storage: storage,
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return _problemResponse(404, 'USER_NOT_FOUND');
        }
        return _userResponse(201);
      }),
    );

    await expectLater(
      repository.ensureUser(),
      throwsA(isA<BetaUserException>()),
    );

    expect(storage.userId, savedId);
    expect(storage.installationId, installationId);
    expect(BetaUserSession.currentUser, isNull);
  });

  test('응답 시간 초과 후 재시도해도 같은 멱등성 키를 전송한다', () async {
    var postCount = 0;
    final idempotencyKeys = <String>[];
    final repository = BetaUserRepository(
      baseUrl: baseUrl,
      requestTimeout: const Duration(milliseconds: 5),
      client: MockClient((request) async {
        postCount++;
        idempotencyKeys.add(
          request.headers[anonymousUserIdempotencyHeader] ?? '',
        );
        if (postCount == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
        return _userResponse(201);
      }),
    );

    await expectLater(
      repository.ensureUser(),
      throwsA(isA<TimeoutException>()),
    );
    final user = await repository.ensureUser();

    expect(user.id, userId);
    expect(postCount, 2);
    expect(idempotencyKeys.first, isNotEmpty);
    expect(idempotencyKeys.toSet(), hasLength(1));
  });
}

class _MemoryBetaUserStorage implements BetaUserStorage {
  _MemoryBetaUserStorage({
    this.userIdWriteSucceeds = true,
    this.userId,
    this.installationId,
  });

  final bool userIdWriteSucceeds;
  String? userId;
  String? installationId;

  @override
  Future<String?> readUserId() async => userId;

  @override
  Future<bool> writeUserId(String userId) async {
    if (!userIdWriteSucceeds) return false;
    this.userId = userId;
    return true;
  }

  @override
  Future<void> clearUserId() async {
    userId = null;
  }

  @override
  Future<String?> readInstallationId() async => installationId;

  @override
  Future<bool> writeInstallationId(String installationId) async {
    this.installationId = installationId;
    return true;
  }
}

http.Response _userResponse(int statusCode) {
  return http.Response(
    '''
      {
        "id": "90000000-0000-0000-0000-000000000001",
        "email": null,
        "displayName": "베타 사용자 1",
        "betaNumber": 1,
        "anonymous": true
      }
    ''',
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

http.Response _problemResponse(int statusCode, String code) {
  return http.Response(
    '{"status": $statusCode, "code": "$code"}',
    statusCode,
    headers: const {'content-type': 'application/problem+json'},
  );
}
