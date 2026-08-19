import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../data/auth_session.dart';

/// 홈 우상단 아바타에서 여는 계정 시트. 지금은 로그아웃만 있다.
///
/// 앱 시작 시 세션을 복원하게 된 뒤로는 이 경로가 없으면 앱을 지우지 않는 한 계정을
/// 바꿀 수 없다. 로그아웃하면 저장된 토큰을 지우고 [firstScreen] 으로 되돌린다.
///
/// 첫 화면을 인자로 받는 이유: 여기서 로그인 화면을 직접 import 하면 auth 와 mvp 가
/// 서로를 참조하게 된다(mvp/auth_screen 은 이미 auth/presentation 을 쓴다).
Future<void> showAccountSheet(
  BuildContext context, {
  required Widget Function() firstScreen,
}) async {
  final signOut = await showModalBottomSheet<bool>(
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
              AuthSession.isLoggedIn ? '로그인됨' : '로그인하지 않음',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('로그아웃'),
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (signOut != true || !context.mounted) return;

  await AuthSession.signOut();
  if (!context.mounted) return;
  await Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => firstScreen()),
    (route) => false,
  );
}
