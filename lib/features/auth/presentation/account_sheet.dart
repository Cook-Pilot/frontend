import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../user/data/account_deletion_repository.dart';
import '../data/auth_session.dart';

enum _AccountAction { signOut, deleteAccount }

/// 홈 우상단 아바타에서 여는 계정 시트. 로그아웃과 회원 탈퇴가 있다.
///
/// 앱 시작 시 세션을 복원하게 된 뒤로는 이 경로가 없으면 앱을 지우지 않는 한 계정을
/// 바꿀 수 없다. 로그아웃하면 저장된 토큰을 지우고 [firstScreen] 으로 되돌린다.
///
/// 탈퇴는 스토어 요건(Play 계정 삭제, Apple 5.1.1(v))이자 방침 제9조의 약속이다.
/// 재확인 다이얼로그 → 서버 삭제 → 로컬 정리 → [firstScreen] 순서이며, 서버 삭제가
/// 실패하면 로컬은 건드리지 않는다 — 세션이 남아 있어야 재시도할 수 있다.
///
/// 첫 화면을 인자로 받는 이유: 여기서 로그인 화면을 직접 import 하면 auth 와 mvp 가
/// 서로를 참조하게 된다(mvp/auth_screen 은 이미 auth/presentation 을 쓴다).
Future<void> showAccountSheet(
  BuildContext context, {
  required Widget Function() firstScreen,
  AccountDeletionRepository? deletionRepository, // 테스트 주입용
  LocalAccountDataWiper? dataWiper, // 테스트 주입용
}) async {
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
              AuthSession.isLoggedIn ? '로그인됨' : '로그인하지 않음',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('로그아웃'),
            onTap: () => Navigator.of(sheetContext).pop(_AccountAction.signOut),
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_rounded,
              color: Theme.of(sheetContext).colorScheme.error,
            ),
            title: Text(
              '회원 탈퇴',
              style: TextStyle(color: Theme.of(sheetContext).colorScheme.error),
            ),
            onTap: () =>
                Navigator.of(sheetContext).pop(_AccountAction.deleteAccount),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return;

  switch (action) {
    case _AccountAction.signOut:
      await AuthSession.signOut();
      if (!context.mounted) return;
      await _restart(context, firstScreen);
    case _AccountAction.deleteAccount:
      await _confirmAndDeleteAccount(
        context,
        firstScreen: firstScreen,
        repository: deletionRepository ?? AccountDeletionRepository(),
        wiper: dataWiper ?? LocalAccountDataWiper(),
      );
  }
}

Future<void> _confirmAndDeleteAccount(
  BuildContext context, {
  required Widget Function() firstScreen,
  required AccountDeletionRepository repository,
  required LocalAccountDataWiper wiper,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('정말 탈퇴할까요?'),
      content: const Text(
        '조리 후기와 사진, 나만의 레시피, 즐겨찾기가 모두 삭제되며 '
        '되돌릴 수 없습니다.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            '탈퇴',
            style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // 서버 삭제(S3 사진 정리 포함)를 기다리는 동안 이중 탭을 막는다.
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ),
  );
  try {
    await repository.deleteAccount();
  } on Object {
    if (!context.mounted) return;
    Navigator.of(context).pop(); // 진행 다이얼로그
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('계정 삭제에 실패했습니다. 잠시 후 다시 시도해 주세요.')),
    );
    return;
  }

  // 서버가 지웠으면 로컬 정리 결과와 무관하게 탈퇴는 완료다(wipe 는 내부적으로 best-effort).
  await wiper.wipe();
  if (!context.mounted) return;
  Navigator.of(context).pop(); // 진행 다이얼로그
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('탈퇴가 완료되었습니다.')));
  await _restart(context, firstScreen);
}

Future<void> _restart(BuildContext context, Widget Function() firstScreen) {
  return Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => firstScreen()),
    (route) => false,
  );
}
