import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../auth/data/auth_session.dart';
import '../user/data/profile_onboarding_cache.dart';
import 'auth_screen.dart';
import 'mvp_widgets.dart';
import 'profile_onboarding_screen.dart';

/// 하단 '내 정보' 탭.
///
/// 계정 시트(홈 우상단 아바타)를 화면으로 끌어올린 것이다. 시트는 로그인/로그아웃
/// 하나만 담기에도 빠듯했는데, 프로필 설정이 붙으면서 이미 좁아졌다.
///
/// 게스트여도 쫓아내지 않는다 — 로그인은 저장이 필요한 시점에만 권한다.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.onSessionChanged});

  /// 로그인·로그아웃이 일어나면 셸에 알린다. 홈이 개인화 데이터를 다시 그린다.
  final VoidCallback onSessionChanged;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    final loggedIn = AuthSession.isLoggedIn;
    final name = AuthSession.current?.displayName ?? '게스트';

    return PageShell(
      children: [
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accent, AppColors.accentDeep],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    name.characters.first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                loggedIn ? '로그인됨' : '로그인하면 후기와 즐겨찾기가 저장돼요',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SectionTitle('계정'),
        if (loggedIn)
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('account-profile-tile'),
                  leading: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.accent,
                  ),
                  title: const Text('프로필 설정'),
                  subtitle: const Text(
                    '성별·연령대로 추천을 맞춰드려요',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => unawaited(_openProfile()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('로그아웃'),
                  onTap: () => unawaited(_signOut()),
                ),
              ],
            ),
          )
        else
          Card(
            child: ListTile(
              key: const Key('account-login-tile'),
              leading: const Icon(Icons.login_rounded, color: AppColors.accent),
              title: const Text('로그인'),
              subtitle: const Text(
                '카카오·구글 계정으로 바로 시작해요',
                style: TextStyle(color: AppColors.muted),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => unawaited(_signIn()),
            ),
          ),
      ],
    );
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ProfileOnboardingScreen()),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _signIn() async {
    final loggedIn = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const AuthScreen()));
    if (!mounted || loggedIn != true || !AuthSession.isLoggedIn) return;
    unawaited(ProfileOnboardingCache.refresh());
    setState(() {});
    widget.onSessionChanged();
  }

  Future<void> _signOut() async {
    await AuthSession.signOut();
    ProfileOnboardingCache.clear();
    if (!mounted) return;
    setState(() {});
    widget.onSessionChanged();
  }
}
