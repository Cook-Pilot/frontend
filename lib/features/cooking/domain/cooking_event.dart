import 'package:flutter/foundation.dart';

enum CommandSource { voice, button, system }

@immutable
final class CookingEvent {
  const CookingEvent({
    required this.eventId,
    required this.sessionId,
    required this.recipeId,
    required this.recipeVersionId,
    required this.stepIndex,
    required this.source,
    required this.command,
    required this.occurredAt,
    required this.result,
    required this.contextVersion,
  });

  final String eventId;
  final String sessionId;
  final String recipeId;
  final String recipeVersionId;
  final int stepIndex;
  final CommandSource source;
  final String command;
  final DateTime occurredAt;
  final String result;
  final int contextVersion;
}
