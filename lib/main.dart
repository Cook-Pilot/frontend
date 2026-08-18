import 'package:flutter/material.dart';

import 'app/cookpilot_app.dart';
import 'features/auth/data/auth_session.dart';

Future<void> main() async {
  // 저장된 세션 토큰을 읽으려면 플러그인 채널이 먼저 준비돼야 한다.
  WidgetsFlutterBinding.ensureInitialized();

  // 복원에 성공하면 로그인 화면을 건너뛴다. 실패(토큰 없음·만료·저장소 오류)는
  // 예외가 아니라 false 로 돌아오므로 앱은 항상 뜬다.
  final restored = await AuthSession.restore();

  runApp(CookPilotApp(startLoggedIn: restored));
}
