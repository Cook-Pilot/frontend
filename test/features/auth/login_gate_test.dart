import 'package:cookpilot/features/auth/presentation/login_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';

class _LoginScreen extends StatelessWidget {
  const _LoginScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        // 실제 화면은 로그인 성공 시 pop(true) — 여기서는 그 계약만 흉내 낸다.
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('로그인 성공'),
      ),
    ),
  );
}

Widget _host(void Function(Future<bool>) onResult) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => onResult(
              ensureLoggedIn(
                context,
                reason: '후기를 저장하려면 로그인이 필요해요',
                loginScreen: () => const _LoginScreen(),
              ),
            ),
            child: const Text('저장'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('로그인 상태면 시트 없이 바로 통과한다', (tester) async {
    await signInForTest();
    Future<bool>? result;
    await tester.pumpWidget(_host((r) => result = r));

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-gate-login-button')), findsNothing);
    await expectLater(result, completion(isTrue));
  });

  testWidgets('게스트가 다음에 할게요를 누르면 false', (tester) async {
    resetAuthForTest();
    Future<bool>? result;
    await tester.pumpWidget(_host((r) => result = r));

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('후기를 저장하려면 로그인이 필요해요'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-gate-later-button')));
    await tester.pumpAndSettle();

    await expectLater(result, completion(isFalse));
  });

  testWidgets('게스트가 로그인까지 마치면 true', (tester) async {
    resetAuthForTest();
    Future<bool>? result;
    await tester.pumpWidget(_host((r) => result = r));

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-gate-login-button')));
    await tester.pumpAndSettle();

    // 로그인 화면이 떴다. 성공(pop true) 전에 세션도 실제로 생겨야 한다 —
    // 게이트는 pop 값과 세션 둘 다 확인한다.
    await signInForTest();
    await tester.tap(find.text('로그인 성공'));
    await tester.pumpAndSettle();

    await expectLater(result, completion(isTrue));
  });

  testWidgets('로그인 화면을 닫기만 하면 false', (tester) async {
    resetAuthForTest();
    Future<bool>? result;
    await tester.pumpWidget(_host((r) => result = r));

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-gate-login-button')));
    await tester.pumpAndSettle();

    // 세션 없이 pop — 뒤로가기와 같다.
    Navigator.of(tester.element(find.text('로그인 성공'))).pop(false);
    await tester.pumpAndSettle();

    await expectLater(result, completion(isFalse));
  });
}
