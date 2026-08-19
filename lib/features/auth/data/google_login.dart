import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/api/social_config.dart';
import 'auth_api.dart';

/// 구글 로그인으로 ID 토큰을 받아온다. 이 토큰은 서버가 구글 공개키(JWKS)로 검증하므로
/// (`POST /auth/google`) 클라이언트가 신원을 주장하는 구조가 아니다.
///
/// 사용자가 취소하면 [GoogleLoginCancelled] 를 던진다 — 실패 안내를 띄우면 안 되는 경우다.
class GoogleLogin {
  const GoogleLogin();

  static bool _initialized = false;

  Future<String> obtainIdToken() async {
    await _ensureInitialized();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleLoginCancelled();
      }
      throw const AuthException('구글 로그인에 실패했습니다.');
    } on Object {
      throw const AuthException('구글 로그인에 실패했습니다.');
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      // serverClientId 가 잘못됐거나 콘솔 설정이 어긋나면 토큰 없이 돌아온다.
      throw const AuthException('구글 인증 정보를 받지 못했습니다.');
    }
    return idToken;
  }

  /// initialize 는 한 번만 호출한다. serverClientId 를 넘겨야 ID 토큰이 발급된다.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: googleServerClientId,
    );
    _initialized = true;
  }
}

/// 사용자가 로그인 창을 닫았다. 오류가 아니므로 조용히 돌아간다.
class GoogleLoginCancelled implements Exception {
  const GoogleLoginCancelled();
}
