import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../auth/data/auth_api.dart';
import '../auth/data/auth_session.dart';
import '../auth/data/google_login.dart';
import '../auth/data/kakao_login.dart';
import '../auth/presentation/developer_login.dart';
import '../user/data/beta_user_repository.dart';
import '../user/data/user_profile_repository.dart';
import 'main_shell.dart';
import 'mvp_widgets.dart';
import 'profile_onboarding_screen.dart';

const _tasteOptions = [
  '마라탕',
  '김치찌개',
  '파스타',
  '초밥',
  '떡볶이',
  '삼겹살',
  '샐러드',
  '카레',
  '치킨',
  '냉면',
  '크림리조또',
  '제육볶음',
];

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key, this.profileRepository});

  /// 테스트에서 프로필 조회를 갈아끼우기 위한 통로. 실제 앱에서는 null.
  final UserProfileRepository? profileRepository;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      children: [
        const SizedBox(height: 40),
        Center(
          // 로고 7번 연타 = 개발자 로그인 입구. 방어는 서버 시크릿이 한다.
          child: DeveloperLoginGate(
            onLoggedIn: () => _openHomeDirectly(context),
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
        PressableScale(
          child: FilledButton(
            onPressed: () => _openHome(context),
            child: const Text('로그인'),
          ),
        ),
        TextButton(
          onPressed: () => _openHome(context),
          child: const Text('게스트로 둘러보기'),
        ),
        TextButton(
          onPressed: () {
            unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TasteProfileScreen(),
                ),
              ),
            );
          },
          child: const Text('계정이 없나요? 회원가입'),
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
      _openHomeDirectly(context);
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
      _openHomeDirectly(context);
    } on GoogleLoginCancelled {
      // 사용자가 직접 닫았다.
    } on AuthException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// 이미 로그인된 상태에서 홈으로. 익명 발급을 타지 않는다.
  void _openHomeDirectly(BuildContext context) {
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const MainShell()),
      ),
    );
  }

  Future<void> _openHome(BuildContext context) async {
    try {
      await BetaUserRepository().ensureUser();
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('사용자 준비에 실패했습니다: $error')));
      return;
    }

    // 프로필 확인 실패나 지연이 홈 진입을 막지 않도록 짧은 타임아웃을 쓴다.
    // 온보딩은 다음 로그인에서 다시 시도하면 된다.
    var needsOnboarding = false;
    try {
      final repository =
          profileRepository ??
          UserProfileRepository(requestTimeout: const Duration(seconds: 3));
      needsOnboarding = await repository.needsOnboarding();
    } on Object {
      // 의도적으로 무시.
    }

    if (!context.mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => needsOnboarding
              ? const ProfileOnboardingScreen()
              : const MainShell(),
        ),
      ),
    );
  }
}

class TasteProfileScreen extends StatefulWidget {
  const TasteProfileScreen({super.key});

  @override
  State<TasteProfileScreen> createState() => _TasteProfileScreenState();
}

class _TasteProfileScreenState extends State<TasteProfileScreen> {
  final Set<String> selected = {'마라탕', '김치찌개', '치킨'};

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: '내 입맛 설정',
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      children: [
        Text(
          '끌리는 음식을 3개 이상 골라주세요',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '고른 음식으로 입맛 프로필을 만들어요.',
          style: TextStyle(color: AppColors.slate),
        ),
        const SizedBox(height: 22),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final option in _tasteOptions)
              _TasteOption(
                label: option,
                selected: selected.contains(option),
                onTap: () {
                  setState(() {
                    if (selected.contains(option)) {
                      selected.remove(option);
                    } else {
                      selected.add(option);
                    }
                  });
                },
              ),
          ],
        ),
        const SectionTitle('매운맛, 어디까지 되세요?'),
        ...['진라면 순한맛도 부담돼요', '신라면 정도가 딱 좋아요', '불닭볶음면도 문제없어요', '핵불닭도 갑니다'].map(
          (label) => Card(
            child: ListTile(
              leading: Icon(
                label.startsWith('신라면')
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: label.startsWith('신라면')
                    ? AppColors.accent
                    : AppColors.muted,
              ),
              title: Text(label),
              subtitle: Text(label.startsWith('신라면') ? '맵기 2~3' : '맵기 선택'),
              dense: true,
            ),
          ),
        ),
      ],
      bottom: PressableScale(
        child: FilledButton(
          onPressed: selected.length >= 3
              ? () async {
                  try {
                    await BetaUserRepository().ensureUser();
                    if (!context.mounted) return;
                  } on Object catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('사용자 준비에 실패했습니다: $error')),
                    );
                    return;
                  }
                  unawaited(
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const MainShell(),
                      ),
                      (route) => false,
                    ),
                  );
                }
              : null,
          child: Text('다음 · ${selected.length}개 선택됨'),
        ),
      ),
    );
  }
}

class _TasteOption extends StatelessWidget {
  const _TasteOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShape.inner),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.short,
          curve: AppMotion.easeInOut,
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : AppColors.card,
            borderRadius: BorderRadius.circular(AppShape.inner),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.wash,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      color: Color(0xFFC08A5A),
                      size: 26,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: AnimatedScale(
                  scale: selected ? 1 : 0.6,
                  duration: AppMotion.fast,
                  curve: AppMotion.easeOut,
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: AppMotion.fast,
                    curve: AppMotion.easeOut,
                    child: const Icon(
                      Icons.check_circle,
                      color: AppColors.accent,
                      size: 18,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
