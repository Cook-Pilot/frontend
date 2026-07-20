import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design/cookpilot_colors.dart';
import '../../../design/cookpilot_spacing.dart';
import '../application/cooking_session_controller.dart';
import '../application/local_command_router.dart';
import '../domain/cooking_session_state.dart';
import 'widgets/cooking_top_bar.dart';
import 'widgets/current_action_section.dart';
import 'widgets/exception_feedback_banner.dart';
import 'widgets/quick_command_deck.dart';
import 'widgets/session_action_bar.dart';
import 'widgets/step_media.dart';
import 'widgets/timer_instrument.dart';
import 'widgets/voice_status_bar.dart';

typedef CookingScreenCallback = void Function();

final class CookingScreen extends StatefulWidget {
  const CookingScreen({
    required this.controller,
    this.recipeName = '라면',
    this.onComplete,
    this.onAbort,
    this.onOpenAppSettings,
    super.key,
  });

  final CookingSessionController controller;
  final String recipeName;
  final CookingScreenCallback? onComplete;
  final CookingScreenCallback? onAbort;
  final CookingScreenCallback? onOpenAppSettings;

  @override
  State<CookingScreen> createState() => _CookingScreenState();
}

final class _CookingScreenState extends State<CookingScreen>
    with WidgetsBindingObserver {
  bool _exitDialogOpen = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.controller.enterForeground());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.enterForeground());
    } else {
      unawaited(widget.controller.leaveForeground());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.controller.leaveForeground());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final step = widget.controller.currentStep;
        final screenHeight = MediaQuery.sizeOf(context).height;
        final compact = screenHeight < 720;
        final mediaHeight = screenHeight < 600
            ? 104.0
            : compact
            ? 190.0
            : 260.0;
        final timerStatus = widget.controller.timer.status;

        return PopScope<Object?>(
          canPop: _allowPop || widget.controller.isTerminal,
          onPopInvokedWithResult: (didPop, _) {
            unawaited(_handleSystemBack(didPop));
          },
          child: Scaffold(
            body: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: CookPilotSpacing.contentMaxWidth,
                  ),
                  child: CustomScrollView(
                    key: const Key('cooking-scroll-view'),
                    slivers: <Widget>[
                      SliverList(
                        delegate: SliverChildListDelegate(<Widget>[
                          CookingTopBar(
                            recipeName: widget.recipeName,
                            currentStep: state.stepIndex + 1,
                            stepCount: widget.controller.steps.length,
                          ),
                          const Divider(height: 1, thickness: 1),
                          CurrentActionSection(
                            step: step,
                            stepIndex: state.stepIndex,
                            stepCount: widget.controller.steps.length,
                            compact: compact,
                          ),
                          StepMedia(step: step, height: mediaHeight),
                          TimerInstrument(
                            remaining: widget.controller.timer.remaining,
                            progress: widget.controller.timer.progress,
                            status: timerStatus,
                            compact: compact,
                            onToggle: timerStatus == TimerStatus.running
                                ? () => _execute(CookingCommand.pauseTimer)
                                : timerStatus == TimerStatus.paused
                                ? () => _execute(CookingCommand.resumeTimer)
                                : null,
                          ),
                          VoiceStatusBar(
                            phase: state.voicePhase,
                            latestMessage: state.lastCommandMessage,
                            lastRecognizedUtterance:
                                state.lastRecognizedUtterance,
                            onOpenAppSettings: widget.onOpenAppSettings,
                          ),
                          if (state.exceptionFeedback case final String message)
                            ExceptionFeedbackBanner(message: message),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: CookPilotSpacing.contentMaxWidth,
                  ),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: CookPilotColors.neutralSurface,
                      border: Border(
                        top: BorderSide(color: CookPilotColors.neutralLine),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          QuickCommandDeck(
                            onPrevious: widget.controller.canGoPrevious
                                ? () => _execute(CookingCommand.previousStep)
                                : null,
                            onRepeat: () =>
                                _execute(CookingCommand.repeatInstruction),
                            onAddMinute: () =>
                                _execute(CookingCommand.addMinute),
                            onNext: widget.controller.canGoNext
                                ? () => _execute(CookingCommand.nextStep)
                                : null,
                          ),
                          const SizedBox(height: CookPilotSpacing.sm),
                          const Divider(height: 1, thickness: 1),
                          const SizedBox(height: CookPilotSpacing.sm),
                          SessionActionBar(
                            onAbort: _confirmAbort,
                            onComplete: _confirmComplete,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _execute(CookingCommand command) async {
    await widget.controller.execute(command);
  }

  Future<void> _confirmComplete() async {
    final confirmed = await _showConfirmation(
      title: '조리를 완료할까요?',
      body: '완료하면 음성 수신과 타이머를 멈추고 결과 피드백으로 이동해요.',
      confirmLabel: '완료하기',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final result = await widget.controller.execute(
      CookingCommand.completeSession,
    );
    if (result.executed && mounted) {
      widget.onComplete?.call();
    }
  }

  Future<void> _confirmAbort() async {
    final confirmed = await _showConfirmation(
      title: '조리를 중단할까요?',
      body: '현재 세션을 중단하고 음성 수신과 타이머를 종료해요.',
      confirmLabel: '중단하기',
    );
    if (!confirmed || !mounted) {
      return;
    }
    final result = await widget.controller.execute(CookingCommand.abortSession);
    if (result.executed && mounted) {
      widget.onAbort?.call();
    }
  }

  Future<void> _handleSystemBack(bool didPop) async {
    if (didPop || _exitDialogOpen || widget.controller.isTerminal || !mounted) {
      return;
    }
    _exitDialogOpen = true;
    try {
      final confirmed = await _showConfirmation(
        title: '조리를 중단하고 나갈까요?',
        body: '현재 세션을 중단하고 음성 수신과 타이머를 종료해요.',
        confirmLabel: '중단하고 나가기',
      );
      if (!confirmed || !mounted) {
        return;
      }
      final result = await widget.controller.execute(
        CookingCommand.abortSession,
      );
      if (!result.executed || !mounted) {
        return;
      }
      final onAbort = widget.onAbort;
      if (onAbort != null) {
        onAbort();
        return;
      }
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } finally {
      _exitDialogOpen = false;
    }
  }

  Future<bool> _showConfirmation({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 조리'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
