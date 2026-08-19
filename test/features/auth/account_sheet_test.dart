import 'package:cookpilot/features/auth/data/auth_api.dart';
import 'package:cookpilot/features/auth/data/auth_session.dart';
import 'package:cookpilot/features/auth/presentation/account_sheet.dart';
import 'package:flutter/material.dart';
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

class _FirstScreen extends StatelessWidget {
  const _FirstScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('첫 화면'));
}

Widget hostWith(GlobalKey<NavigatorState> navigatorKey) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showAccountSheet(
              context,
              firstScreen: () => const _FirstScreen(),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late _FakeTokenStorage storage;

  setUp(() async {
    storage = _FakeTokenStorage();
    AuthSession.debugReset();
    AuthSession.debugUseStorage(storage);
    await AuthSession.save(
      AuthSessionToken(
        token: 'jwt',
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        userId: 'user-1',
        displayName: '개발자',
      ),
    );
  });

  tearDown(AuthSession.debugReset);

  testWidgets('로그아웃하면 세션을 지우고 첫 화면으로 되돌린다', (tester) async {
    await tester.pumpWidget(hostWith(GlobalKey<NavigatorState>()));

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('개발자'), findsOneWidget);

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    expect(AuthSession.isLoggedIn, isFalse);
    expect(storage.stored, isNull);
    expect(find.text('첫 화면'), findsOneWidget);
  });

  testWidgets('시트를 닫기만 하면 세션이 유지된다', (tester) async {
    await tester.pumpWidget(hostWith(GlobalKey<NavigatorState>()));

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    // 바깥을 눌러 시트를 닫는다.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(AuthSession.isLoggedIn, isTrue);
    expect(storage.stored, isNotNull);
    expect(find.text('첫 화면'), findsNothing);
  });
}
