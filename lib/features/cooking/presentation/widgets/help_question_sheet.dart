import 'package:flutter/material.dart';

import '../../../../design/cookpilot_spacing.dart';

/// 음성 폴백용 질문 입력 시트. 제출한 질문 문자열을 반환하고,
/// 입력 없이 닫으면 null을 반환한다.
final class HelpQuestionSheet extends StatefulWidget {
  const HelpQuestionSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const HelpQuestionSheet(),
    );
  }

  @override
  State<HelpQuestionSheet> createState() => _HelpQuestionSheetState();
}

final class _HelpQuestionSheetState extends State<HelpQuestionSheet> {
  final TextEditingController _question = TextEditingController();

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  void _submit() {
    final question = _question.text.trim();
    if (question.isEmpty) {
      return;
    }
    Navigator.of(context).pop(question);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        CookPilotSpacing.lg,
        CookPilotSpacing.lg,
        CookPilotSpacing.lg,
        CookPilotSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('무엇이 문제인가요?', style: theme.textTheme.titleMedium),
          const SizedBox(height: CookPilotSpacing.xs),
          Text(
            '현재 단계에 맞춰 대처 방법을 알려드려요.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: CookPilotSpacing.md),
          TextField(
            key: const Key('help-question-field'),
            controller: _question,
            autofocus: true,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              hintText: '예: 물이 안 끓어요',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: CookPilotSpacing.md),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _question,
            builder: (context, value, _) => FilledButton(
              key: const Key('help-question-submit'),
              onPressed: value.text.trim().isEmpty ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(
                  CookPilotSpacing.sessionActionHeight,
                ),
              ),
              child: const Text('질문하기'),
            ),
          ),
        ],
      ),
    );
  }
}
