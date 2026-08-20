import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../user/data/profile_onboarding_cache.dart';
import '../user/data/user_profile_repository.dart';
import 'main_shell.dart';
import 'mvp_widgets.dart';

const _genderOptions = [('M', '남성'), ('F', '여성'), ('N', '선택 안 함')];

const _ageGroupOptions = [
  (10, '10대'),
  (20, '20대'),
  (30, '30대'),
  (40, '40대'),
  (50, '50대'),
  (60, '60세 이상'),
];

/// 성별·연령대 프로필 화면. 마이(아바타)에서 들어온다 —
/// 아직 안 물어봤으면(profileAskedAt == null) 마이 진입 시 바로 뜨고,
/// 그 뒤로는 계정 시트의 '프로필 설정'으로 다시 들어온다.
/// 입력하든 건너뛰든 PATCH /users/me로 서버에 "물어봤음"을 기록한다.
class ProfileOnboardingScreen extends StatefulWidget {
  const ProfileOnboardingScreen({super.key, this.repository});

  final UserProfileRepository? repository;

  @override
  State<ProfileOnboardingScreen> createState() =>
      _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState extends State<ProfileOnboardingScreen> {
  late final UserProfileRepository _repository =
      widget.repository ?? UserProfileRepository();

  String? _gender;
  int? _ageGroup;

  void _goHome() {
    unawaited(
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MainShell()),
        (route) => false,
      ),
    );
  }

  /// 건너뛰기: 화면은 바로 넘기고 뒤에서 조용히 빈 body PATCH.
  /// 실패는 무시한다 — 다음 로그인에서 온보딩이 다시 뜰 뿐이다.
  void _skip() {
    ProfileOnboardingCache.markAsked();
    _goHome();
    unawaited(_repository.updateProfile().catchError((Object _) {}));
  }

  Future<void> _submit() async {
    try {
      await _repository.updateProfile(gender: _gender, ageGroup: _ageGroup);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('프로필 저장에 실패했습니다: $error')));
      return;
    }
    if (!mounted) return;
    ProfileOnboardingCache.markAsked();
    _goHome();
  }

  Wrap _chips<T>(
    List<(T, String)> options,
    T? selected,
    ValueChanged<T?> onChanged,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: selected == value,
            onSelected: (on) => setState(() => onChanged(on ? value : null)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: '프로필 입력',
      actions: [TextButton(onPressed: _skip, child: const Text('건너뛰기'))],
      children: [
        const Text(
          '맞춤 추천을 위해 사용돼요 (선택)',
          style: TextStyle(color: AppColors.slate),
        ),
        const SectionTitle('성별'),
        _chips(_genderOptions, _gender, (value) => _gender = value),
        const SectionTitle('연령대'),
        _chips(_ageGroupOptions, _ageGroup, (value) => _ageGroup = value),
      ],
      bottom: PressableScale(
        child: FilledButton(
          onPressed: _gender != null || _ageGroup != null
              ? () => unawaited(_submit())
              : null,
          child: const Text('확인'),
        ),
      ),
    );
  }
}
