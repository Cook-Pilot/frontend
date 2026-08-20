import 'package:cookpilot/features/auth/data/auth_api.dart';
import 'package:cookpilot/features/auth/data/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';

AuthSessionToken tokenExpiring(Duration fromNow) => AuthSessionToken(
  token: 'jwt',
  expiresAt: DateTime.now().toUtc().add(fromNow),
  userId: 'user-1',
  displayName: '개발자',
);

void main() {
  late FakeTokenStorage storage;

  setUp(() {
    storage = FakeTokenStorage();
    AuthSession.debugReset();
    AuthSession.debugUseStorage(storage);
  });

  tearDown(resetAuthForTest);

  test('저장한 토큰은 Bearer 헤더로 나온다', () async {
    await AuthSession.save(tokenExpiring(const Duration(days: 1)));

    expect(AuthSession.requestHeaders, {'Authorization': 'Bearer jwt'});
    expect(AuthSession.isLoggedIn, isTrue);
  });

  test('로그인 전에는 요청 헤더를 만들지 못한다', () {
    expect(() => AuthSession.requestHeaders, throwsA(isA<AuthException>()));
    expect(AuthSession.isLoggedIn, isFalse);
  });

  test('만료된 토큰으로도 요청 헤더를 만들지 못한다', () async {
    await AuthSession.save(tokenExpiring(const Duration(minutes: -1)));

    expect(() => AuthSession.requestHeaders, throwsA(isA<AuthException>()));
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

    expect(() => AuthSession.requestHeaders, throwsA(isA<AuthException>()));
    expect(storage.stored, isNull);
  });
}
