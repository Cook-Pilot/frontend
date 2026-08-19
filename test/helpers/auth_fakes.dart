import 'package:cookpilot/features/auth/data/auth_api.dart';
import 'package:cookpilot/features/auth/data/auth_session.dart';

/// 메모리에만 남는 토큰 저장소. 테스트가 OS 보안 저장소(키체인)를 건드리지 않게 한다.
class FakeTokenStorage implements AuthTokenStorage {
  AuthSessionToken? stored;

  @override
  Future<AuthSessionToken?> read() async => stored;

  @override
  Future<void> write(AuthSessionToken token) async => stored = token;

  @override
  Future<void> clear() async => stored = null;
}

const testSessionUserId = '90000000-0000-0000-0000-000000000001';

/// 로그인된 세션이 실제로 내보내는 헤더 값. API 테스트는 이걸로 요청을 검증한다.
const testAuthHeader = 'Bearer test-jwt';

/// 로그인된 세션을 만든다. API 를 부르는 테스트는 setUp 에서 이걸 호출한다.
Future<void> signInForTest() async {
  AuthSession.debugReset();
  AuthSession.debugUseStorage(FakeTokenStorage());
  await AuthSession.save(
    AuthSessionToken(
      token: 'test-jwt',
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
      userId: testSessionUserId,
      displayName: '테스트 사용자',
    ),
  );
}

/// 로그아웃 상태로 되돌린다.
void resetAuthForTest() => AuthSession.debugReset();
