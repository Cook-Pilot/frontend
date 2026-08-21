import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'auth_api.dart';

/// 애플 로그인(Sign in with Apple)으로 identity token 을 받아온다. 이 토큰은 서버가 애플
/// 공개키(JWKS)로 검증하므로(`POST /auth/apple`) 클라이언트가 신원을 주장하는 구조가 아니다.
///
/// iOS 전용이다. 안드로이드에서 쓰려면 Services ID 와 서버 리다이렉트 콜백이 더 필요해
/// 아직 붙이지 않았다(`docs/feat-apple-login.md`).
///
/// 사용자가 취소하면 [AppleLoginCancelled] 를 던진다 — 실패 안내를 띄우면 안 되는 경우다.
class AppleLogin {
  const AppleLogin();

  Future<AppleLoginResult> obtainIdentityToken() async {
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AppleLoginCancelled();
      }
      throw const AuthException('Apple 로그인에 실패했습니다.');
    } on Object {
      throw const AuthException('Apple 로그인에 실패했습니다.');
    }

    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      // Xcode 의 Sign in with Apple capability 가 빠졌거나 번들 ID 가 등록되지 않은 경우다.
      throw const AuthException('Apple 인증 정보를 받지 못했습니다.');
    }
    return AppleLoginResult(
      identityToken: identityToken,
      displayName: _displayName(credential),
    );
  }

  /// 애플은 이름을 **최초 로그인 1회만** 준다(토큰에는 아예 없다). 그래서 이때 받은 이름을
  /// 서버로 같이 보내 계정 생성 시 쓰게 한다. 두 번째 로그인부터는 null 이고, 서버는 이미
  /// 만들어진 계정의 이름을 건드리지 않는다.
  static String? _displayName(AuthorizationCredentialAppleID credential) {
    final family = credential.familyName?.trim() ?? '';
    final given = credential.givenName?.trim() ?? '';
    if (family.isEmpty && given.isEmpty) return null;
    // 한글 이름은 성+이름을 붙여 쓰고(홍길동), 그 외는 이름 성 순서로 띄어 쓴다(Tim Cook).
    final hangul = RegExp(r'[가-힣]');
    final name = hangul.hasMatch(family) || hangul.hasMatch(given)
        ? '$family$given'
        : [given, family].where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? null : name;
  }
}

class AppleLoginResult {
  const AppleLoginResult({required this.identityToken, this.displayName});

  final String identityToken;

  /// 최초 로그인에만 온다. 이후에는 null.
  final String? displayName;
}

/// 사용자가 로그인 창을 닫았다. 오류가 아니므로 조용히 돌아간다.
class AppleLoginCancelled implements Exception {
  const AppleLoginCancelled();
}
