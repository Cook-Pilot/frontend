import 'package:cookpilot/features/auth/data/auth_api.dart';
import 'package:cookpilot/features/auth/data/auth_session.dart';
import 'package:cookpilot/features/auth/presentation/account_sheet.dart';
import 'package:cookpilot/features/user/data/account_deletion_repository.dart';
import 'package:cookpilot/features/user/data/beta_user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:cookpilot/features/review/application/pending_review_draft_store.dart';

import '../../helpers/review_photo_fakes.dart';

void main() {
  const userId = '90000000-0000-0000-0000-000000000001';

  setUp(() {
    BetaUserSession.setCurrentUser(
      const BetaUser(id: userId, displayName: '베타 사용자', betaNumber: 1),
    );
    // 실제 보안 저장소는 테스트 환경에 플러그인이 없어 wipe 가 끝나지 않는다.
    AuthSession.debugUseStorage(_MemoryTokenStorage());
  });

  tearDown(() {
    BetaUserSession.clear();
    AuthSession.debugReset();
  });

  Future<void> openSheet(
    WidgetTester tester, {
    required http.Client client,
  }) async {
    final wiper = LocalAccountDataWiper(
      betaUserStorage: _NoopBetaStorage(),
      photoStore: InMemoryReviewPhotoFileStore(),
      draftStore: _NoopDraftGateway(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAccountSheet(
                  context,
                  firstScreen: () => const Scaffold(body: Text('첫 화면으로 돌아옴')),
                  deletionRepository: AccountDeletionRepository(
                    baseUrl: 'http://example.test',
                    client: client,
                  ),
                  dataWiper: wiper,
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  testWidgets('로그아웃하면 세션을 지우고 첫 화면으로 되돌린다', (tester) async {
    final storage = _MemoryTokenStorage();
    AuthSession.debugUseStorage(storage);
    await AuthSession.save(
      AuthSessionToken(
        token: 'jwt',
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        userId: userId,
        displayName: '개발자',
      ),
    );
    await openSheet(
      tester,
      client: MockClient((_) async => http.Response('', 500)),
    );

    expect(find.text('개발자'), findsOneWidget);
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    expect(AuthSession.isLoggedIn, isFalse);
    expect(storage.token, isNull);
    expect(find.text('첫 화면으로 돌아옴'), findsOneWidget);
  });

  testWidgets('시트를 닫기만 하면 세션이 유지된다', (tester) async {
    final storage = _MemoryTokenStorage();
    AuthSession.debugUseStorage(storage);
    await AuthSession.save(
      AuthSessionToken(
        token: 'jwt',
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        userId: userId,
        displayName: '개발자',
      ),
    );
    await openSheet(
      tester,
      client: MockClient((_) async => http.Response('', 500)),
    );

    // 바깥을 눌러 시트를 닫는다.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(AuthSession.isLoggedIn, isTrue);
    expect(storage.token, isNotNull);
    expect(find.text('첫 화면으로 돌아옴'), findsNothing);
  });

  testWidgets('탈퇴는 재확인을 거쳐 서버 삭제 후 첫 화면으로 돌아온다', (tester) async {
    var deleteCalled = false;
    await openSheet(
      tester,
      client: MockClient((request) async {
        deleteCalled = true;
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/users/me');
        return http.Response('', 204);
      }),
    );

    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();

    // 재확인 다이얼로그 — 여기까지는 아무것도 지워지지 않는다.
    expect(find.text('정말 탈퇴할까요?'), findsOneWidget);
    expect(deleteCalled, isFalse);

    await tester.tap(find.text('탈퇴'));
    await tester.pumpAndSettle();

    expect(deleteCalled, isTrue);
    expect(find.text('첫 화면으로 돌아옴'), findsOneWidget);
  });

  testWidgets('재확인에서 취소하면 아무것도 하지 않는다', (tester) async {
    var deleteCalled = false;
    await openSheet(
      tester,
      client: MockClient((_) async {
        deleteCalled = true;
        return http.Response('', 204);
      }),
    );

    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(deleteCalled, isFalse);
    expect(find.text('첫 화면으로 돌아옴'), findsNothing);
  });

  testWidgets('서버 삭제가 실패하면 화면에 남고 실패를 알린다', (tester) async {
    await openSheet(
      tester,
      client: MockClient((_) async => http.Response('{"detail":"x"}', 500)),
    );

    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴'));
    await tester.pumpAndSettle();

    expect(find.text('첫 화면으로 돌아옴'), findsNothing);
    expect(find.text('계정 삭제에 실패했습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
  });
}

class _NoopBetaStorage implements BetaUserStorage {
  @override
  Future<String?> readUserId() async => null;

  @override
  Future<bool> writeUserId(String userId) async => true;

  @override
  Future<void> clearUserId() async {}

  @override
  Future<String?> readInstallationId() async => null;

  @override
  Future<bool> writeInstallationId(String installationId) async => true;
}

class _NoopDraftGateway implements PendingReviewDraftGateway {
  @override
  Future<void> save(PendingReviewDraft draft) async {}

  @override
  Future<PendingReviewDraft?> load() async => null;

  @override
  Future<void> clear() async {}
}

class _MemoryTokenStorage implements AuthTokenStorage {
  AuthSessionToken? token;

  @override
  Future<AuthSessionToken?> read() async => token;

  @override
  Future<void> write(AuthSessionToken token) async {
    this.token = token;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}
