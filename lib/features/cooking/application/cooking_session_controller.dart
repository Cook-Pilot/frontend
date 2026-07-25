// Public constructor names intentionally map to private immutable fields.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../domain/cooking_event.dart';
import '../domain/cooking_session_state.dart';
import '../domain/cooking_step.dart';
import 'cooking_ports.dart';
import 'local_command_router.dart';
import 'timer_controller.dart';

@immutable
final class CommandResult {
  const CommandResult({required this.executed, required this.message});

  final bool executed;
  final String message;
}

enum _SpeechPlaybackOutcome { spoken, outputFailed, unsafe, stale, timedOut }

final class CookingSessionController extends ChangeNotifier {
  CookingSessionController({
    required String recipeId,
    required String recipeVersionId,
    required List<CookingStep> steps,
    required LocalTimerController timer,
    required SpeechInputPort speechInput,
    required SpeechOutputPort speechOutput,
    required ExceptionAdvicePort exceptionAdvice,
    TimerAlarmPort alarm = const SilentTimerAlarm(),
    LocalCommandRouter commandRouter = const LocalCommandRouter(),
    DateTime Function()? wallClock,
    Duration Function()? commandClock,
    Duration voiceStopTimeout = const Duration(seconds: 2),
    Duration voicePlaybackTimeout = const Duration(seconds: 45),
    String? sessionId,
  }) : assert(steps.isNotEmpty),
       assert(voiceStopTimeout > Duration.zero),
       assert(voicePlaybackTimeout > Duration.zero),
       _recipeId = recipeId,
       _recipeVersionId = recipeVersionId,
       _steps = List<CookingStep>.unmodifiable(steps),
       _timer = timer,
       _speechInput = speechInput,
       _speechOutput = speechOutput,
       _exceptionAdvice = exceptionAdvice,
       _alarm = alarm,
       _commandRouter = commandRouter,
       _voiceStopTimeout = voiceStopTimeout,
       _voicePlaybackTimeout = voicePlaybackTimeout,
       _wallClock = wallClock ?? DateTime.now,
       _commandClock = commandClock ?? _readProcessMonotonicTime {
    _state = CookingUiState(
      sessionId:
          sessionId ??
          'local-${_wallClock().microsecondsSinceEpoch.toString()}',
      stepIndex: 0,
      sessionStatus: CookingSessionStatus.cooking,
      voicePhase: VoicePhase.listening,
      requestContextVersion: 0,
      lastCommandMessage: '조리를 시작했어요.',
    );
    _timer.addListener(_handleTimerChanged);
    _record(
      source: CommandSource.system,
      command: 'session_started',
      result: 'success',
    );
    _activateStep(0);
  }

  final String _recipeId;
  final String _recipeVersionId;
  final List<CookingStep> _steps;
  final LocalTimerController _timer;
  final SpeechInputPort _speechInput;
  final SpeechOutputPort _speechOutput;
  final ExceptionAdvicePort _exceptionAdvice;
  final TimerAlarmPort _alarm;
  final LocalCommandRouter _commandRouter;
  final Duration _voiceStopTimeout;
  final Duration _voicePlaybackTimeout;
  final DateTime Function() _wallClock;
  final Duration Function() _commandClock;
  final Map<int, StepTimerSnapshot> _timerSnapshots =
      <int, StepTimerSnapshot>{};
  final List<CookingEvent> _events = <CookingEvent>[];

  late CookingUiState _state;
  TimerStatus? _lastObservedTimerStatus;
  CookingCommand? _lastCommand;
  Duration? _lastCommandAt;
  final LinkedHashSet<String> _seenUtteranceIds = LinkedHashSet<String>();
  int _eventSequence = 0;
  int _voiceOperationVersion = 0;
  int _exceptionRequestVersion = 0;
  int _speechLifecycleVersion = 0;
  int _speechOutputActivityVersion = 0;
  Future<void> _speechInputTransition = Future<void>.value();
  Future<void> _speechOutputStopTransition = Future<void>.value();
  bool _speechInputDesired = false;
  bool _speechInputReady = false;
  bool _speechInputRestartBlocked = false;
  bool _speechOutputUnsafe = false;
  int _speechInputStopVersion = 0;
  int _speechOutputStopVersion = 0;
  int _foregroundRequestVersion = 0;
  Future<void>? _foregroundEntry;
  Future<void>? _activeSpeechPlayback;
  Future<_SpeechPlaybackOutcome>? _activeTimerElapsedPlayback;
  bool _isForeground = false;
  bool _hasAnnouncedInitialStep = false;
  VoicePhase? _speechRecoveryPhase;
  bool _timerElapsedAnnouncementPending = false;
  bool _isActivatingStep = false;
  bool _disposed = false;

  static final Stopwatch _processMonotonicClock = Stopwatch()..start();

  static Duration _readProcessMonotonicTime() => _processMonotonicClock.elapsed;

  CookingUiState get state => _state;
  List<CookingStep> get steps => _steps;
  CookingStep get currentStep => _steps[_state.stepIndex];
  LocalTimerController get timer => _timer;
  UnmodifiableListView<CookingEvent> get events =>
      UnmodifiableListView<CookingEvent>(_events);
  bool get canGoPrevious => _state.stepIndex > 0;
  bool get canGoNext => _state.stepIndex < _steps.length - 1;
  bool get isTerminal =>
      _state.sessionStatus == CookingSessionStatus.review ||
      _state.sessionStatus == CookingSessionStatus.completed ||
      _state.sessionStatus == CookingSessionStatus.aborted;

  Future<CommandResult> execute(
    CookingCommand command, {
    CommandSource source = CommandSource.button,
  }) async {
    if (_disposed) {
      return const CommandResult(executed: false, message: '이미 닫힌 조리 세션이에요.');
    }
    if (isTerminal) {
      _record(
        source: source,
        command: 'command_ignored',
        result: 'terminal:${command.eventName}',
      );
      return const CommandResult(executed: false, message: '이미 종료된 조리 세션이에요.');
    }
    if (_isDuplicate(command)) {
      _record(
        source: source,
        command: 'command_deduplicated',
        result: command.eventName,
      );
      return const CommandResult(
        executed: false,
        message: '같은 조작이 연속으로 들어와 한 번만 실행했어요.',
      );
    }
    if (source != CommandSource.voice &&
        _state.lastRecognizedUtterance != null) {
      _state = _state.copyWith(lastRecognizedUtterance: null);
    }

    switch (command) {
      case CookingCommand.previousStep:
        return _moveStep(-1, source);
      case CookingCommand.nextStep:
        return _moveStep(1, source);
      case CookingCommand.repeatInstruction:
        return _repeatInstruction(source);
      case CookingCommand.announceCurrentStep:
        return _announceCurrentStep(source);
      case CookingCommand.addMinute:
        return _addMinute(source);
      case CookingCommand.pauseTimer:
        return _pauseTimer(source);
      case CookingCommand.resumeTimer:
        return _resumeTimer(source);
      case CookingCommand.completeSession:
        return _completeSession(source);
      case CookingCommand.abortSession:
        return _abortSession(source);
      case CookingCommand.unknown:
        _record(
          source: source,
          command: 'unknown_command',
          result: 'not_local',
        );
        return const CommandResult(
          executed: false,
          message: '로컬에서 처리할 수 없는 명령이에요.',
        );
    }
  }

