enum CookingCommand {
  previousStep,
  repeatInstruction,
  announceCurrentStep,
  addMinute,
  pauseTimer,
  resumeTimer,
  nextStep,
  completeSession,
  abortSession,
  unknown,
}

final class LocalCommandRouter {
  const LocalCommandRouter();

  CookingCommand route(String utterance) {
    final normalized = utterance.toLowerCase().replaceAll(
      RegExp(r'[\s,.!?~]+'),
      '',
    );

    if (normalized.contains('다시시작') || normalized.contains('타이머재개')) {
      return CookingCommand.resumeTimer;
    }
    if (normalized == '멈춰' ||
        normalized.contains('타이머멈') ||
        normalized.contains('일시정지')) {
      return CookingCommand.pauseTimer;
    }
    if (normalized.contains('1분더') ||
        normalized.contains('일분더') ||
        normalized.contains('1분추가')) {
      return CookingCommand.addMinute;
    }
    if (normalized.contains('다시말') || normalized.contains('다시읽')) {
      return CookingCommand.repeatInstruction;
    }
    if (normalized.contains('지금뭐') || normalized.contains('현재단계')) {
      return CookingCommand.announceCurrentStep;
    }
    if (normalized == '이전' ||
        normalized.contains('전단계') ||
        normalized.contains('이전단계')) {
      return CookingCommand.previousStep;
    }
    if (normalized == '다음' || normalized.contains('다음단계')) {
      return CookingCommand.nextStep;
    }
    return CookingCommand.unknown;
  }
}

extension CookingCommandLabel on CookingCommand {
  String get eventName => switch (this) {
    CookingCommand.previousStep => 'previous_step',
    CookingCommand.repeatInstruction => 'repeat_instruction',
    CookingCommand.announceCurrentStep => 'announce_current_step',
    CookingCommand.addMinute => 'add_minute',
    CookingCommand.pauseTimer => 'pause_timer',
    CookingCommand.resumeTimer => 'resume_timer',
    CookingCommand.nextStep => 'next_step',
    CookingCommand.completeSession => 'complete_session',
    CookingCommand.abortSession => 'abort_session',
    CookingCommand.unknown => 'unknown',
  };
}
