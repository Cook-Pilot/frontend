import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../data/auth_session.dart';

/// 홈 우상단 아바타에서 여는 계정 시트.
///
/// 게스트면 '로그인' 을, 로그인 상태면 '로그아웃' 을 보여준다.
/// 로그아웃해도 앱은 게스트 홈으로 돌아갈 뿐 쫓겨나지 않는다.
///
/// 화면들을 함수로 받는 이유: 여기서 mvp 화면을 직접 import 하면 auth 와 mvp 가
/// 서로를 참조하게 된다(mvp/auth_screen 은 이미 auth/presentation 을 쓴다).
Future<void> showAccountSheet(
  BuildContext context, {
  required Widget Function() firstScreen,
  required Widget Function() loginScreen,
}) async {
  final loggedIn = AuthSession.isLoggedIn;
  final action = await showModalBottomSheet<_AccountAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person_rounded, color: AppColors.accent),
            title: Text(AuthSession.current?.displayName ?? '게스트'),
            subtitle: Text(
              loggedIn ? '로그인됨' : '로그인하면 후기와 즐겨찾기가 저장돼요',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          const Divider(height: 1),
          if (loggedIn)
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('로그아웃'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AccountAction.signOut),
            )
          else
            ListTile(
              key: const Key('account-sheet-login-tile'),
              leading: const Icon(Icons.login_rounded, color: AppColors.accent),
              title: const Text('로그인'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AccountAction.signIn),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return;

  switch (action) {
    case _AccountAction.signIn:
      // 로그인 화면은 홈 위에 얹힌다. 성공하면 pop 으로 돌아오고,
      // 호출부(main_shell)가 시트 종료 후 홈을 새로고침한다.
      await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute<bool>(builder: (_) => loginScreen()));
    case _AccountAction.signOut:
      await AuthSession.signOut();
      if (!context.mounted) return;
      // 게스트 홈으로 스택을 재구성한다 — 개인화된 화면 상태를 남기지 않는다.
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => firstScreen()),
        (route) => false,
      );
  }
}

enum _AccountAction { signIn, signOut }
