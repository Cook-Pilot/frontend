import 'dart:async';

import 'package:flutter/material.dart';

import '../data/auth_api.dart';
import '../data/auth_session.dart';

/// 로고를 정해진 횟수만큼 연달아 누르면 개발자 로그인 입구가 열린다.
///
/// 이 숫자는 **보안이 아니다** — 앱을 뜯으면 누구나 알 수 있다. 실제 방어는 서버 시크릿이고,
/// 서버에 시크릿이 설정돼 있지 않으면 로그인 자체가 거부된다.
class DeveloperLoginGate extends StatefulWidget {
  const DeveloperLoginGate({
    super.key,
    required this.child,
    required this.onLoggedIn,
    this.requiredTaps = 7,
    this.authApi,
  });

  final Widget child;
  final VoidCallback onLoggedIn;
  final int requiredTaps;
  final AuthApi? authApi;

  @override
  State<DeveloperLoginGate> createState() => _DeveloperLoginGateState();
}

class _DeveloperLoginGateState extends State<DeveloperLoginGate> {
  /// 연타로 인정하는 간격. 넘으면 처음부터 다시 센다 — 평소 조작으로 우연히 열리지 않게.
  static const _tapWindow = Duration(seconds: 2);

  int _taps = 0;
  DateTime? _lastTapAt;

  void _handleTap() {
    final now = DateTime.now();
    final last = _lastTapAt;
    _taps = (last != null && now.difference(last) > _tapWindow) ? 1 : _taps + 1;
    _lastTapAt = now;

    if (_taps >= widget.requiredTaps) {
      _taps = 0;
      _lastTapAt = null;
      unawaited(_promptForSecret());
    }
  }

  Future<void> _promptForSecret() async {
    final controller = TextEditingController();
    final secret = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('개발자 로그인'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(labelText: '시크릿'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('로그인'),
          ),
        ],
      ),
    );

    if (secret == null || secret.isEmpty) return;
    await _login(secret);
  }

  Future<void> _login(String secret) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = await (widget.authApi ?? AuthApi()).loginAsDeveloper(
        secret,
      );
      await AuthSession.save(token);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${token.displayName}(으)로 로그인했습니다.')),
      );
      widget.onLoggedIn();
    } on AuthException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: widget.child,
    );
  }
}
