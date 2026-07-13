import 'package:flutter/material.dart';

import '../features/mvp/auth_screen.dart';
import 'app_theme.dart';

class CookPilotApp extends StatelessWidget {
  const CookPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CookPilot',
      debugShowCheckedModeBanner: false,
      theme: buildCookPilotTheme(),
      home: const AuthScreen(),
    );
  }
}
