import 'package:flutter/material.dart';

import '../features/mvp/main_shell.dart';
import 'app_theme.dart';
import 'cooklog_mark.dart';

class CookPilotApp extends StatelessWidget {
  const CookPilotApp({super.key, this.startup});

  /// 앱을 띄우기 전에 끝나야 하는 준비 작업(세션 복원 등).
  /// null 이면 곧바로 홈으로 간다 — 테스트에서 그렇게 쓴다.
  final Future<void>? startup;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CookPilot',
      debugShowCheckedModeBanner: false,
      theme: buildCookPilotTheme(),
      // 게스트 우선: 앱은 항상 홈에서 시작한다. 로그인은 저장이 필요한 순간
      // (후기·즐겨찾기·마이)에만 화면 위로 띄운다.
      home: startup == null ? const MainShell() : _Startup(work: startup!),
    );
  }
}

/// 준비 작업이 끝날 때까지 랜딩 화면을 보여 준다.
class _Startup extends StatefulWidget {
  const _Startup({required this.work});

  final Future<void> work;

  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  /// 준비가 눈 깜짝할 새 끝나도 로고는 이만큼 머무른다. 한 프레임 스쳐 지나가면
  /// 브랜드가 보이는 게 아니라 화면이 깜빡인 것으로 읽힌다.
  static const _minimumHold = Duration(milliseconds: 900);

  late final Future<void> _ready = Future.wait([
    widget.work,
    Future<void>.delayed(_minimumHold),
  ]);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CookLogLanding();
        }
        return const MainShell();
      },
    );
  }
}