  Future<CommandResult> handleUtterance(
    String utterance, {
    String? utteranceId,
  }) async {
    if (_disposed ||
        isTerminal ||
        _state.voicePhase == VoicePhase.off ||
        _state.voicePhase == VoicePhase.permissionDenied ||
        _state.voicePhase == VoicePhase.starting ||
        _state.voicePhase == VoicePhase.speaking) {
      return const CommandResult(
        executed: false,
        message: '현재 화면에서는 음성 입력을 처리하지 않아요.',
      );
    }
    if (utteranceId != null && !_rememberUtteranceId(utteranceId)) {
      return const CommandResult(executed: false, message: '이미 처리한 음성 입력이에요.');
    }
    final voiceOperationVersion = ++_voiceOperationVersion;
    _state = _state.copyWith(
      voicePhase: VoicePhase.recognizing,
      lastRecognizedUtterance: utterance,
      lastCommandMessage: '“$utterance”로 들었어요.',
    );
    notifyListeners();

    final command = _commandRouter.route(utterance);
    _record(
      source: CommandSource.voice,
      command: 'voice_utterance_received',
      result: command.eventName,
    );
    if (command != CookingCommand.unknown) {
      final result = await execute(command, source: CommandSource.voice);
      if (!_disposed &&
          _voiceOperationVersion == voiceOperationVersion &&
          !isTerminal &&
          _state.voicePhase != VoicePhase.failed &&
          _state.voicePhase != VoicePhase.off &&
          _state.voicePhase != VoicePhase.permissionDenied) {
        _state = _state.copyWith(voicePhase: VoicePhase.listening);
        notifyListeners();
      }
      return result;
    }
    return _requestExceptionAdvice(utterance);
  }

  Future<void> enterForeground() {
    if (_disposed || isTerminal) {
      return Future<void>.value();
    }
    final wasForeground = _isForeground;
    _isForeground = true;
    final activeEntry = _foregroundEntry;
    if (activeEntry != null && wasForeground) {
      return activeEntry;
    }
    final requestVersion = ++_foregroundRequestVersion;
    final predecessor = activeEntry ?? Future<void>.value();
    late final Future<void> trackedEntry;
    trackedEntry = predecessor
        .then<void>((_) => _enterForegroundOnce(requestVersion))
        .whenComplete(() {
          if (identical(_foregroundEntry, trackedEntry)) {
            _foregroundEntry = null;
            unawaited(_announceTimerElapsedIfPossible());
          }
        });
    _foregroundEntry = trackedEntry;
    return trackedEntry;
  }

  Future<void> _enterForegroundOnce(int requestVersion) async {
    if (_disposed ||
        isTerminal ||
        !_isForeground ||
        requestVersion != _foregroundRequestVersion) {
      return;
    }
    _timer.sync();
    if (_speechInputDesired) {
      await _announceTimerElapsedIfPossible(duringForegroundEntry: true);
      return;
    }
    if (_speechInputRestartBlocked || _speechOutputUnsafe) {
      _state = _state.copyWith(
        voicePhase: VoicePhase.failed,
        lastCommandMessage: '음성 장치를 안전하게 다시 시작할 수 없어요. 버튼으로 계속 조리하세요.',
      );
      notifyListeners();
      return;
    }
    if (await _waitForSpeechOutputSafety() == null) {
      return;
    }
    final wasPermissionDenied =
        _state.voicePhase == VoicePhase.permissionDenied;
    _speechInputReady = false;
    final shouldAnnounceInitialStep = !_hasAnnouncedInitialStep;
    final initialStep = _state.stepIndex;
    final initialContextVersion = _state.requestContextVersion;
    if (shouldAnnounceInitialStep) {
      _hasAnnouncedInitialStep = true;
    }
    _state = _state.copyWith(
      voicePhase: wasPermissionDenied
          ? VoicePhase.permissionDenied
          : VoicePhase.starting,
      lastCommandMessage: wasPermissionDenied
          ? '마이크 권한을 다시 확인하고 있어요.'
          : '마이크를 준비하고 있어요.',
    );
    notifyListeners();
    if (shouldAnnounceInitialStep) {
      await _speakCurrentStep();
    }
    if (_disposed ||
        !_isForeground ||
        isTerminal ||
        requestVersion != _foregroundRequestVersion ||
        _state.requestContextVersion != initialContextVersion ||
        _state.stepIndex != initialStep) {
      if (!_disposed && !isTerminal && _state.stepIndex == initialStep) {
        _hasAnnouncedInitialStep = false;
      }
      return;
    }
    if (_speechInputRestartBlocked || _speechOutputUnsafe) {
      if (shouldAnnounceInitialStep) {
        _hasAnnouncedInitialStep = false;
      }
      return;
    }
    await _announceTimerElapsedIfPossible(duringForegroundEntry: true);
    if (_disposed ||
        !_isForeground ||
        isTerminal ||
        requestVersion != _foregroundRequestVersion ||
        _state.requestContextVersion != initialContextVersion ||
        _speechInputRestartBlocked ||
        _speechOutputUnsafe) {
      return;
    }
    while (true) {
      final safeOutputActivityVersion = await _waitForSpeechOutputSafety();
      if (_disposed ||
          !_isForeground ||
          isTerminal ||
          safeOutputActivityVersion == null ||
          requestVersion != _foregroundRequestVersion ||
          _state.requestContextVersion != initialContextVersion) {
        return;
      }
      if (safeOutputActivityVersion != _speechOutputActivityVersion) {
        continue;
      }
      _speechInputDesired = true;
      _speechInputReady = false;
      final lifecycleVersion = ++_speechLifecycleVersion;
      await _queueSpeechInputStart(
        lifecycleVersion,
        outputActivityVersion: safeOutputActivityVersion,
      );
      break;
    }
    if (shouldAnnounceInitialStep && _state.voicePhase == VoicePhase.off) {
      _hasAnnouncedInitialStep = false;
    }
  }

  Future<void> leaveForeground() async {
    if (_disposed) {
      return;
    }
    _isForeground = false;
    _foregroundRequestVersion += 1;
    _speechInputDesired = false;
    _speechInputReady = false;
    _speechLifecycleVersion += 1;
    _voiceOperationVersion += 1;
    if (!isTerminal) {
      _state = _state.copyWith(
        voicePhase: VoicePhase.off,
        requestContextVersion: _state.requestContextVersion + 1,
        lastCommandMessage: '화면을 벗어나 음성 수신을 종료했어요.',
      );
      _record(
        source: CommandSource.system,
        command: 'voice_stopped_on_background',
        result: 'success',
      );
      notifyListeners();
    }
    await Future.wait<bool>(<Future<bool>>[
      _queueSpeechInputStop(),
      _queueSpeechOutputStop(),
    ]);
  }

