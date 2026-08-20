import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../data/auth_session.dart';

/// 로그인이 필요한 동작(후기 저장·즐겨찾기 등) 앞에서 부른다.
///
/// 이미 로그인이면 바로 true. 게스트면 이유를 보여주는 시트를 띄우고,
/// 로그인 화면까지 마치면 true 를 돌려준다 — 호출부는 true 일 때만 동작을 잇는다.
///
/// 로그인 화면을 함수로 받는 이유: 여기서 mvp/auth_screen 을 직접 import 하면
/// auth 와 mvp 가 서로를 참조하게 된다(account_sheet 와 같은 패턴).
Future<bool> ensureLoggedIn(
  BuildContext context, {
  required String reason,
  required Widget Function() loginScreen,
}) async {
  if (AuthSession.isLoggedIn) return true;

  final wantsLogin = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.lock_open_rounded,
              color: AppColors.accent,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '로그인하면 내 기록이 계정에 안전하게 남아요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('login-gate-login-button'),
              onPressed: () => Navigator.of(sheetContext).pop(true),
              child: const Text('로그인하기'),
            ),
            TextButton(
              key: const Key('login-gate-later-button'),
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: const Text('다음에 할게요'),
            ),
          ],
        ),
      ),
    ),
  );

  if (wantsLogin != true || !context.mounted) return false;

  final loggedIn = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute<bool>(builder: (_) => loginScreen()));
  return loggedIn == true && AuthSession.isLoggedIn;
}
