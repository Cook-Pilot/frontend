import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'app/cookpilot_app.dart';
import 'core/api/social_config.dart';
import 'features/auth/data/auth_session.dart';

Future<void> main() async {
  // 저장된 세션 토큰을 읽으려면 플러그인 채널이 먼저 준비돼야 한다.
  WidgetsFlutterBinding.ensureInitialized();

  // 로그인 시점에는 초기화가 끝나 있어야 하므로 기다린다.
  await KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);

  // 이 빌드의 키 해시. 개발자마다 다르므로 각자 카카오 콘솔에 등록해야 하고,
  // 등록이 안 맞으면 로그인이 'Android keyHash validation failed' 로 실패한다.
  // 디버그 빌드에서만 찍힌다.
  if (kDebugMode) {
    debugPrint('[카카오] 이 빌드의 키 해시 = ${KakaoSdk.platformInfo.origin}');
  }

  // 복원에 성공하면 로그인 화면을 건너뛴다. 실패(토큰 없음·만료·저장소 오류)는
  // 예외가 아니라 false 로 돌아오므로 앱은 항상 뜬다.
  final restored = await AuthSession.restore();

  runApp(CookPilotApp(startLoggedIn: restored));
}
