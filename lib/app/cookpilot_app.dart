import 'package:flutter/material.dart';

import '../features/mvp/main_shell.dart';
import 'app_theme.dart';

class CookPilotApp extends StatelessWidget {
  const CookPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CookPilot',
      debugShowCheckedModeBanner: false,
      theme: buildCookPilotTheme(),
      // 게스트 우선: 앱은 항상 홈에서 시작한다. 로그인은 저장이 필요한 순간
      // (후기·즐겨찾기·마이)에만 화면 위로 띄운다.
      home: const MainShell(),
    );
  }
}
