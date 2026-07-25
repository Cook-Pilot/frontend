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