  void setMicrophonePermissionDenied() {
    if (_disposed || isTerminal) {
      return;
    }
    _speechInputDesired = false;
    _speechInputReady = false;
    _speechLifecycleVersion += 1;
    _voiceOperationVersion += 1;
    _state = _state.copyWith(
      voicePhase: VoicePhase.permissionDenied,
      requestContextVersion: _state.requestContextVersion + 1,
      lastCommandMessage: '마이크 권한이 없어도 버튼으로 계속 조리할 수 있어요.',
    );
    _record(
      source: CommandSource.system,
      command: 'microphone_permission_denied',
      result: 'button_fallback_available',
    );
    notifyListeners();
    _stopSpeechInputWithoutWaiting();
  }

  void markFeedbackSaved() {
    if (_disposed || _state.sessionStatus != CookingSessionStatus.review) {
      return;
    }
    _state = _state.copyWith(sessionStatus: CookingSessionStatus.completed);
    _record(
      source: CommandSource.system,
      command: 'feedback_saved',
      result: 'success',
    );
    notifyListeners();
  }

  bool _isDuplicate(CookingCommand command) {
    final now = _commandClock();
    final lastAt = _lastCommandAt;
    final duplicate =
        _lastCommand == command &&
        lastAt != null &&
        now - lastAt < const Duration(milliseconds: 300);
    if (!duplicate) {
      _lastCommand = command;
      _lastCommandAt = now;
    }
    return duplicate;
  }

  bool _rememberUtteranceId(String utteranceId) {
    if (_seenUtteranceIds.contains(utteranceId)) {
      return false;
    }
    _seenUtteranceIds.add(utteranceId);
    const retainedIdLimit = 64;
    if (_seenUtteranceIds.length > retainedIdLimit) {
      _seenUtteranceIds.remove(_seenUtteranceIds.first);
    }
    return true;
  }

  Future<CommandResult> _moveStep(int delta, CommandSource source) async {
    final target = _state.stepIndex + delta;
    if (target < 0 || target >= _steps.length) {
      const message = '이동할 단계가 없어요.';
      _setMessage(message);
      _record(
        source: source,
        command: delta < 0 ? 'previous_step' : 'next_step',
        result: 'blocked_at_boundary',
      );
      return const CommandResult(executed: false, message: message);
    }

    _timerSnapshots[_state.stepIndex] = _timer.snapshot();
    _state = _state.copyWith(
      stepIndex: target,
      requestContextVersion: _state.requestContextVersion + 1,
      exceptionFeedback: null,
      lastCommandMessage: '${target + 1}단계로 이동했어요.',
    );
    _activateStep(target);
    _state = _state.copyWith(
      sessionStatus: _timer.status == TimerStatus.paused
          ? CookingSessionStatus.paused
          : CookingSessionStatus.cooking,
    );
    _record(
      source: source,
      command: delta < 0 ? 'previous_step' : 'next_step',
      result: 'success',
    );
    notifyListeners();
    await _speakCurrentStep();
    return CommandResult(executed: true, message: '${target + 1}단계로 이동했어요.');
  }

  Future<CommandResult> _repeatInstruction(CommandSource source) async {
    const message = '현재 안내를 다시 들려드릴게요.';
    _setMessage(message);
    _record(source: source, command: 'repeat_instruction', result: 'success');
    await _speakCurrentStep();
    return const CommandResult(executed: true, message: message);
  }

  Future<CommandResult> _announceCurrentStep(CommandSource source) async {
    final message = '${_state.stepIndex + 1}단계예요. ${currentStep.instruction}';
    _setMessage(message);
    _record(
      source: source,
      command: 'announce_current_step',
      result: 'success',
    );
    await _speakCurrentStep();
    return CommandResult(executed: true, message: message);
  }

  Future<CommandResult> _addMinute(CommandSource source) async {
    final activeTimerElapsedPlayback = _timer.status == TimerStatus.elapsed
        ? _activeTimerElapsedPlayback
        : null;
    _timer.add(const Duration(minutes: 1));
    _syncTimerAlarmSchedule();
    const message = '타이머에 1분을 추가했어요.';
    _setMessage(message);
    _record(source: source, command: 'add_minute', result: 'success');
    if (activeTimerElapsedPlayback != null) {
      await _cancelTimerElapsedAnnouncement(activeTimerElapsedPlayback);
    }
    return const CommandResult(executed: true, message: message);
  }

  Future<void> _cancelTimerElapsedAnnouncement(
    Future<_SpeechPlaybackOutcome> activePlayback,
  ) async {
    if (!identical(_activeTimerElapsedPlayback, activePlayback)) {
      return;
    }
    final shouldResumeSpeechInput =
        _speechInputDesired && _isForeground && !isTerminal;
    final recoveryPhase = _speechRecoveryPhase ?? VoicePhase.listening;
    _speechInputReady = false;
    if (shouldResumeSpeechInput) {
      _speechLifecycleVersion += 1;
    }
    final cancellationVersion = ++_voiceOperationVersion;
    final stopped = await _queueSpeechOutputStop();
    await activePlayback;
    if (_disposed ||
        isTerminal ||
        cancellationVersion != _voiceOperationVersion ||
        !stopped ||
        _speechOutputUnsafe) {
      return;
    }

    _speechRecoveryPhase = null;
    _record(
      source: CommandSource.system,
      command: 'timer_elapsed_announcement_cancelled',
      result: 'timer_extended',
    );
    if (shouldResumeSpeechInput &&
        _speechInputDesired &&
        _isForeground &&
        !_speechInputRestartBlocked) {
      _state = _state.copyWith(voicePhase: VoicePhase.starting);
      notifyListeners();
      final lifecycleVersion = ++_speechLifecycleVersion;
      await _queueSpeechInputStart(
        lifecycleVersion,
        outputActivityVersion: _speechOutputActivityVersion,
      );
      return;
    }
    if (_state.voicePhase == VoicePhase.speaking) {
      _state = _state.copyWith(voicePhase: recoveryPhase);
      notifyListeners();
    }
  }

  CommandResult _pauseTimer(CommandSource source) {
    _timer.sync();
    if (_timer.status == TimerStatus.elapsed) {
      const message = '이미 시간이 끝났어요.';
      _setMessage(message);
      _record(
        source: source,
        command: 'pause_timer',
        result: 'blocked_elapsed',
      );
      return const CommandResult(executed: false, message: message);
    }
    if (_timer.status != TimerStatus.running) {
      const message = '현재 타이머가 실행 중이 아니에요.';
      _setMessage(message);
      _record(
        source: source,
        command: 'pause_timer',
        result: 'blocked_not_running',
      );
      return const CommandResult(executed: false, message: message);
    }
    _timer.pause();
    _syncTimerAlarmSchedule();
    _state = _state.copyWith(
      sessionStatus: CookingSessionStatus.paused,
      lastCommandMessage: '타이머를 일시정지했어요.',
    );
    _record(source: source, command: 'pause_timer', result: 'success');
    notifyListeners();
    return const CommandResult(executed: true, message: '타이머를 일시정지했어요.');
  }

