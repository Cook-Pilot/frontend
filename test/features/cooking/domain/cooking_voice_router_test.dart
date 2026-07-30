import 'package:cookpilot/features/cooking/domain/cooking_voice_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const router = CookingVoiceRouter();

  VoiceIntent routeOf(String transcript) {
    return router.route(
      transcript,
      recipeTitle: '토마토 파스타',
      ingredientNames: const ['소스', '양파', '마늘', '면', '올리브유', '소금'],
      currentStepInstruction: '소스를 중불에서 끓이며 간을 맞춘다',
    );
  }

  group('CookingVoiceRouter local commands', () {
    test('routes step navigation and recall commands', () {
      expect(routeOf('다음 단계'), const VoiceIntent(VoiceIntentType.next));
      expect(routeOf('이전으로 돌아가'), const VoiceIntent(VoiceIntentType.previous));
      expect(routeOf('이전'), const VoiceIntent(VoiceIntentType.previous));
      expect(routeOf('다시 말해줘'), const VoiceIntent(VoiceIntentType.repeat));
      expect(
        routeOf('지금 뭐 해야 해?'),
        const VoiceIntent(VoiceIntentType.currentStep),
      );
    });

    test('routes timer lifecycle commands without external state', () {
      expect(routeOf('타이머 시작'), const VoiceIntent(VoiceIntentType.startTimer));
      expect(
        routeOf('타이머 잠깐 멈춰'),
        const VoiceIntent(VoiceIntentType.pauseTimer),
      );
      expect(
        routeOf('타이머 다시 시작'),
        const VoiceIntent(VoiceIntentType.resumeTimer),
      );
      expect(routeOf('재개'), const VoiceIntent(VoiceIntentType.resumeTimer));
    });

    test('checks resume before repeat', () {
      expect(
        routeOf('다시 시작해서 계속해'),
        const VoiceIntent(VoiceIntentType.resumeTimer),
      );
    });

    test('parses and bounds timer extensions', () {
      expect(
        routeOf('30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 30),
      );
      expect(
        routeOf('2분 추가'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 120),
      );
      expect(
        routeOf('삼분 더 연장해줘'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 180),
      );
      expect(
        routeOf('5초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 15),
      );
      expect(
        routeOf('30분 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 600),
      );
    });

    test('explicit whole-cook completion wins over a step-level cue', () {
      expect(
        routeOf('조리 완료, 이제 됐어'),
        const VoiceIntent(VoiceIntentType.finish),
      );
    });
  });

  group('CookingVoiceRouter contextual questions', () {
    test('question and cooking context win over substring commands', () {
      expect(
        routeOf('다음에 소금 넣는 게 맞아?'),
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(
        routeOf('몇 분 더 끓여야 돼?'),
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
    });

    test('recognizes static and recipe-specific cooking context', () {
      const questions = [
        '지금 불 줄여야 할까?',
        '고기 다 익었어?',
        '소스가 묽은데 어떻게 해야 해?',
        '토마토는 얼마나 더 익혀?',
        '마늘 더 넣는 게 맞아?',
      ];

      for (final question in questions) {
        expect(
          routeOf(question),
          const VoiceIntent(VoiceIntentType.exceptionQuestion),
          reason: question,
        );
      }
    });

    test('keeps one-character Korean ingredient names as cooking context', () {
      final waterQuestion = router.route(
        '물 더 넣어야 해?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '약불에서 익힌다',
      );
      final riceProblem = router.route(
        '쌀이 없어',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );

      expect(
        waterQuestion,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(riceProblem, const VoiceIntent(VoiceIntentType.exceptionQuestion));
    });

    test(
      'does not match a one-character ingredient inside an unrelated word',
      () {
        final partyQuestion = router.route(
          '파티 어때?',
          recipeTitle: '파전',
          ingredientNames: const ['파'],
          currentStepInstruction: '반죽을 섞는다',
        );

        expect(partyQuestion, const VoiceIntent(VoiceIntentType.ignore));
      },
    );

    test('does not mistake 진짜 for a salty problem', () {
      expect(
        routeOf('고기 진짜 익었어?'),
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
    });
  });

  group('CookingVoiceRouter explicit problem statements', () {
    test('routes cooking failures without requiring question wording', () {
      const problems = [
        '물이 아직 안 끓어',
        '국이 너무 짜',
        '고기가 덜 익었어',
        '면이 안 익어',
        '재료가 없어',
        '양파가 다 떨어졌어',
        '소스가 너무 묽어',
        '양파가 좀 탔네',
      ];

      for (final problem in problems) {
        expect(
          routeOf(problem),
          const VoiceIntent(VoiceIntentType.exceptionQuestion),
          reason: problem,
        );
      }
    });

    test('routes explicit kitchen safety patterns', () {
      const safetyProblems = [
        '기름에 불 붙었어',
        '가스 냄새가 나',
        '재료에 곰팡이가 있어',
        '닭이 안 익었어',
        '칼에 손을 베였어',
      ];

      for (final problem in safetyProblems) {
        expect(
          routeOf(problem),
          const VoiceIntent(VoiceIntentType.exceptionQuestion),
          reason: problem,
        );
      }
    });
  });

  group('CookingVoiceRouter false-positive boundaries', () {
    test('ignores questions without cooking context', () {
      const unrelatedQuestions = [
        '오늘 어떻게 집에 가지?',
        '이 노래 제목 뭐였지?',
        '오늘 왜 이렇게 피곤하지?',
      ];

      for (final question in unrelatedQuestions) {
        expect(
          routeOf(question),
          const VoiceIntent(VoiceIntentType.ignore),
          reason: question,
        );
      }
    });

    test('ignores cooking statements that do not describe a problem', () {
      const statements = ['소스 좀 더 넣었어', '양파를 다 썰었어', '물이 끓어'];

      for (final statement in statements) {
        expect(
          routeOf(statement),
          const VoiceIntent(VoiceIntentType.ignore),
          reason: statement,
        );
      }
    });

    test('keeps known substring false positives out of local commands', () {
      const falsePositives = [
        '진짜',
        '가짜',
        '이번 주 요리 계획을 짜',
        '오늘 시간이 없어',
        '다음 주에 장 보러 가자',
        '다 됐다 이제',
      ];

      for (final statement in falsePositives) {
        expect(
          routeOf(statement),
          const VoiceIntent(VoiceIntentType.ignore),
          reason: statement,
        );
      }
    });

    test('empty transcript is ignored', () {
      expect(routeOf(' \n\t '), const VoiceIntent(VoiceIntentType.ignore));
    });
  });
}
