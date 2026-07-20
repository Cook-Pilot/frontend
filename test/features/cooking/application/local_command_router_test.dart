import 'package:cookpilot/features/cooking/application/local_command_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const router = LocalCommandRouter();

  const cases = <String, CookingCommand>{
    '다음': CookingCommand.nextStep,
    '다음 단계로': CookingCommand.nextStep,
    '이전': CookingCommand.previousStep,
    '전 단계': CookingCommand.previousStep,
    '다시 말해줘': CookingCommand.repeatInstruction,
    '지금 뭐 해야 해?': CookingCommand.announceCurrentStep,
    '1분 더': CookingCommand.addMinute,
    '타이머 멈춰': CookingCommand.pauseTimer,
    '다시 시작': CookingCommand.resumeTimer,
  };

  for (final entry in cases.entries) {
    test('“${entry.key}”를 ${entry.value.name}으로 분류한다', () {
      expect(router.route(entry.key), entry.value);
    });
  }

  test('예외 질문은 unknown으로 남겨 LLM 포트에 위임한다', () {
    expect(router.route('물이 안 끓어'), CookingCommand.unknown);
  });
}