  CommandResult _resumeTimer(CommandSource source) {
    if (_timer.status != TimerStatus.paused) {
      const message = '일시정지된 타이머가 없어요.';
      _setMessage(message);
      _record(
        source: source,
        command: 'resume_timer',
        result: 'blocked_not_paused',
      );
      return const CommandResult(executed: false, message: message);
    }
    _timer.resume();
    _syncTimerAlarmSchedule();
    _state = _state.copyWith(
      sessionStatus: CookingSessionStatus.cooking,
      lastCommandMessage: '타이머를 다시 시작했어요.',
    );
    _record(source: source, command: 'resume_timer', result: 'success');
    notifyListeners();
    return const CommandResult(executed: true, message: '타이머를 다시 시작했어요.');
  }

  Future<CommandResult> _completeSession(CommandSource source) async {
    _isForeground = false;
    _foregroundRequestVersion += 1;
    _speechInputDesired = false;
    _speechInputReady = false;
    _speechLifecycleVersion += 1;
    _voiceOperationVersion += 1;
    _timer.pause();
    unawaited(_alarm.cancelScheduledAlarm());
    _state = _state.copyWith(
      sessionStatus: CookingSessionStatus.review,
      voicePhase: VoicePhase.off,
      requestContextVersion: _state.requestContextVersion + 1,
      lastCommandMessage: '조리가 끝났어요. 결과를 짧게 남겨주세요.',
    );
    _record(source: source, command: 'complete_session', result: 'success');
    notifyListeners();
    await Future.wait<bool>(<Future<bool>>[
      _queueSpeechInputStop(),
      _queueSpeechOutputStop(),
    ]);
    return const CommandResult(
      executed: true,
      message: '조리가 끝났어요. 결과를 짧게 남겨주세요.',
    );
  }

  Future<CommandResult> _abortSession(CommandSource source) async {
    _isForeground = false;
    _foregroundRequestVersion += 1;
    _speechInputDesired = false;
    _speechInputReady = false;
    _speechLifecycleVersion += 1;
    _voiceOperationVersion += 1;
    _timer.pause();
    unawaited(_alarm.cancelScheduledAlarm());
    _state = _state.copyWith(
      sessionStatus: CookingSessionStatus.aborted,
      voicePhase: VoicePhase.off,
      requestContextVersion: _state.requestContextVersion + 1,
      lastCommandMessage: '조리를 중단했어요.',
    );
    _record(source: source, command: 'abort_session', result: 'success');
    notifyListeners();
    await Future.wait<bool>(<Future<bool>>[
      _queueSpeechInputStop(),
      _queueSpeechOutputStop(),
    ]);
    return const CommandResult(executed: true, message: '조리를 중단했어요.');
  }

  Future<CommandResult> _requestExceptionAdvice(String utterance) async {
    final exceptionRequestVersion = ++_exceptionRequestVersion;
    final requestedStep = _state.stepIndex;
    final requestedVersion = _state.requestContextVersion;
    _state = _state.copyWith(
      voicePhase: VoicePhase.processing,
      lastCommandMessage: '현재 단계에 맞는 답을 확인하고 있어요.',
    );
    _record(
      source: CommandSource.voice,
      command: 'exception_advice_requested',
      result: 'pending',
    );
    notifyListeners();

    late final ExceptionAdvice advice;
    try {
      advice = await _exceptionAdvice.requestAdvice(
        ExceptionAdviceContext(
          sessionId: _state.sessionId,
          recipeId: _recipeId,
          recipeVersionId: _recipeVersionId,
          stepIndex: requestedStep,
          requestContextVersion: requestedVersion,
          instruction: _steps[requestedStep].instruction,
          remaining: _timer.remaining,
          utterance: utterance,
          recentEvents: _recentAdviceEvents(),
        ),
      );
    } catch (_) {
      if (!_isExceptionRequestCurrent(
        exceptionRequestVersion: exceptionRequestVersion,
        stepIndex: requestedStep,
        contextVersion: requestedVersion,
      )) {
        return const CommandResult(
          executed: false,
          message: '현재 화면의 맥락이 바뀌어 이전 요청을 종료했어요.',
        );
      }
      _state = _state.copyWith(
        voicePhase: VoicePhase.failed,
        lastCommandMessage: '답변을 불러오지 못했어요. 버튼과 타이머는 계속 사용할 수 있어요.',
      );
      _record(
        source: CommandSource.voice,
        command: 'exception_advice_failed',
        result: 'error',
      );
      notifyListeners();
      return const CommandResult(
        executed: false,
        message: '답변을 불러오지 못했어요. 버튼과 타이머는 계속 사용할 수 있어요.',
      );
    }

    if (!_isExceptionRequestCurrent(
      exceptionRequestVersion: exceptionRequestVersion,
      stepIndex: requestedStep,
      contextVersion: requestedVersion,
    )) {
      if (!_disposed) {
        _record(
          source: CommandSource.system,
          command: 'exception_advice_discarded',
          result: 'stale_context_or_request',
        );
      }
      return const CommandResult(
        executed: false,
        message: '화면 맥락이나 질문이 바뀌어 이전 답변을 표시하지 않았어요.',
      );
    }

    final phaseBeforeAdviceSpeech = _state.voicePhase == VoicePhase.speaking
        ? _speechRecoveryPhase ?? VoicePhase.listening
        : _state.voicePhase;
    _speechRecoveryPhase = phaseBeforeAdviceSpeech;
    _state = _state.copyWith(
      voicePhase: VoicePhase.speaking,
      exceptionFeedback: advice.message,
      lastCommandMessage: '현재 단계에 맞는 안내를 찾았어요.',
    );
    _record(
      source: CommandSource.voice,
      command: 'exception_advice_received',
      result: 'success',
    );
    notifyListeners();

    final voiceOperationVersion = ++_voiceOperationVersion;
    final playback = await _playSpeechSafely(
      advice.message,
      voiceOperationVersion: voiceOperationVersion,
      stepIndex: requestedStep,
      contextVersion: requestedVersion,
    );
    if (playback == _SpeechPlaybackOutcome.spoken &&
        _isVoiceOperationCurrent(
          voiceOperationVersion: voiceOperationVersion,
          stepIndex: requestedStep,
          contextVersion: requestedVersion,
        ) &&
        _state.voicePhase == VoicePhase.speaking) {
      _state = _state.copyWith(
        voicePhase: phaseBeforeAdviceSpeech == VoicePhase.processing
            ? _phaseAfterSpeech(VoicePhase.listening)
            : _phaseAfterSpeech(phaseBeforeAdviceSpeech),
      );
      _speechRecoveryPhase = null;
      notifyListeners();
    } else if (playback == _SpeechPlaybackOutcome.outputFailed &&
        _isVoiceOperationCurrent(
          voiceOperationVersion: voiceOperationVersion,
          stepIndex: requestedStep,
          contextVersion: requestedVersion,
        )) {
      _state = _state.copyWith(
        voicePhase: phaseBeforeAdviceSpeech == VoicePhase.permissionDenied
            ? VoicePhase.permissionDenied
            : VoicePhase.failed,
        lastCommandMessage: '답변은 화면에 표시했지만 음성으로 재생하지 못했어요.',
      );
      _speechRecoveryPhase = null;
      _record(
        source: CommandSource.system,
        command: 'speech_output_failed',
        result: 'exception_advice_visible',
      );
      notifyListeners();
    }
    return CommandResult(executed: true, message: advice.message);
  }

