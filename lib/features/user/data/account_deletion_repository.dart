import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import '../../auth/data/auth_session.dart';
import '../../review/application/pending_review_draft_store.dart';
import '../../review/application/review_photo_file_store.dart';
import 'beta_user_repository.dart';

/// `DELETE /api/v1/users/me` — 계정과 서버의 모든 개인정보(후기·사진·개인 레시피·
/// 즐겨찾기·추천 반응)를 한 번에 삭제한다. 개인정보처리방침 제9조가 약속하는 동작.
///
/// 서버 삭제와 로컬 정리([LocalAccountDataWiper])는 분리되어 있다 — 서버가 204 를
/// 돌려준 뒤에만 로컬을 지워야, 실패 시 세션이 남아 있어 재시도할 수 있다.
class AccountDeletionRepository {
  AccountDeletionRepository({
    http.Client? client,
    String? baseUrl,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? cookPilotApiBaseUrl();

  final http.Client _client;
  final String _baseUrl;

  /// 서버가 S3 사진 삭제까지 마치고 응답하므로 일반 API 보다 여유를 둔다.
  final Duration requestTimeout;

  /// 204 = 삭제 완료. 404 USER_NOT_FOUND 도 성공으로 본다 —
  /// 앞선 시도가 서버에서는 끝났는데 응답만 유실된 재시도 경로다(서버 쪽 멱등 규칙과 짝).
  Future<void> deleteAccount() async {
    final response = await _client
        .delete(
          Uri.parse('$_baseUrl/api/v1/users/me'),
          headers: BetaUserSession.requestHeaders,
        )
        .timeout(requestTimeout);

    if (response.statusCode == 204) return;
    if (_isUserNotFound(response)) return;
    throw BetaUserException('계정 삭제에 실패했습니다. (${response.statusCode})');
  }

  bool _isUserNotFound(http.Response response) {
    if (response.statusCode != 404) return false;
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> &&
          decoded['code'] == 'USER_NOT_FOUND';
    } on FormatException {
      return false;
    }
  }
}

/// 탈퇴 후 기기에 남는 개인 데이터 정리. 세션(토큰·익명 id)과 함께
/// 후기 사진 파일·작성 중 초안까지 지운다 — 방침이 약속한 "사진 파일까지 삭제"의
/// 기기 쪽 절반이다(서버 쪽은 S3 접두사 삭제).
///
/// 각 단계는 best-effort 다. 서버 삭제가 이미 끝난 뒤라 여기서 던지면 사용자가
/// 할 수 있는 게 없다 — 남은 파일은 다음 설치·세션이 덮거나 앱 삭제로 사라진다.
class LocalAccountDataWiper {
  LocalAccountDataWiper({
    BetaUserStorage? betaUserStorage,
    ReviewPhotoFileGateway? photoStore,
    PendingReviewDraftGateway? draftStore,
  }) : _betaUserStorage =
           betaUserStorage ?? const SharedPreferencesBetaUserStorage(),
       _photoStore = photoStore ?? ReviewPhotoFileStore(),
       _draftStore = draftStore ?? PendingReviewDraftStore();

  final BetaUserStorage _betaUserStorage;
  final ReviewPhotoFileGateway _photoStore;
  final PendingReviewDraftGateway _draftStore;

  Future<void> wipe() async {
    await _bestEffort(AuthSession.signOut);
    BetaUserSession.clear();
    // 저장된 익명 id 를 지워야 다음 부팅이 삭제된 계정을 다시 찾지 않는다.
    // (남아 있어도 404 → 재발급으로 자가 복구되지만, 즉시 지우는 쪽이 명확하다.)
    await _bestEffort(_betaUserStorage.clearUserId);
    await _bestEffort(_draftStore.clear);
    await _bestEffort(_photoStore.clearAll);
  }

  Future<void> _bestEffort(Future<void> Function() operation) async {
    try {
      await operation();
    } on Object {
      // 위 doc comment 참고 — 로컬 정리 실패가 탈퇴 완료 화면 전환을 막으면 안 된다.
    }
  }
}
