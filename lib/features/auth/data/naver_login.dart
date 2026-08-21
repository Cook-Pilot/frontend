import 'package:flutter/foundation.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
// 결과 타입은 메인 라이브러리가 export 하지 않는다(플러그인 2.1.1).
import 'package:flutter_naver_login/interface/types/naver_login_result.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';

import 'auth_api.dart';

/// 네이버 로그인으로 액세스 토큰을 받아온다. 이 토큰은 서버가 네이버 프로필 API 에 되물어
/// 검증하므로(`POST /auth/naver`) 클라이언트가 신원을 주장하는 구조가 아니다.
///
/// 카카오와 같은 액세스 토큰 방식이다(네이버는 OIDC ID 토큰을 주지 않는다). 네이버 앱이
/// 깔려 있으면 앱으로, 아니면 웹 로그인으로 가는 분기는 SDK 가 알아서 한다.
///
/// 사용자가 취소하면 [NaverLoginCancelled] 를 던진다 — 실패 안내를 띄우면 안 되는 경우다.
class NaverLogin {
  const NaverLogin();

  Future<String> obtainAccessToken() async {
    final NaverLoginResult result;
    try {
      result = await FlutterNaverLogin.logIn();
    } on Object catch (error, stackTrace) {
      debugPrint('[네이버] 로그인 실패 ($error)');
      debugPrintStack(stackTrace: stackTrace, maxFrames: 5);
      throw const AuthException('네이버 로그인에 실패했습니다.');
    }

    switch (result.status) {
      case NaverLoginStatus.loggedIn:
        final token = result.accessToken?.accessToken;
        if (token == null || token.isEmpty) {
          // 로그인은 됐다는데 토큰이 없다 — 콘솔 설정(Client ID/Secret·패키지명)이 어긋난 경우.
          throw const AuthException('네이버 인증 정보를 받지 못했습니다.');
        }
        return token;
      case NaverLoginStatus.loggedOut:
        // 플러그인은 사용자 취소(user_cancel)를 loggedOut 으로 돌려준다.
        throw const NaverLoginCancelled();
      case NaverLoginStatus.error:
        // 원인을 삼키면 진단할 수 없다. 사용자에게는 일반 문구를 보이되 로그에는 남긴다.
        debugPrint('[네이버] 로그인 실패: ${result.errorMessage}');
        throw const AuthException('네이버 로그인에 실패했습니다.');
    }
  }
}

/// 사용자가 로그인 창을 닫았다. 오류가 아니므로 조용히 돌아간다.
class NaverLoginCancelled implements Exception {
  const NaverLoginCancelled();
}