  Future<void> _speakCurrentStep() async {
    if (_disposed || isTerminal || _state.voicePhase == VoicePhase.off) {
      return;
    }
    final phaseBeforeSpeech = _state.voicePhase == VoicePhase.speaking
        ? _speechRecoveryPhase ?? VoicePhase.listening
        : _state.voicePhase;
    _speechRecoveryPhase = phaseBeforeSpeech;
    final speakingVersion = _state.requestContextVersion;
    final speakingStep = _state.stepIndex;
    final voiceOperationVersion = ++_voiceOperationVersion;
    _state = _state.copyWith(voicePhase: VoicePhase.speaking);
    notifyListeners();
    final playback = await _playSpeechSafely(
      '${currentStep.instruction} ${currentStep.completionCue}',
      voiceOperationVersion: voiceOperationVersion,
      stepIndex: speakingStep,
      contextVersion: speakingVersion,
    );
    if (playback == _SpeechPlaybackOutcome.spoken &&
        _isVoiceOperationCurrent(
          voiceOperationVersion: voiceOperationVersion,
          stepIndex: speakingStep,
          contextVersion: speakingVersion,
        ) &&
        _state.voicePhase == VoicePhase.speaking) {
      _state = _state.copyWith(
        voicePhase: _phaseAfterSpeech(phaseBeforeSpeech),
      );
      _speechRecoveryPhase = null;
      notifyListeners();
    } else if (playback == _SpeechPlaybackOutcome.outputFailed &&
        _isVoiceOperationCurrent(
          voiceOperationVersion: voiceOperationVersion,
          stepIndex: speakingStep,
          contextVersion: speakingVersion,
        )) {
      final phaseAfterSpeech = _phaseAfterSpeech(phaseBeforeSpeech);
      _state = _state.copyWith(
        voicePhase: phaseAfterSpeech == VoicePhase.permissionDenied
            ? VoicePhase.permissionDenied
            : VoicePhase.failed,
        lastCommandMessage: '음성 안내를 재생하지 못했어요. 화면의 안내를 확인해주세요.',
      );
      _speechRecoveryPhase = null;
      _record(
        source: CommandSource.system,
        command: 'speech_output_failed',
        result: 'step_instruction_visible',
      );
      notifyListeners();
    }
  }

  Future<void> _announceTimerElapsedIfPossible({
    bool duringForegroundEntry = false,
  }) async {
    if (!_timerElapsedAnnouncementPending || _disposed) {
      return;
    }
    if (_timer.status != TimerStatus.elapsed) {
      _timerElapsedAnnouncementPending = false;
      return;
    }
    if (isTerminal) {
      _timerElapsedAnnouncementPending = false;
      return;
    }
    if (!_isForeground ||
        _state.voicePhase == VoicePhase.off ||
        (!duringForegroundEntry && _foregroundEntry != null) ||
        _speechOutputUnsafe) {
      return;
    }
    _timerElapsedAnnouncementPending = false;
    final phaseBeforeSpeech = _state.voicePhase == VoicePhase.speaking
        ? _speechRecoveryPhase ?? VoicePhase.listening
        : _state.voicePhase;
    _speechRecoveryPhase = phaseBeforeSpeech;
    final speakingStep = _state.stepIndex;
    final speakingVersion = _state.requestContextVersion;
    final voiceOperationVersion = ++_voiceOperationVersion;
    _state = _state.copyWith(
      voicePhase: VoicePhase.speaking,
      lastCommandMessage: '시간이 끝났어요. 준비되면 다음을 눌러주세요.',
    );
    _record(
      source: CommandSource.system,
      command: 'timer_elapsed_announcement_started',
      result: 'pending',
    );
    notifyListeners();

    final playbackFuture = _playSpeechSafely(
      '시간이 끝났어요. 준비되면 다음 버튼을 눌러주세요.',
      voiceOperationVersion: voiceOperationVersion,
      stepIndex: speakingStep,
      contextVersion: speakingVersion,
    );
    _activeTimerElapsedPlayback = playbackFuture;
    late final _SpeechPlaybackOutcome playback;
    try {
      playback = await playbackFuture;
    } finally {
      if (identical(_activeTimerElapsedPlayback, playbackFuture)) {
        _activeTimerElapsedPlayback = null;
      }
    }
    if (playback == _SpeechPlaybackOutcome.spoken &&
        _isVoiceOperationCurrent(
          voiceOperationVersion: voiceOperationVersion,
          stepIndex: speakingStep,
          contextVersion: speakingVersion,
        ) &&
        _state.voicePhase == VoicePhase.speaking) {
      _state = _state.copyWith(
        voicePhase: _phaseAfterSpeech(phaseBeforeSpeech),
      );
      _speechRecoveryPhase = null;
      _record(
        source: CommandSource.system,
        command: 'timer_elapsed_announcement_completed',
        result: 'success_no_auto_advance',
      );
      notifyListeners();
    } else if (playback == _SpeechPlaybackOutcome.outputFailed &&
        _isVoiceOperationCurrent(
          voiceOperationVersion: voiceOperationVersion,
          stepIndex: speakingStep,
          contextVersion: speakingVersion,
        )) {
      final phaseAfterSpeech = _phaseAfterSpeech(phaseBeforeSpeech);
      _state = _state.copyWith(
        voicePhase: phaseAfterSpeech == VoicePhase.permissionDenied
            ? VoicePhase.permissionDenied
            : VoicePhase.failed,
        lastCommandMessage: '시간 종료 안내를 음성으로 재생하지 못했어요. 화면을 확인해주세요.',
      );
      _speechRecoveryPhase = null;
      _record(
        source: CommandSource.system,
        command: 'speech_output_failed',
        result: 'timer_elapsed_prompt_visible',
      );
      notifyListeners();
    } else if (playback == _SpeechPlaybackOutcome.stale &&
        !_disposed &&
        !isTerminal &&
        !_isForeground &&
        _timer.status == TimerStatus.elapsed) {
      _timerElapsedAnnouncementPending = true;
    }
  }

  void _activateStep(int index) {
    _timerElapsedAnnouncementPending = false;
    _isActivatingStep = true;
    try {
      final snapshot = _timerSnapshots[index];
      if (snapshot != null) {
        _timer.restore(snapshot);
        _record(
          source: CommandSource.system,
          command: 'timer_restored',
          result: _timer.status.name,
        );
      } else {
        final duration = _steps[index].timerDuration;
        _timer.reset(duration, autoStart: duration > Duration.zero);
        if (duration > Duration.zero) {
          _record(
            source: CommandSource.system,
            command: 'timer_started',
            result: 'success',
          );
        }
      }
    } finally {
      _timerSnapshots[index] = _timer.snapshot();
      _lastObservedTimerStatus = _timer.status;
      _isActivatingStep = false;
    }
    _syncTimerAlarmSchedule();
  }

