import 'package:cookpilot/features/auth/data/auth_api.dart';
import 'package:cookpilot/features/auth/data/auth_session.dart';
import 'package:cookpilot/features/user/data/beta_user_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTokenStorage implements AuthTokenStorage {
  AuthSessionToken? stored;

  @override
  Future<AuthSessionToken?> read() async => stored;

  @override
  Future<void> write(AuthSessionToken token) async => stored = token;

  @override
  Future<void> clear() async => stored = null;
}

AuthSessionToken tokenExpiring(Duration fromNow) => AuthSessionToken(
  token: 'jwt',
  expiresAt: DateTime.now().toUtc().add(fromNow),
  userId: 'user-1',
  displayName: '개발자',
);

void main() {
  late _FakeTokenStorage storage;

  setUp(() {
    storage = _FakeTokenStorage();
    AuthSession.debugReset();
    AuthSession.debugUseStorage(storage);
  });

  tearDown(() {
    AuthSession.debugReset();
    BetaUserSession.clear();
  });

  test('저장한 토큰은 Bearer 헤더로 나온다', () async {
    await AuthSession.save(tokenExpiring(const Duration(days: 1)));

    expect(AuthSession.requestHeaders, {'Authorization': 'Bearer jwt'});
    expect(AuthSession.isLoggedIn, isTrue);
  });

  test('만료된 토큰은 헤더를 내지 않는다', () async {
    await AuthSession.save(tokenExpiring(const Duration(minutes: -1)));

    expect(AuthSession.requestHeaders, isEmpty);
    expect(AuthSession.isLoggedIn, isFalse);
  });

  test('restore 는 저장된 토큰을 복원한다', () async {
    storage.stored = tokenExpiring(const Duration(days: 1));

    expect(await AuthSession.restore(), isTrue);
    expect(AuthSession.current?.userId, 'user-1');
  });

  test('restore 는 만료된 토큰을 지우고 실패한다', () async {
    storage.stored = tokenExpiring(const Duration(minutes: -1));

    expect(await AuthSession.restore(), isFalse);
    expect(storage.stored, isNull);
  });

  test('signOut 은 메모리와 저장소를 모두 비운다', () async {
    await AuthSession.save(tokenExpiring(const Duration(days: 1)));

    await AuthSession.signOut();

    expect(AuthSession.requestHeaders, isEmpty);
    expect(storage.stored, isNull);
  });

  group('전환기 헤더 규칙', () {
    test('토큰이 있으면 Bearer 를 쓴다', () async {
      BetaUserSession.setCurrentUser(
        const BetaUser(
          id: '11111111-1111-1111-1111-111111111111',
          displayName: '베타 사용자 1',
          betaNumber: 1,
        ),
      );
      await AuthSession.save(tokenExpiring(const Duration(days: 1)));

      expect(BetaUserSession.requestHeaders, {'Authorization': 'Bearer jwt'});
    });

    test('토큰이 없으면 기존 익명 헤더로 떨어진다', () {
      BetaUserSession.setCurrentUser(
        const BetaUser(
          id: '11111111-1111-1111-1111-111111111111',
          displayName: '베타 사용자 1',
          betaNumber: 1,
        ),
      );

      expect(BetaUserSession.requestHeaders, {
        cookPilotUserIdHeader: '11111111-1111-1111-1111-111111111111',
      });
    });
  });
}
