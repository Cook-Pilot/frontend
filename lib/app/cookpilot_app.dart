import 'package:flutter/material.dart';

import '../features/mvp/auth_screen.dart';
import '../features/mvp/main_shell.dart';
import 'app_theme.dart';

class CookPilotApp extends StatelessWidget {
  const CookPilotApp({super.key, this.startLoggedIn = false});

  /// 저장된 세션을 복원했는지. 참이면 로그인 화면 없이 바로 홈으로 시작한다.
  final bool startLoggedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CookPilot',
      debugShowCheckedModeBanner: false,
      theme: buildCookPilotTheme(),
      home: startLoggedIn ? const MainShell() : const AuthScreen(),
    );
  }
}
