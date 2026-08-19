import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'auth_api.dart';

/// 카카오 로그인으로 액세스 토큰을 받아온다. 이 토큰은 서버가 카카오에 되물어 검증하므로
/// (`POST /auth/kakao`) 클라이언트가 신원을 주장하는 구조가 아니다.
///
/// 사용자가 취소하면 [KakaoLoginCancelled] 를 던진다 — 실패 안내를 띄우면 안 되는 경우다.
class KakaoLogin {
  const KakaoLogin();

  Future<String> obtainAccessToken() async {
    // 카카오톡이 깔려 있으면 앱으로, 아니면 웹 계정 로그인으로 간다.
    if (await isKakaoTalkInstalled()) {
      try {
        final token = await UserApi.instance.loginWithKakaoTalk();
        return token.accessToken;
      } on PlatformException catch (error) {
        if (error.code == 'CANCELED') {
          throw const KakaoLoginCancelled();
        }
        debugPrint('[카카오] 카카오톡 로그인 실패 → 웹으로 재시도: $error');
        // 카카오톡은 있는데 실패한 경우(로그인 안 된 카카오톡 등) 웹으로 한 번 더 시도한다.
        return _loginWithAccount();
      }
    }
    return _loginWithAccount();
  }

  Future<String> _loginWithAccount() async {
    try {
      final token = await UserApi.instance.loginWithKakaoAccount();
      return token.accessToken;
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED') {
        throw const KakaoLoginCancelled();
      }
      // 원인을 삼키면 진단할 수 없다. 사용자에게는 일반 문구를 보이되 로그에는 남긴다.
      debugPrint(
        '[카카오] 로그인 실패 (PlatformException ${error.code}): ${error.message}',
      );
      throw const AuthException('카카오 로그인에 실패했습니다.');
    } on Object catch (error, stackTrace) {
      debugPrint('[카카오] 로그인 실패 ($error)');
      debugPrintStack(stackTrace: stackTrace, maxFrames: 5);
      throw const AuthException('카카오 로그인에 실패했습니다.');
    }
  }
}

/// 사용자가 로그인 창을 닫았다. 오류가 아니므로 조용히 돌아간다.
class KakaoLoginCancelled implements Exception {
  const KakaoLoginCancelled();
}
