import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../auth/data/auth_api.dart';
import '../auth/data/auth_session.dart';
import '../auth/data/google_login.dart';
import '../auth/data/kakao_login.dart';
import '../auth/presentation/developer_login.dart';
import '../user/data/user_profile_repository.dart';
import 'main_shell.dart';
import 'mvp_widgets.dart';
import 'profile_onboarding_screen.dart';

/// 로그인 직후 갈 화면. 아직 프로필을 물어보지 않았으면 온보딩을 먼저 띄운다.
///
/// 프로필 확인이 실패하거나 늦어도 홈 진입을 막지 않는다 — 온보딩은 다음 로그인에서
/// 다시 시도하면 되지만, 여기서 막히면 앱을 아예 쓸 수 없다.
Future<Widget> homeAfterLogin({
  UserProfileRepository? profileRepository,
}) async {
  try {
    final repository =
        profileRepository ??
        UserProfileRepository(requestTimeout: const Duration(seconds: 3));
    if (await repository.needsOnboarding()) {
      return const ProfileOnboardingScreen();
    }
  } on Object {
    // 의도적으로 무시.
  }
  return const MainShell();
}

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      children: [
        const SizedBox(height: 40),
        Center(
          // 로고 7번 연타 = 개발자 로그인 입구. 방어는 서버 시크릿이 한다.
          child: DeveloperLoginGate(
            onLoggedIn: () => unawaited(_openHome(context)),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'CookPilot',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '내 입맛을 기억하는 요리 파트너',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.slate, fontSize: 15),
        ),
        const SizedBox(height: 28),
        PressableScale(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.kakao,
              foregroundColor: const Color(0xFF191600),
            ),
            onPressed: () => unawaited(_loginWithKakao(context)),
            icon: const Icon(Icons.chat_bubble_rounded),
            label: const Text('카카오로 시작하기'),
          ),
        ),
        const SizedBox(height: 10),
        PressableScale(
          child: OutlinedButton.icon(
            onPressed: () => unawaited(_loginWithGoogle(context)),
            icon: const Icon(Icons.g_mobiledata_rounded),
            label: const Text('Google로 시작하기'),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '따로 가입할 필요 없어요.\n처음 로그인하면 계정이 만들어집니다.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  /// 카카오 로그인 → 서버 세션 토큰 발급 → 홈.
  ///
  /// 카카오에서 받은 액세스 토큰은 서버로 보내 검증받는다(POST /auth/kakao).
  /// 클라이언트가 신원을 주장하는 구조가 아니다.
  Future<void> _loginWithKakao(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final kakaoToken = await const KakaoLogin().obtainAccessToken();
      final session = await AuthApi().loginWithProvider('kakao', kakaoToken);
      await AuthSession.save(session);
      if (!context.mounted) return;
      await _openHome(context);
    } on KakaoLoginCancelled {
      // 사용자가 직접 닫았다. 오류 안내를 띄우지 않는다.
    } on AuthException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// 구글 로그인 → 서버 세션 토큰 발급 → 홈.
  Future<void> _loginWithGoogle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final idToken = await const GoogleLogin().obtainIdToken();
      final session = await AuthApi().loginWithProvider('google', idToken);
      await AuthSession.save(session);
      if (!context.mounted) return;
      await _openHome(context);
    } on GoogleLoginCancelled {
      // 사용자가 직접 닫았다.
    } on AuthException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openHome(BuildContext context) async {
    final next = await homeAfterLogin();
    if (!context.mounted) return;
    unawaited(
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute<void>(builder: (_) => next)),
    );
  }
}
