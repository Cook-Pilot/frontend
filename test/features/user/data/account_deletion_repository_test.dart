import 'package:cookpilot/features/auth/data/auth_api.dart';
import 'package:cookpilot/features/auth/data/auth_session.dart';
import 'package:cookpilot/features/review/application/pending_review_draft_store.dart';
import 'package:cookpilot/features/user/data/account_deletion_repository.dart';
import 'package:cookpilot/features/user/data/beta_user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../helpers/review_photo_fakes.dart';

void main() {
  const baseUrl = 'http://example.test';
  const userId = '90000000-0000-0000-0000-000000000001';

  setUp(() {
    BetaUserSession.setCurrentUser(
      const BetaUser(id: userId, displayName: '베타 사용자', betaNumber: 1),
    );
  });

  tearDown(() {
    BetaUserSession.clear();
    AuthSession.debugReset();
  });

  group('AccountDeletionRepository', () {
    test('204면 성공한다', () async {
      var called = false;
      final repository = AccountDeletionRepository(
        baseUrl: baseUrl,
        client: MockClient((request) async {
          called = true;
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/v1/users/me');
          expect(request.headers[cookPilotUserIdHeader], userId);
          return http.Response('', 204);
        }),
      );

      await repository.deleteAccount();
      expect(called, isTrue);
    });

    test('404 USER_NOT_FOUND는 이미 삭제된 것이므로 성공으로 본다', () async {
      final repository = AccountDeletionRepository(
        baseUrl: baseUrl,
        client: MockClient(
          (_) async => http.Response('{"code":"USER_NOT_FOUND"}', 404),
        ),
      );

      await repository.deleteAccount();
    });

    test('그 밖의 404와 5xx는 예외를 던진다 — 세션을 지우면 안 된다', () async {
      for (final response in [
        http.Response('not found', 404),
        http.Response('{"detail":"boom"}', 500),
      ]) {
        final repository = AccountDeletionRepository(
          baseUrl: baseUrl,
          client: MockClient((_) async => response),
        );
        await expectLater(
          repository.deleteAccount(),
          throwsA(isA<BetaUserException>()),
        );
      }
    });
  });

  group('LocalAccountDataWiper', () {
    test('세션·저장된 사용자 id·사진·후기 초안을 모두 지운다', () async {
      final tokenStorage = _MemoryTokenStorage();
      AuthSession.debugUseStorage(tokenStorage);
      await AuthSession.save(
        AuthSessionToken(
          token: 'jwt',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
          userId: userId,
          displayName: '테스터',
        ),
      );
      final betaStorage = _MemoryBetaUserStorage(userId: userId);
      final photoStore = InMemoryReviewPhotoFileStore()
        ..existingPaths.add('review_photos/some-session/a.jpg');
      final draftStore = _MemoryDraftGateway();

      await LocalAccountDataWiper(
        betaUserStorage: betaStorage,
        photoStore: photoStore,
        draftStore: draftStore,
      ).wipe();

      expect(AuthSession.current, isNull);
      expect(tokenStorage.cleared, isTrue);
      expect(BetaUserSession.currentUser, isNull);
      expect(betaStorage.userId, isNull);
      expect(photoStore.existingPaths, isEmpty);
      expect(draftStore.cleared, isTrue);
    });

    test('한 단계가 실패해도 나머지는 지운다', () async {
      final betaStorage = _MemoryBetaUserStorage(userId: userId)
        ..failOnClear = true;
      final photoStore = InMemoryReviewPhotoFileStore()
        ..existingPaths.add('review_photos/some-session/a.jpg');
      final draftStore = _MemoryDraftGateway();

      await LocalAccountDataWiper(
        betaUserStorage: betaStorage,
        photoStore: photoStore,
        draftStore: draftStore,
      ).wipe();

      expect(photoStore.existingPaths, isEmpty);
      expect(draftStore.cleared, isTrue);
    });
  });
}

class _MemoryTokenStorage implements AuthTokenStorage {
  AuthSessionToken? token;
  bool cleared = false;

  @override
  Future<AuthSessionToken?> read() async => token;

  @override
  Future<void> write(AuthSessionToken token) async {
    this.token = token;
  }

  @override
  Future<void> clear() async {
    token = null;
    cleared = true;
  }
}

class _MemoryBetaUserStorage implements BetaUserStorage {
  _MemoryBetaUserStorage({this.userId});

  String? userId;
  bool failOnClear = false;

  @override
  Future<String?> readUserId() async => userId;

  @override
  Future<bool> writeUserId(String userId) async {
    this.userId = userId;
    return true;
  }

  @override
  Future<void> clearUserId() async {
    if (failOnClear) {
      throw StateError('clear 실패');
    }
    userId = null;
  }

  @override
  Future<String?> readInstallationId() async => null;

  @override
  Future<bool> writeInstallationId(String installationId) async => true;
}

class _MemoryDraftGateway implements PendingReviewDraftGateway {
  bool cleared = false;

  @override
  Future<void> save(PendingReviewDraft draft) async {}

  @override
  Future<PendingReviewDraft?> load() async => null;

  @override
  Future<void> clear() async {
    cleared = true;
  }
}