  void _handleTimerChanged() {
    _timerSnapshots[_state.stepIndex] = _timer.snapshot();
    final status = _timer.status;
    var shouldAnnounceElapsed = false;
    if (_isActivatingStep) {
      _lastObservedTimerStatus = status;
      return;
    }
    if (status == TimerStatus.elapsed &&
        _lastObservedTimerStatus != TimerStatus.elapsed) {
      _timerElapsedAnnouncementPending = true;
      shouldAnnounceElapsed = true;
      _alarm.signalTimerElapsed();
      // 포그라운드에서 이미 울렸으니 남아있는 백그라운드 예약은 취소한다.
      _syncTimerAlarmSchedule();
      _state = _state.copyWith(lastCommandMessage: '시간이 끝났어요. 준비되면 다음을 눌러주세요.');
      _record(
        source: CommandSource.system,
        command: 'timer_elapsed',
        result: 'success_no_auto_advance',
      );
    } else if (status != TimerStatus.elapsed) {
      _timerElapsedAnnouncementPending = false;
    }
    _lastObservedTimerStatus = status;
    if (!_disposed) {
      notifyListeners();
    }
    if (shouldAnnounceElapsed) {
      unawaited(_announceTimerElapsedIfPossible());
    }
  }

  /// 현재 타이머 상태에 맞춰 백그라운드 알림 예약을 동기화한다.
  /// 실행 중이고 남은 시간이 있으면 완료 시각에 예약하고, 그 외에는 취소한다.
  /// 매 틱이 아니라 타이머 상태가 바뀌는 지점에서만 호출해야 한다.
  void _syncTimerAlarmSchedule() {
    if (_disposed || isTerminal) {
      unawaited(_alarm.cancelScheduledAlarm());
      return;
    }
    if (_timer.status == TimerStatus.running &&
        _timer.remaining > Duration.zero) {
      unawaited(
        _alarm.scheduleTimerElapsed(_wallClock().add(_timer.remaining)),
      );
    } else {
      unawaited(_alarm.cancelScheduledAlarm());
    }
  }

  void _setMessage(String message) {
    _state = _state.copyWith(lastCommandMessage: message);
    if (!_disposed) {
      notifyListeners();
    }
  }

  bool _isVoiceOperationCurrent({
    required int voiceOperationVersion,
    required int stepIndex,
    required int contextVersion,
  }) {
    return !_disposed &&
        _voiceOperationVersion == voiceOperationVersion &&
        _state.stepIndex == stepIndex &&
        _state.requestContextVersion == contextVersion &&
        !isTerminal &&
        _state.voicePhase != VoicePhase.off &&
        _state.voicePhase != VoicePhase.permissionDenied;
  }

  bool _isExceptionRequestCurrent({
    required int exceptionRequestVersion,
    required int stepIndex,
    required int contextVersion,
  }) {
    return !_disposed &&
        _exceptionRequestVersion == exceptionRequestVersion &&
        _state.stepIndex == stepIndex &&
        _state.requestContextVersion == contextVersion &&
        !isTerminal;
  }

  void _handleSpeechInputFailure(
    SpeechInputFailure failure,
    int lifecycleVersion,
  ) {
    if (_disposed ||
        lifecycleVersion != _speechLifecycleVersion ||
        isTerminal ||
        _state.voicePhase == VoicePhase.off) {
      return;
    }
    if (failure == SpeechInputFailure.permissionDenied) {
      setMicrophonePermissionDenied();
      return;
    }

    _voiceOperationVersion += 1;
    final retryRequired = failure == SpeechInputFailure.retryRequired;
    _speechInputReady = false;
    if (!retryRequired) {
      _speechInputDesired = false;
      _speechLifecycleVersion += 1;
    }
    _state = _state.copyWith(
      voicePhase: retryRequired ? VoicePhase.retryRequired : VoicePhase.failed,
      lastCommandMessage: retryRequired
          ? '음성을 인식하지 못했어요. 짧게 다시 말해주세요.'
          : '음성 입력을 사용할 수 없어요. 버튼으로 계속 조리하세요.',
    );
    _record(
      source: CommandSource.system,
      command: retryRequired
          ? 'speech_input_retry_required'
          : 'speech_input_failed',
      result: 'button_fallback_available',
    );
    notifyListeners();
    if (!retryRequired) {
      _stopSpeechInputWithoutWaiting();
    }
  }

  void _record({
    required CommandSource source,
    required String command,
    required String result,
  }) {
    _eventSequence += 1;
    _events.add(
      CookingEvent(
        eventId: '${_state.sessionId}-$_eventSequence',
        sessionId: _state.sessionId,
        recipeId: _recipeId,
        recipeVersionId: _recipeVersionId,
        stepIndex: _state.stepIndex,
        source: source,
        command: command,
        occurredAt: _wallClock(),
        result: result,
        contextVersion: _state.requestContextVersion,
      ),
    );
  }

  List<ExceptionAdviceEvent> _recentAdviceEvents() {
    const limit = 12;
    final start = _events.length > limit ? _events.length - limit : 0;
    return List<ExceptionAdviceEvent>.unmodifiable(
      _events
          .skip(start)
          .map(
            (event) => ExceptionAdviceEvent(
              stepIndex: event.stepIndex,
              source: event.source.name,
              command: event.command,
              result: event.result,
              occurredAt: event.occurredAt,
            ),
          ),
    );
  }

  Future<void> _queueSpeechInputStart(
    int lifecycleVersion, {
    required int outputActivityVersion,
  }) async {
    final transition = _speechInputTransition.then<void>(
      (_) => _startSpeechInput(lifecycleVersion, outputActivityVersion),
    );
    _speechInputTransition = transition;
    try {
      await transition.timeout(_voiceStopTimeout);
    } on TimeoutException {
      if (!_disposed && lifecycleVersion == _speechLifecycleVersion) {
        _record(
          source: CommandSource.system,
          command: 'speech_input_start_timed_out',
          result: 'waiting_for_previous_stop',
        );
        _blockSpeechInputRestart();
      }
    }
  }

  void _startSpeechInput(int lifecycleVersion, int outputActivityVersion) {
    if (_disposed ||
        !_speechInputDesired ||
        _speechInputRestartBlocked ||
        _speechOutputUnsafe ||
        outputActivityVersion != _speechOutputActivityVersion ||
        lifecycleVersion != _speechLifecycleVersion ||
        isTerminal) {
      return;
    }
    _seenUtteranceIds.clear();
    try {
      _speechInput.start(
        onReady: () {
          _handleSpeechInputReady(lifecycleVersion);
        },
        onUtterance: (utterance, utteranceId) {
          if (_disposed ||
              !_speechInputDesired ||
              lifecycleVersion != _speechLifecycleVersion ||
              _state.voicePhase == VoicePhase.off) {
            return;
          }
          unawaited(handleUtterance(utterance, utteranceId: utteranceId));
        },
        onFailure: (failure) {
          _handleSpeechInputFailure(failure, lifecycleVersion);
        },
      );
    } catch (_) {
      if (_disposed ||
          lifecycleVersion != _speechLifecycleVersion ||
          isTerminal ||
          _state.voicePhase == VoicePhase.off) {
        return;
      }
      _speechInputDesired = false;
      _speechInputReady = false;
      _speechLifecycleVersion += 1;
      _voiceOperationVersion += 1;
      _state = _state.copyWith(
        voicePhase: VoicePhase.failed,
        lastCommandMessage: '음성 입력을 시작하지 못했어요. 버튼으로 계속 조리하세요.',
      );
      _record(
        source: CommandSource.system,
        command: 'speech_input_start_failed',
        result: 'error',
      );
      notifyListeners();
      _stopSpeechInputWithoutWaiting();
    }
  }

