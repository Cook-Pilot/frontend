import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/features/shell/main_shell.dart';
import 'package:cookpilot/shared/widgets/page_shell.dart';
import 'package:flutter/material.dart';

/// 입맛 프로필(F-05)은 아직 백엔드 API가 없다. 선택값은 화면 안에만 남는다.
/// TODO(backend): POST /users/me/taste-profile 이 생기면 여기서 저장한다.
class TasteProfileScreen extends StatefulWidget {
  const TasteProfileScreen({super.key});

  @override
  State<TasteProfileScreen> createState() => _TasteProfileScreenState();
}

class _TasteProfileScreenState extends State<TasteProfileScreen> {
  static const tasteOptions = [
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

  static const spiceLevels = [
    ('진라면 순한맛도 부담돼요', '맵기 1'),
    ('신라면 정도가 딱 좋아요', '맵기 2~3'),
    ('불닭볶음면도 문제없어요', '맵기 4'),
    ('핵불닭도 갑니다', '맵기 5'),
  ];

  final Set<String> selected = {};
  int spiceLevel = 1;

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
          '입맛 프로필 저장 API는 아직 준비 중이에요. 지금은 화면에만 반영됩니다.',
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
            for (final option in tasteOptions)
              _TasteOption(
                label: option,
                selected: selected.contains(option),
                onTap: () => setState(() {
                  if (!selected.remove(option)) selected.add(option);
                }),
              ),
          ],
        ),
        const SectionTitle('매운맛, 어디까지 되세요?'),
        for (var i = 0; i < spiceLevels.length; i++)
          Card(
            child: ListTile(
              onTap: () => setState(() => spiceLevel = i),
              leading: Icon(
                spiceLevel == i
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: AppColors.ink,
              ),
              title: Text(spiceLevels[i].$1),
              subtitle: Text(spiceLevels[i].$2),
              dense: true,
            ),
          ),
      ],
      bottom: FilledButton(
        onPressed: selected.length >= 3
            ? () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const MainShell()),
                (route) => false,
              )
            : null,
        child: Text('다음 · ${selected.length}개 선택됨'),
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
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
            if (selected)
              const Positioned(
                right: 8,
                top: 8,
                child: Icon(Icons.check_circle, color: AppColors.ink, size: 18),
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
    );
  }
}
