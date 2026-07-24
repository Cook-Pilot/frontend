import 'package:flutter/foundation.dart';

enum CookingSessionStatus { ready, cooking, paused, review, completed, aborted }

enum VoicePhase {
  off,
  permissionDenied,
  starting,
  listening,
  recognizing,
  processing,
  speaking,
  retryRequired,
  failed,
}

enum TimerStatus { idle, running, paused, elapsed }

enum MediaLoadStatus { idle, loading, ready, failed }

@immutable
final class CookingUiState {
  const CookingUiState({
    required this.sessionId,
    required this.stepIndex,
    required this.sessionStatus,
    required this.voicePhase,
    required this.requestContextVersion,
    this.lastRecognizedUtterance,
    this.lastCommandMessage,
    this.exceptionFeedback,
  });

  static const _unset = Object();

  final String sessionId;
  final int stepIndex;
  final CookingSessionStatus sessionStatus;
  final VoicePhase voicePhase;
  final int requestContextVersion;
  final String? lastRecognizedUtterance;
  final String? lastCommandMessage;
  final String? exceptionFeedback;

  CookingUiState copyWith({
    int? stepIndex,
    CookingSessionStatus? sessionStatus,
    VoicePhase? voicePhase,
    int? requestContextVersion,
    Object? lastRecognizedUtterance = _unset,
    Object? lastCommandMessage = _unset,
    Object? exceptionFeedback = _unset,
  }) {
    return CookingUiState(
      sessionId: sessionId,
      stepIndex: stepIndex ?? this.stepIndex,
      sessionStatus: sessionStatus ?? this.sessionStatus,
      voicePhase: voicePhase ?? this.voicePhase,
      requestContextVersion:
          requestContextVersion ?? this.requestContextVersion,
      lastRecognizedUtterance: identical(lastRecognizedUtterance, _unset)
          ? this.lastRecognizedUtterance
          : lastRecognizedUtterance as String?,
      lastCommandMessage: identical(lastCommandMessage, _unset)
          ? this.lastCommandMessage
          : lastCommandMessage as String?,
      exceptionFeedback: identical(exceptionFeedback, _unset)
          ? this.exceptionFeedback
          : exceptionFeedback as String?,
    );
  }
}