  void _handleSpeechInputReady(int lifecycleVersion) {
    if (_disposed ||
        !_speechInputDesired ||
        lifecycleVersion != _speechLifecycleVersion ||
        isTerminal ||
        _state.voicePhase == VoicePhase.off) {
      return;
    }
    _speechInputReady = true;
    if (_state.voicePhase != VoicePhase.permissionDenied &&
        _state.voicePhase != VoicePhase.starting &&
        _state.voicePhase != VoicePhase.retryRequired &&
        _state.voicePhase != VoicePhase.listening) {
      return;
    }
    _state = _state.copyWith(
      voicePhase: VoicePhase.listening,
      lastCommandMessage: '마이크가 준비됐어요. 음성 명령을 들을게요.',
    );
    notifyListeners();
  }

  VoicePhase _phaseAfterSpeech(VoicePhase phaseBeforeSpeech) {
    if (phaseBeforeSpeech == VoicePhase.processing) {
      return VoicePhase.processing;
    }
    if (_speechInputDesired && _speechInputReady) {
      return VoicePhase.listening;
    }
    if (phaseBeforeSpeech == VoicePhase.permissionDenied) {
      return VoicePhase.permissionDenied;
    }
    if (phaseBeforeSpeech == VoicePhase.retryRequired) {
      return VoicePhase.retryRequired;
    }
    if (_speechInputDesired) {
      return VoicePhase.starting;
    }
    return phaseBeforeSpeech;
  }

  Future<({int lifecycleVersion, bool safelyStopped, bool shouldResume})>
  _suspendSpeechInputForOutput() async {
    final shouldResume = _speechInputDesired && _isForeground && !isTerminal;
    if (!shouldResume) {
      return (
        lifecycleVersion: _speechLifecycleVersion,
        safelyStopped: true,
        shouldResume: false,
      );
    }
    _speechInputReady = false;
    final lifecycleVersion = ++_speechLifecycleVersion;
    final safelyStopped = await _queueSpeechInputStop();
    return (
      lifecycleVersion: lifecycleVersion,
      safelyStopped: safelyStopped,
      shouldResume: true,
    );
  }

  Future<void> _resumeSpeechInputAfterOutput({
    required int suspendedLifecycleVersion,
    required bool shouldResume,
  }) async {
    if (!shouldResume ||
        _disposed ||
        !_isForeground ||
        isTerminal ||
        !_speechInputDesired ||
        _speechInputRestartBlocked ||
        _speechOutputUnsafe ||
        suspendedLifecycleVersion != _speechLifecycleVersion) {
      return;
    }
    _speechInputReady = false;
    final lifecycleVersion = ++_speechLifecycleVersion;
    await _queueSpeechInputStart(
      lifecycleVersion,
      outputActivityVersion: _speechOutputActivityVersion,
    );
  }

  Future<_SpeechPlaybackOutcome> _playSpeechSafely(
    String text, {
    required int voiceOperationVersion,
    required int stepIndex,
    required int contextVersion,
  }) async {
    _speechOutputActivityVersion += 1;
    final suspension = await _suspendSpeechInputForOutput();
    if (!suspension.safelyStopped) {
      return _SpeechPlaybackOutcome.unsafe;
    }
    if (!_isVoiceOperationCurrent(
      voiceOperationVersion: voiceOperationVersion,
      stepIndex: stepIndex,
      contextVersion: contextVersion,
    )) {
      return _SpeechPlaybackOutcome.stale;
    }
    final outputStopped = await _queueSpeechOutputStop();
    if (!outputStopped) {
      return _SpeechPlaybackOutcome.unsafe;
    }
    final safeOutputActivityVersion = await _waitForSpeechOutputSafety();
    if (safeOutputActivityVersion == null) {
      return _SpeechPlaybackOutcome.unsafe;
    }
    if (safeOutputActivityVersion != _speechOutputActivityVersion) {
      return _SpeechPlaybackOutcome.stale;
    }
    if (!_isVoiceOperationCurrent(
      voiceOperationVersion: voiceOperationVersion,
      stepIndex: stepIndex,
      contextVersion: contextVersion,
    )) {
      return _SpeechPlaybackOutcome.stale;
    }

    final playback = await _awaitSpeechPlayback(
      text,
      voiceOperationVersion: voiceOperationVersion,
      stepIndex: stepIndex,
      contextVersion: contextVersion,
    );
    if (playback == _SpeechPlaybackOutcome.stale ||
        playback == _SpeechPlaybackOutcome.unsafe) {
      return playback;
    }
    await _resumeSpeechInputAfterOutput(
      suspendedLifecycleVersion: suspension.lifecycleVersion,
      shouldResume: suspension.shouldResume,
    );
    if (!_isVoiceOperationCurrent(
      voiceOperationVersion: voiceOperationVersion,
      stepIndex: stepIndex,
      contextVersion: contextVersion,
    )) {
      return _SpeechPlaybackOutcome.stale;
    }
    return playback;
  }

  Future<_SpeechPlaybackOutcome> _awaitSpeechPlayback(
    String text, {
    required int voiceOperationVersion,
    required int stepIndex,
    required int contextVersion,
  }) async {
    _speechOutputActivityVersion += 1;
    final playback = Future<void>.sync(() => _speechOutput.speak(text))
        .then<_SpeechPlaybackOutcome>(
          (_) => _SpeechPlaybackOutcome.spoken,
          onError: (Object _, StackTrace _) =>
              _SpeechPlaybackOutcome.outputFailed,
        );
    late final Future<void> trackedPlayback;
    trackedPlayback = playback.then<void>((_) {}).whenComplete(() {
      if (identical(_activeSpeechPlayback, trackedPlayback)) {
        _activeSpeechPlayback = null;
      }
    });
    _activeSpeechPlayback = trackedPlayback;
    final timeoutSignal = Completer<_SpeechPlaybackOutcome?>();
    final timeoutTimer = Timer(
      _voicePlaybackTimeout,
      () => timeoutSignal.complete(_SpeechPlaybackOutcome.timedOut),
    );
    try {
      while (true) {
        final result = await Future.any<_SpeechPlaybackOutcome?>(
          <Future<_SpeechPlaybackOutcome?>>[
            playback,
            timeoutSignal.future,
            Future<_SpeechPlaybackOutcome?>.delayed(
              const Duration(milliseconds: 50),
              () => null,
            ),
          ],
        );
        if (result == _SpeechPlaybackOutcome.timedOut) {
          if (!_disposed) {
            _record(
              source: CommandSource.system,
              command: 'speech_output_playback_timed_out',
              result: 'stopping_output',
            );
          }
          final stopped = await _queueSpeechOutputStop();
          if (!stopped) {
            return _SpeechPlaybackOutcome.unsafe;
          }
          try {
            await trackedPlayback.timeout(_voiceStopTimeout);
          } on TimeoutException {
            if (!_disposed) {
              _record(
                source: CommandSource.system,
                command: 'speech_output_cancel_timed_out',
                result: 'speech_input_not_started',
              );
            }
            _blockSpeechForUnsafeOutput();
            return _SpeechPlaybackOutcome.unsafe;
          }
          return _SpeechPlaybackOutcome.outputFailed;
        }
        if (result != null) {
          return result;
        }
        if (!_isVoiceOperationCurrent(
          voiceOperationVersion: voiceOperationVersion,
          stepIndex: stepIndex,
          contextVersion: contextVersion,
        )) {
          return _SpeechPlaybackOutcome.stale;
        }
      }
    } finally {
      timeoutTimer.cancel();
    }
  }

