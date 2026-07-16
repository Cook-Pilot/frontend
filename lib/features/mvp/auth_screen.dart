import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import 'main_shell.dart';
import 'mock_data.dart';
import 'mvp_widgets.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      children: [
        const SizedBox(height: 40),
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
        const SizedBox(height: 28),
        PressableScale(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.ink,
            ),
            onPressed: () => _openHome(context),
            icon: const Icon(Icons.chat_bubble_rounded),
            label: const Text('카카오로 시작하기'),
          ),
        ),
        const SizedBox(height: 10),
        PressableScale(
          child: OutlinedButton.icon(
            onPressed: () => _openHome(context),
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
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TasteProfileScreen(),
              ),
            );
          },
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
            for (final (i, option) in tasteOptions.indexed)
              FadeSlideIn(
                delay: Duration(milliseconds: 30 * i),
                child: _TasteOption(
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
                color: AppColors.ink,
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
              ? () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(builder: (_) => const MainShell()),
                    (route) => false,
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
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.short,
          curve: AppMotion.easeInOut,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.line,
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
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      color: AppColors.slate,
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
                      color: AppColors.ink,
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
