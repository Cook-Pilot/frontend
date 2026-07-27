import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/data/providers.dart';
import 'package:cookpilot/features/auth/taste_profile_screen.dart';
import 'package:cookpilot/features/shell/main_shell.dart';
import 'package:cookpilot/shared/widgets/async_value_view.dart';
import 'package:cookpilot/shared/widgets/page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 인증은 백엔드 미확정(docs/08). 어떤 버튼으로 들어와도 서버의 고정 목유저를 쓴다.
/// GET /api/v1/users/me 로 백엔드 연결 상태를 먼저 확인시킨다.
class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return PageShell(
      children: [
        const SizedBox(height: 36),
        Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 34,
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
        const SizedBox(height: 20),
        user.when(
          data: (data) => InfoStrip(
            icon: Icons.cloud_done_rounded,
            title: '${data.displayName}(으)로 시작합니다',
            body: '인증 미확정 · 서버 고정 계정 ${data.email}',
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ApiErrorView(
            error: error,
            onRetry: () => ref.invalidate(currentUserProvider),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.ink,
          ),
          onPressed: () => _openHome(context),
          icon: const Icon(Icons.chat_bubble_rounded),
          label: const Text('카카오로 시작하기'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openHome(context),
          icon: const Icon(Icons.g_mobiledata_rounded),
          label: const Text('Google로 시작하기'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '또는 이메일로',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        const TextField(decoration: InputDecoration(labelText: '이메일')),
        const SizedBox(height: 10),
        const TextField(
          obscureText: true,
          decoration: InputDecoration(labelText: '비밀번호'),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => _openHome(context),
          child: const Text('로그인'),
        ),
        TextButton(
          onPressed: () => _openHome(context),
          child: const Text('게스트로 둘러보기'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const TasteProfileScreen()),
          ),
          child: const Text('계정이 없나요? 회원가입'),
        ),
      ],
    );
  }

  void _openHome(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
    );
  }
}
