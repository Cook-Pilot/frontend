import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/core/network/api_exception.dart';
import 'package:cookpilot/data/models/ai_feedback.dart';
import 'package:cookpilot/data/models/cook_session.dart';
import 'package:cookpilot/features/cook/cook_session_controller.dart';
import 'package:cookpilot/features/review/review_screen.dart';
import 'package:cookpilot/shared/widgets/async_value_view.dart';
import 'package:cookpilot/shared/widgets/food_widgets.dart';
import 'package:cookpilot/shared/widgets/page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 조리 진행: POST /step, /events, /ai-feedback, /complete, /abort
class CookSessionScreen extends ConsumerWidget {
  const CookSessionScreen({
    super.key,
    required this.session,
    required this.servings,
  });

  final CookSession session;
  final int servings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = cookSessionControllerProvider(session);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final step = state.session.currentStep;
    final stepNumber = state.session.currentStepIndex + 1;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => _confirmAbort(context, controller),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          '${state.session.recipeTitle} · $servings인분',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Pill(state.session.status.label, selected: true),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Text(
                  '$stepNumber / ${state.session.totalSteps} 단계',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const Expanded(
                  child: Text(
                    '서버에 자동 기록됨',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.slate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: stepNumber / state.session.totalSteps,
            ),
            const SizedBox(height: 18),
            const FoodPreview(size: double.infinity),
            const SizedBox(height: 18),
            Text(
              step?.instruction ?? '단계 정보를 불러오지 못했어요.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (step?.cautionNote != null) ...[
              const SizedBox(height: 12),
              InfoStrip(
                icon: Icons.warning_amber_rounded,
                title: '주의',
                body: step!.cautionNote!,
              ),
            ],
            const SizedBox(height: 18),
            _TimerPanel(state: state, onToggle: controller.toggleTimer),
            const SizedBox(height: 14),
            if (state.feedback != null)
              _FeedbackCard(
                feedback: state.feedback!,
                onExtendTimer: controller.extendTimer,
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: state.busy
                  ? null
                  : () => _askAi(context, controller),
              icon: const Icon(Icons.mic_rounded),
              label: const Text('AI에게 물어보기'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Row(
          children: [
            if (!state.session.isFirstStep) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: state.busy
                      ? null
                      : () => _move(context, controller, next: false),
                  child: const Text('이전 단계'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: state.busy
                    ? null
                    : state.session.isLastStep
                    ? () => _complete(context, controller)
                    : () => _move(context, controller, next: true),
                child: Text(state.session.isLastStep ? '조리 완료' : '다음 단계'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _move(
    BuildContext context,
    CookSessionController controller, {
    required bool next,
  }) async {
    try {
      await controller.moveStep(next: next);
    } on ApiException catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }

  Future<void> _complete(
    BuildContext context,
    CookSessionController controller,
  ) async {
    try {
      final completed = await controller.complete();
      if (!context.mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              ReviewScreen(session: completed, servings: servings),
        ),
      );
    } on ApiException catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }

  Future<void> _confirmAbort(
    BuildContext context,
    CookSessionController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('조리를 중단할까요?'),
        content: const Text('중단 상태가 서버에 기록되고, 이 세션은 다시 이어서 할 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 조리'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('중단'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await controller.abort();
    } on ApiException catch (e) {
      if (context.mounted) showApiError(context, e);
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _askAi(
    BuildContext context,
    CookSessionController controller,
  ) async {
    final speech = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AiPromptSheet(),
    );
    if (speech == null || speech.isEmpty) return;

    try {
      await controller.askAi(speech);
    } on ApiException catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }
}

class _TimerPanel extends StatelessWidget {
  const _TimerPanel({required this.state, required this.onToggle});

  final CookSessionState state;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      _ when !state.hasTimer => '타이머 없는 단계',
      _ when state.timerFinished => '타이머 완료',
      _ when state.timerRunning => '일시정지',
      _ => '타이머 시작',
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text('남은 시간', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            state.timerLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: state.hasTimer && !state.timerFinished ? onToggle : null,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.feedback, required this.onExtendTimer});

  final AiFeedback feedback;
  final void Function(int seconds) onExtendTimer;

  @override
  Widget build(BuildContext context) {
    final action = feedback.suggestedAction;

    return Card(
      color: const Color(0xFFF1F5F9),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.ink),
                const SizedBox(width: 8),
                const Text(
                  'AI 피드백',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                if (feedback.mock) const Pill('목데이터'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              feedback.screenText,
              style: const TextStyle(color: AppColors.ink),
            ),
            if (action != null && action.extendsTimer) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => onExtendTimer(action.seconds!),
                child: Text('타이머 ${action.seconds}초 연장'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// STT 미확정 — 지금은 텍스트로 질문을 받아 /ai-feedback 에 보낸다.
class _AiPromptSheet extends StatefulWidget {
  const _AiPromptSheet();

  @override
  State<_AiPromptSheet> createState() => _AiPromptSheetState();
}

class _AiPromptSheetState extends State<_AiPromptSheet> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '무엇이 궁금한가요?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'STT는 아직 붙지 않았어요. 텍스트로 물어보면 서버(목데이터)가 답합니다.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '예: 아직 안 끓는데 얼마나 더 기다려요?',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in const [
                '아직 안 익었어요',
                '재료가 없어요',
                '다시 말해줘요',
                '너무 짜요',
              ])
                Pill(preset, onTap: () => Navigator.of(context).pop(preset)),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('물어보기'),
          ),
        ],
      ),
    );
  }
}
