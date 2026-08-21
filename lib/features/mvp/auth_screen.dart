import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../auth/data/auth_api.dart';
import '../auth/data/auth_session.dart';
import '../auth/data/google_login.dart';
import '../auth/data/kakao_login.dart';
import '../auth/presentation/developer_login.dart';
import '../user/data/profile_onboarding_cache.dart';
import 'main_shell.dart';
import 'mvp_widgets.dart';

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
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      children: [
        // 홈이 항상 아래에 있으므로 이 화면은 언제나 '위에 얹힌' 화면이다.
        // 닫으면 게스트인 채 하던 일로 돌아간다.
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            key: const Key('auth-close-button'),
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded, color: AppColors.slate),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          // 로고 7번 연타 = 개발자 로그인 입구. 방어는 서버 시크릿이 한다.
          child: DeveloperLoginGate(
            onLoggedIn: () => unawaited(_openHome(context)),
            // 워드마크는 글자 모양 자체가 브랜드라 텍스트로 흉내 내지 않고 이미지를 쓴다.
            child: Image.asset(
              'assets/logo/cooklog-wordmark.png',
              height: 52,
              fit: BoxFit.contain,
            ),
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
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            key: const Key('auth-browse-as-guest-button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              '로그인 없이 둘러보기',
              style: TextStyle(color: AppColors.slate),
            ),
          ),
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

  /// 로그인 성공 뒤에는 항상 로그인을 요구했던 화면(후기 저장·마이 등)으로
  /// 그대로 복귀한다. 프로필(성별·연령대) 입력은 로그인 흐름에 끼우지 않는다 —
  /// 우상단 사람 버튼(마이)에서 한다. 하던 일을 끊지 않기 위해서다.
  Future<void> _openHome(BuildContext context) async {
    // 마이 진입 시 온보딩 여부를 캐시로 즉답할 수 있게 뒤에서 채워 둔다.
    unawaited(ProfileOnboardingCache.refresh());
    Navigator.of(context).pop(true);
  }
}

/// 입맛·맵기 선택 화면. **아직 진입점이 없다.**
///
/// 예전 '회원가입' 목업 버튼으로 들어가던 화면인데, 익명 발급을 걷어내면서 그 버튼이
/// 사라졌다. 백엔드에 입맛 컬럼도 API 도 없어 지금은 고른 값을 저장할 곳이 없다 —
/// 온보딩에 입맛 단계를 붙일 때 여기서 이어간다(#58).
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
          // TODO(#58): 고른 값을 PATCH /users/me 로 저장한다. 지금은 화면만 넘어간다.
          onPressed: selected.length >= 3
              ? () {
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