  Future<bool> _queueSpeechInputStop() {
    final stopVersion = ++_speechInputStopVersion;
    final operation = _speechInputTransition.then<bool>(
      (_) => _stopSpeechInputSafely(),
    );
    _speechInputTransition = operation.then<void>((_) {});
    return _observeSpeechInputStop(operation, stopVersion);
  }

  Future<bool> _observeSpeechInputStop(
    Future<bool> operation,
    int stopVersion,
  ) async {
    try {
      final stopped = await operation.timeout(_voiceStopTimeout);
      if (stopVersion == _speechInputStopVersion) {
        if (stopped) {
          _speechInputRestartBlocked = false;
        } else {
          _blockSpeechInputRestart();
        }
      }
      return stopped;
    } on TimeoutException {
      if (!_disposed) {
        _record(
          source: CommandSource.system,
          command: 'speech_input_stop_timed_out',
          result: 'button_fallback_available',
        );
      }
      if (stopVersion == _speechInputStopVersion) {
        _blockSpeechInputRestart();
      }
      unawaited(
        operation.then<void>((stopped) {
          if (stopped && stopVersion == _speechInputStopVersion) {
            _speechInputRestartBlocked = false;
          }
        }),
      );
      return false;
    }
  }

  Future<bool> _stopSpeechInputSafely() async {
    try {
      await _speechInput.stop();
      return true;
    } catch (_) {
      if (!_disposed) {
        _record(
          source: CommandSource.system,
          command: 'speech_input_stop_failed',
          result: 'ignored_to_preserve_session_transition',
        );
      }
      return false;
    }
  }

  Future<bool> _queueSpeechOutputStop() {
    _speechOutputActivityVersion += 1;
    final stopVersion = ++_speechOutputStopVersion;
    final operation = _speechOutputStopTransition.then<bool>(
      (_) => _stopSpeechOutputSafely(),
    );
    _speechOutputStopTransition = operation.then<void>((_) {});
    return _observeSpeechOutputStop(operation, stopVersion);
  }

  Future<int?> _waitForSpeechOutputSafety() async {
    if (_speechOutputUnsafe) {
      return null;
    }
    while (true) {
      final observedActivityVersion = _speechOutputActivityVersion;
      final pendingStops = _speechOutputStopTransition;
      try {
        await pendingStops.timeout(_voiceStopTimeout);
        final activePlayback = _activeSpeechPlayback;
        if (activePlayback != null) {
          await activePlayback.timeout(_voicePlaybackTimeout);
        }
        if (_speechOutputUnsafe) {
          return null;
        }
        if (observedActivityVersion == _speechOutputActivityVersion) {
          return observedActivityVersion;
        }
      } on TimeoutException {
        if (!_disposed) {
          _record(
            source: CommandSource.system,
            command: 'speech_output_settle_timed_out',
            result: 'speech_input_not_started',
          );
        }
        _blockSpeechForUnsafeOutput();
        return null;
      }
    }
  }

  Future<bool> _observeSpeechOutputStop(
    Future<bool> operation,
    int stopVersion,
  ) async {
    try {
      final stopped = await operation.timeout(_voiceStopTimeout);
      if (stopVersion == _speechOutputStopVersion) {
        if (stopped) {
          _speechOutputUnsafe = false;
        } else {
          _blockSpeechForUnsafeOutput();
        }
      }
      return stopped;
    } on TimeoutException {
      if (!_disposed) {
        _record(
          source: CommandSource.system,
          command: 'speech_output_stop_timed_out',
          result: 'button_fallback_available',
        );
      }
      if (stopVersion == _speechOutputStopVersion) {
        _blockSpeechForUnsafeOutput();
      }
      unawaited(
        operation.then<void>((stopped) {
          if (stopped && stopVersion == _speechOutputStopVersion) {
            _speechOutputUnsafe = false;
          }
        }),
      );
      return false;
    }
  }

  Future<bool> _stopSpeechOutputSafely() async {
    try {
      await _speechOutput.stop();
      return true;
    } catch (_) {
      if (!_disposed) {
        _record(
          source: CommandSource.system,
          command: 'speech_output_stop_failed',
          result: 'ignored_to_preserve_session_transition',
        );
      }
      return false;
    }
  }

  void _blockSpeechInputRestart() {
    final wasBlocked = _speechInputRestartBlocked;
    _speechInputRestartBlocked = true;
    _speechInputDesired = false;
    _speechInputReady = false;
    if (!wasBlocked) {
      _speechLifecycleVersion += 1;
      _voiceOperationVersion += 1;
    }
    if (!_disposed &&
        !isTerminal &&
        _state.voicePhase != VoicePhase.off &&
        _state.voicePhase != VoicePhase.permissionDenied) {
      _state = _state.copyWith(
        voicePhase: VoicePhase.failed,
        lastCommandMessage: '마이크를 안전하게 종료하지 못했어요. 버튼으로 계속 조리하세요.',
      );
      _speechRecoveryPhase = null;
      notifyListeners();
    }
  }

  void _blockSpeechForUnsafeOutput() {
    final wasUnsafe = _speechOutputUnsafe;
    _speechOutputUnsafe = true;
    _speechInputDesired = false;
    _speechInputReady = false;
    if (!wasUnsafe) {
      _speechLifecycleVersion += 1;
      _voiceOperationVersion += 1;
    }
    if (!_disposed && !isTerminal && _state.voicePhase != VoicePhase.off) {
      _state = _state.copyWith(
        voicePhase: VoicePhase.failed,
        lastCommandMessage: '기존 음성 재생을 안전하게 멈추지 못했어요. 화면 안내를 확인해주세요.',
      );
      _speechRecoveryPhase = null;
      notifyListeners();
    }
  }

  void _stopSpeechInputWithoutWaiting() {
    unawaited(_queueSpeechInputStop().then<void>((_) {}));
  }

  Future<void> _stopVoiceSafely() async {
    await Future.wait<bool>(<Future<bool>>[
      _queueSpeechInputStop(),
      _queueSpeechOutputStop(),
    ]);
  }

  @override
  void dispose() {
    _isForeground = false;
    _foregroundRequestVersion += 1;
    _speechInputDesired = false;
    _speechInputReady = false;
    _speechLifecycleVersion += 1;
    _voiceOperationVersion += 1;
    _disposed = true;
    unawaited(_alarm.cancelScheduledAlarm());
    _timer
      ..removeListener(_handleTimerChanged)
      ..dispose();
    unawaited(_stopVoiceSafely());
    super.dispose();
  }
}
