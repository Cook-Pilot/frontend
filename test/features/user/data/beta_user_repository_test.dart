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
  _MemoryBetaUserStorage({this.userIdWriteSucceeds = true});

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
  Future<bool> removeUserId() async {
    final existed = userId != null;
    userId = null;
    return existed;
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
