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

    test('rejects negated timer-start commands', () {
      for (final command in const [
        '타이머 시작하지 마',
        '타이머 켜지 마',
        '조리 시작하지 말아 줘',
        '요리 시작하지 않아',
      ]) {
        expect(
          routeOf(command),
          const VoiceIntent(VoiceIntentType.ignore),
          reason: command,
        );
      }
    });

    test('checks resume before repeat', () {
      expect(
        routeOf('다시 시작해서 계속해'),
        const VoiceIntent(VoiceIntentType.resumeTimer),
      );
    });

    test('keeps direct mutating commands local', () {
      expect(routeOf('요리 시작해'), const VoiceIntent(VoiceIntentType.startTimer));
      expect(routeOf('다음 단계로 가줘'), const VoiceIntent(VoiceIntentType.next));
      expect(
        routeOf('1분 더 해줘'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 60),
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

    test('adds mixed minute and second units before applying bounds', () {
      expect(
        routeOf('1분 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 90),
      );
      expect(
        routeOf('30초 1분 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 90),
      );
      expect(
        routeOf('한 분 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 90),
      );
      expect(
        routeOf('9분 59초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 599),
      );
      expect(
        routeOf('10분 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 600),
      );
      expect(
        routeOf('0분 5초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 15),
      );
    });

    test('parses only durations attached to an extension clause', () {
      expect(
        routeOf('타이머 5분인데 1분 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 60),
      );
      expect(
        routeOf('타이머 5분인데 1분 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 90),
      );
      expect(
        routeOf('타이머 5분인데 더 1분'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 60),
      );
      expect(
        routeOf('1분 더하고 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 90),
      );
      expect(
        routeOf('1분 더 말고 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 30),
      );
      expect(
        routeOf('1분 더, 그건 말고 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 30),
      );
      expect(
        routeOf('1분 더 해줘. 그건 말고 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 30),
      );
      expect(
        routeOf('1분 더하지 말고 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 30),
      );
      expect(
        routeOf('1분 더 대신 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 30),
      );
      expect(
        routeOf('1분 더하는 대신 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 30),
      );
      expect(
        routeOf('1분 추가 대신 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 30),
      );
      expect(
        routeOf('1분 더 연장하는 대신 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 30),
      );
      expect(
        routeOf('1분 더 추가하는 대신 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 30),
      );
      expect(
        routeOf('1분 더, 아니 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 30),
      );
      expect(
        routeOf('1분 더 해줘. 아니, 30초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 30),
      );
      expect(
        routeOf('1분 더, 아니 30초 더, 아니 45초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 45),
      );
      expect(
        routeOf('1분 추가 취소하고 45초만 연장'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 45),
      );
      expect(routeOf('1분 추가 취소'), const VoiceIntent(VoiceIntentType.ignore));
      expect(routeOf('1분 더하지 마'), const VoiceIntent(VoiceIntentType.ignore));
      expect(
        routeOf('1분 더 말고 30초도 추가하지 마'),
        const VoiceIntent(VoiceIntentType.ignore),
      );
      expect(
        routeOf('1분 추가할까 했지만 안 할게'),
        const VoiceIntent(VoiceIntentType.ignore),
      );
      expect(
        routeOf('1분 더 추가할까 했지만 안 할게'),
        const VoiceIntent(VoiceIntentType.ignore),
      );
      expect(
        routeOf('1분 더, 취소하지 마'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 60),
      );
      expect(
        routeOf('1분 더하고 취소는 안 해'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 60),
      );
      expect(
        routeOf('추가로 1분'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 60),
      );
    });

    test('keeps extensions before unrelated replacement clauses', () {
      for (final command in const [
        '1분 더 하고 소금 말고 후추 넣어',
        '1분 더하고 양파 대신 마늘 넣어',
        '1분 더 하고 재료 준비 취소했어',
        '1분 더 하고 소금, 아니 후추 넣어',
        '1분 더 하고 소금 추가 말고 후추 넣어',
      ]) {
        expect(
          routeOf(command),
          const VoiceIntent(VoiceIntentType.extendTimer, seconds: 60),
          reason: command,
        );
      }
    });

    test('replaces only the immediately competing timer extension', () {
      expect(
        routeOf('1분 더하고 30초 더 말고 45초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 105),
      );
      expect(
        routeOf('1분 더하고 30초 더, 아니 45초 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 105),
      );
    });

    test('requires a lexical boundary after timer extension signals', () {
      expect(
        routeOf('1분 더해줘'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 60),
      );
      expect(
        routeOf('1분 더요'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 60),
      );
      expect(
        routeOf('1분 연장요'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 60),
      );
      expect(routeOf('1분 더덕을 볶아'), const VoiceIntent(VoiceIntentType.ignore));
      expect(routeOf('1분 건더기를 건져'), const VoiceIntent(VoiceIntentType.ignore));
    });

    test('matches complete Korean minute quantities', () {
      expect(
        routeOf('타이머 두 분 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 120),
      );
      expect(
        routeOf('십이 분 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 600),
      );
      expect(
        routeOf('십일 분 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 600),
      );
      expect(
        routeOf('이십 분 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 600),
      );
      expect(
        routeOf('십 이 분 더'),
        const VoiceIntent(VoiceIntentType.extendTimer, seconds: 600),
      );
      expect(routeOf('열두 분 더'), const VoiceIntent(VoiceIntentType.ignore));
      expect(routeOf('열 두 분 더'), const VoiceIntent(VoiceIntentType.ignore));
      expect(routeOf('스물 세 분 더'), const VoiceIntent(VoiceIntentType.ignore));
      expect(routeOf('백이 분 더'), const VoiceIntent(VoiceIntentType.ignore));
      expect(routeOf('백 이 분 더'), const VoiceIntent(VoiceIntentType.ignore));
    });

    test('explicit whole-cook completion wins over a step-level cue', () {
      expect(
        routeOf('조리 완료, 이제 됐어'),
        const VoiceIntent(VoiceIntentType.finish),
      );
    });

    test('requires whole-cook context for generic completion phrases', () {
      expect(routeOf('완료했어'), const VoiceIntent(VoiceIntentType.finish));
      expect(routeOf('요리 완성했어요'), const VoiceIntent(VoiceIntentType.finish));
      expect(routeOf('요리는 완료했어'), const VoiceIntent(VoiceIntentType.finish));
      expect(routeOf('조리가 완료됐어'), const VoiceIntent(VoiceIntentType.finish));
      expect(routeOf('조리 완료됐다고 했어'), const VoiceIntent(VoiceIntentType.finish));
      expect(routeOf('조리 끝났다고 했어'), const VoiceIntent(VoiceIntentType.finish));
      expect(
        routeOf('조리 완료됐다는 말을 들었어'),
        const VoiceIntent(VoiceIntentType.finish),
      );

      for (final negatedCompletion in const [
        '조리 완료하지 마',
        '요리 끝내지 마',
        '조리 완료는 아직 안 했어',
        '조리 끝난 건 아니야',
        '조리 완료라고 한 건 아니야',
        '조리 완료가 된 건 아니야',
        '조리 완료됐다고 한 건 아니야',
        '요리 완성했다고 한 건 아니야',
        '조리 완료되었다고 한 건 아니야',
        '조리 끝났다고 한 건 아니야',
        '조리 완료됐다는 말은 아니야',
        '조리 완료됐다는 말이 아니야',
        '조리 완료됐다고 했던 건 아니야',
        '조리 완료됐다고 말했던 건 아니야',
      ]) {
        expect(
          routeOf(negatedCompletion),
          const VoiceIntent(VoiceIntentType.ignore),
          reason: negatedCompletion,
        );
      }

      for (final partialCompletion in const [
        '재료 손질 완료했어',
        '타이머 설정 완료했어',
        '양파 손질 완료했어',
        '재료 손질이 다 끝났어',
        '타이머 설정이 전부 끝났어',
      ]) {
        expect(
          routeOf(partialCompletion),
          const VoiceIntent(VoiceIntentType.ignore),
          reason: partialCompletion,
        );
      }
    });
  });

  group('CookingVoiceRouter contextual questions', () {
    test('routes tentative mutating commands to the coach', () {
      const questions = ['요리 시작해도 돼?', '다음 단계로 가도 돼?', '1분 더 해도 돼?'];

      for (final question in questions) {
        expect(
          routeOf(question),
          const VoiceIntent(VoiceIntentType.exceptionQuestion),
          reason: question,
        );
      }

      expect(
        routeOf('지금 뭐 해야 해?'),
        const VoiceIntent(VoiceIntentType.currentStep),
      );
      expect(routeOf('오늘 시작해도 돼?'), const VoiceIntent(VoiceIntentType.ignore));
      expect(routeOf('다음 주에 가도 돼?'), const VoiceIntent(VoiceIntentType.ignore));
    });

    test('routes tentative completion questions to the coach', () {
      const questions = ['조리 완료해도 돼?', '요리 끝내도 되나요?', '조리 완료인가?'];

      for (final question in questions) {
        expect(
          routeOf(question),
          const VoiceIntent(VoiceIntentType.exceptionQuestion),
          reason: question,
        );
      }
    });

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
        '불이 너무 센 것 같아?',
        '불로 조절해도 돼?',
        '불의 세기 괜찮아?',
        '불의세기 괜찮아?',
        '지금 불의세기 괜찮아?',
        '지금불의세기괜찮아?',
        '불의 강도를 줄여야 할까?',
        '불만 줄여야 할까?',
        '불만줄여야 할까?',
        '불인가요?',
        '불일까요?',
        '간이 맞아?',
        '팬이 너무 뜨거워?',
        '팬에서 계속 구워도 돼?',
        '팬으로는 괜찮아?',
        '팬이면 괜찮아?',
        '팬이어도 괜찮아?',
        '팬은요?',
        '팬에서요?',
        '팬에서는요?',
        '팬에서라도요?',
        '팬에서라도 계속 구워도 돼?',
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

    test('recognizes an exact single-token recipe title', () {
      final result = router.route(
        '비빔밥 어떻게 해?',
        recipeTitle: '비빔밥',
        ingredientNames: const ['고추장', '나물'],
        currentStepInstruction: '재료를 섞는다',
      );

      expect(result, const VoiceIntent(VoiceIntentType.exceptionQuestion));
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
      final waterMethodQuestion = router.route(
        '물로 농도 맞춰도 돼?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '약불에서 익힌다',
      );
      final waterPoliteQuestion = router.route(
        '물로요?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '약불에서 익힌다',
      );
      final waterAuxiliaryChainQuestion = router.route(
        '물로만은요?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '약불에서 익힌다',
      );
      final greenOnionAlsoQuestion = router.route(
        '파도 넣어야 해?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );
      final greenOnionPrepQuestion = router.route(
        '파도 썰어 넣을까?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );
      final joinedGreenOnionAlsoQuestion = router.route(
        '파도넣어야 해?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );
      final joinedPrefixedGreenOnionAlsoQuestion = router.route(
        '지금파도넣어야해?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );
      final joinedGreenOnionQuantityQuestion = router.route(
        '파몇개?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );

      expect(
        waterQuestion,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(riceProblem, const VoiceIntent(VoiceIntentType.exceptionQuestion));
      expect(
        waterMethodQuestion,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(
        waterPoliteQuestion,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(
        waterAuxiliaryChainQuestion,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(
        greenOnionAlsoQuestion,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(
        greenOnionPrepQuestion,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(
        joinedGreenOnionAlsoQuestion,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(
        joinedPrefixedGreenOnionAlsoQuestion,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(
        joinedGreenOnionQuantityQuestion,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
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

    test('disambiguates multi-syllable ingredient homonyms', () {
      VoiceIntent routeWithEggplant(String transcript) {
        return router.route(
          transcript,
          recipeTitle: '채소 볶음',
          ingredientNames: const ['가지', '양파'],
          currentStepInstruction: '팬을 달군다',
        );
      }

      for (final unrelatedQuestion in const [
        '오늘 어떻게 집에 가지?',
        '휴가를 어디로 가지?',
        '오늘은 집에 가지는 않아?',
        '이번엔 학교에 가지도 않아?',
      ]) {
        expect(
          routeWithEggplant(unrelatedQuestion),
          const VoiceIntent(VoiceIntentType.ignore),
          reason: unrelatedQuestion,
        );
      }

      for (final cookingQuestion in const [
        '가지는 얼마나 익혀?',
        '가지를 더 넣어도 돼?',
        '가지 어떻게 썰어?',
        '가지가 없어',
        '가지는요?',
        '양파는 몇 개 넣어?',
        '양파는 몇 개?',
        '양파 몇 개?',
        '양파몇개?',
      ]) {
        expect(
          routeWithEggplant(cookingQuestion),
          const VoiceIntent(VoiceIntentType.exceptionQuestion),
          reason: cookingQuestion,
        );
      }

      final recipeTitleHomonym = router.route(
        '오늘 어떻게 집에 가지?',
        recipeTitle: '가지 볶음',
        ingredientNames: const ['양파'],
        currentStepInstruction: '팬을 달군다',
      );
      expect(recipeTitleHomonym, const VoiceIntent(VoiceIntentType.ignore));

      final fullRecipeTitle = router.route(
        '토마토 파스타 어떻게 해?',
        recipeTitle: '토마토 파스타',
        ingredientNames: const ['양파'],
        currentStepInstruction: '팬을 달군다',
      );
      expect(
        fullRecipeTitle,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
    });

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
        '맛이 짜',
        '국이 짜구나',
        '국물이 뭔가 짜',
        '소스가 뭔가 좀 짜',
        '국이 짭니다',
        '국이 짭니다만',
        '국이 짭니까?',
        '국물이 짜졌어',
        '국물이 짜졌습니다',
        '국물이 짜졌습니까?',
        '소스가 짜더라',
        '소스가 짜던데',
        '소스가 짜던데요',
        '국이 짜더니',
        '소스가 짜대요',
        '국물이 짜다고 느껴',
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

    test('associates missing predicates with their ingredient clause', () {
      expect(
        routeOf('양파를 넣었는데 시간이 없어'),
        const VoiceIntent(VoiceIntentType.ignore),
      );
      expect(
        routeOf('양파가 다 떨어졌어'),
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(
        routeOf('양파를 다 썼어'),
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(
        routeOf('양파를 다 사용했어'),
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(
        routeOf('소스가 맛있는데 시간이 없어'),
        const VoiceIntent(VoiceIntentType.ignore),
      );
    });

    test('uses recipe ingredients as explicit salty subjects', () {
      final saltyKimchi = router.route(
        '김치가 짜',
        recipeTitle: '김치찌개',
        ingredientNames: const ['김치', '두부'],
        currentStepInstruction: '김치와 두부를 끓인다',
      );
      final lexicalKimchi = router.route(
        '김치가 짜임새가 좀 좋아',
        recipeTitle: '김치찌개',
        ingredientNames: const ['김치', '두부'],
        currentStepInstruction: '김치와 두부를 끓인다',
      );
      final stackedParticleKimchi = router.route(
        '김치만은 짜',
        recipeTitle: '김치찌개',
        ingredientNames: const ['김치', '두부'],
        currentStepInstruction: '김치와 두부를 끓인다',
      );
      final attributiveKimchi = router.route(
        '김치가 짠 반찬이야',
        recipeTitle: '김치찌개',
        ingredientNames: const ['김치', '두부'],
        currentStepInstruction: '김치와 두부를 끓인다',
      );

      expect(saltyKimchi, const VoiceIntent(VoiceIntentType.exceptionQuestion));
      expect(
        stackedParticleKimchi,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(
        attributiveKimchi,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(lexicalKimchi, const VoiceIntent(VoiceIntentType.ignore));
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

    test('requires an unsafe predicate for raw meat statements', () {
      for (final problem in const [
        '생고기를 먹었어',
        '고기를 생으로 먹었어',
        '생고기가 덜 익었어',
        '생고기가 위험해',
        '생고기를 못 익혀서 먹었어',
        '생고기를 안 다 익힌 뒤 먹었어',
        '생고기를 덜 익힌 뒤 먹었어',
        '생고기를 먹은 적 없지만 오늘 먹었어',
        '생고기를 안 먹으려 했지만 결국 먹었어',
        '생고기를 익혀야 했지만 그냥 먹었어',
        '생고기를 구운 줄 알고 먹었어',
        '생고기를 익힌 줄 착각하고 먹었어',
        '생고기를 조리한 것으로 알고 먹었어',
        '생고기를 익힌 셈 치고 먹었어',
        '익힌 걸로 생각하고 먹었어',
        '익힌 줄로 알고 먹었어',
        '생고기를 먹으려 해',
        '생고기를 먹어도 돼?',
        '생고기를 먹으면 괜찮을까?',
        '생고기는 썰기만 하고 그대로 먹었어',
        '생고기를 양념했지만 익히지 않은 채 먹었어',
        '생고기를 익혀 먹었고 남은 생고기는 그대로 먹었어',
        '생고기를 아이가 먹었어',
        '생고기를 나는 먹었어',
        '생고기를 익혀 먹고 나머지는 그대로 먹었어',
      ]) {
        expect(
          routeOf(problem),
          const VoiceIntent(VoiceIntentType.exceptionQuestion),
          reason: problem,
        );
      }

      for (final ordinaryStep in const [
        '생고기를 넣었어',
        '생고기를 팬에 올렸어',
        '생고기를 먹기 좋게 썰었어',
        '생고기를 넣었어. 밥을 먹었어',
        '생고기를 넣었어, 그리고 밥을 먹었어',
        '생고기를 넣었고 밥을 먹었어',
        '생고기를 냉장고에 넣고 밥을 먹었어',
        '생고기를 손질했고 아이는 과자를 먹었어',
        '생고기를 먹지 말고 완전히 익힌 뒤 먹었어',
        '생고기를 먹으려다 그만뒀어',
        '생고기를 익혀 먹으려 했지만 결국 안 먹었어',
        '생고기를 먹으려 했지만 결국 안 먹었어',
        '생고기를 먹으려다가 결국 안 먹었어',
        '생고기를 먹었다고 한 건 아니야',
        '“생고기를 먹었어”라는 말은 사실이 아니야',
        '“생고기를 먹었어.”라는 말은 사실이 아니야',
        '생고기를 익혀 먹었어',
        '생고기를 구워서 먹었어',
        '생고기를 익혀서 먹었어',
        '생고기를 볶아서 먹었어',
        '생고기를 다 익힌 뒤 먹었어',
        '생고기를 완전히 익힌 다음에 먹었어',
        '생고기를 안 먹었어',
        '생고기를 먹은 적이 없어',
        '생고기를 먹은 건 아니야',
        '생고기를 먹은 적이 전혀 없어',
        '생고기를 먹은 적이 한 번도 없어',
        '생고기를 먹은 건 절대 아니야',
        '고기를 생으로 안 먹었어',
        '생고기가 위험하지 않아',
        '익힌 셈 치고 밥을 먹었어',
      ]) {
        expect(
          routeOf(ordinaryStep),
          const VoiceIntent(VoiceIntentType.ignore),
          reason: ordinaryStep,
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
        '인간관계가 어때?',
        '불가능한 일인데 어때?',
        '불이익은 어때?',
        '팬클럽은 어때?',
        '불의의 사고는 어때?',
        '불이익은요?',
        '팬클럽은요?',
        '불의의 사고는요?',
        '불의 세상은 어때?',
        '고객 불만 줄여야 할까?',
        '고객불만줄여야 할까?',
        '이불의 세기 괜찮아?',
        '불이익만은요?',
        '불만은요?',
        '불과 몇 분 차이야?',
        '불의는 어때?',
      ];

      for (final question in unrelatedQuestions) {
        expect(
          routeOf(question),
          const VoiceIntent(VoiceIntentType.ignore),
          reason: question,
        );
      }
    });

    test('does not parse lexical 짜 and 짠 prefixes as taste predicates', () {
      for (final statement in const [
        '음식이 짜장면이야',
        '요리가 짜릿해',
        '음식 때문에 짜증나',
        '그 영화가 너무 짠해',
        '그 사람은 좀 짠돌이야',
        '날짜 좀 알려줘',
        '짜임새가 좀 좋아',
      ]) {
        expect(
          routeOf(statement),
          const VoiceIntent(VoiceIntentType.ignore),
          reason: statement,
        );
      }
    });

    test('requires food context for degree-marked salty statements', () {
      expect(
        routeOf('국이 너무 짜'),
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      final recipeProblem = router.route(
        '토마토 파스타가 너무 짜',
        recipeTitle: '토마토 파스타',
        ingredientNames: const ['면'],
        currentStepInstruction: '면을 삶는다',
      );
      expect(
        recipeProblem,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
      expect(routeOf('월급이 너무 짜'), const VoiceIntent(VoiceIntentType.ignore));
      expect(routeOf('회사 복지가 좀 짜'), const VoiceIntent(VoiceIntentType.ignore));
    });

    test('does not parse lexicalized one-letter words as cooking context', () {
      final waveQuestion = router.route(
        '파도는 어때?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );
      final waveSubjectQuestion = router.route(
        '파도가 얼마나 높아?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );
      final waveOnlyQuestion = router.route(
        '파도만 보여?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );
      final joinedWaveQuantityQuestion = router.route(
        '파도몇개야?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );
      final fileQuestion = router.route(
        '파일까요?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );
      final diggingQuestion = router.route(
        '땅을 파면 뭐가 나와?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );
      final waveCookingVerbWithoutIngredient = router.route(
        '파도 넣어야 해?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀'],
        currentStepInstruction: '쌀을 씻는다',
      );
      final wavePhotoQuestion = router.route(
        '파도 사진 넣어야 해?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );
      final prefixedWaveCookingVerb = router.route(
        '사진에 파도 넣어야 해?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );
      final joinedPrefixedWaveCookingVerb = router.route(
        '사진에파도넣어야 해?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '쌀을 씻는다',
      );

      expect(waveQuestion, const VoiceIntent(VoiceIntentType.ignore));
      expect(waveSubjectQuestion, const VoiceIntent(VoiceIntentType.ignore));
      expect(waveOnlyQuestion, const VoiceIntent(VoiceIntentType.ignore));
      expect(
        joinedWaveQuantityQuestion,
        const VoiceIntent(VoiceIntentType.ignore),
      );
      expect(fileQuestion, const VoiceIntent(VoiceIntentType.ignore));
      expect(diggingQuestion, const VoiceIntent(VoiceIntentType.ignore));
      expect(
        waveCookingVerbWithoutIngredient,
        const VoiceIntent(VoiceIntentType.ignore),
      );
      expect(wavePhotoQuestion, const VoiceIntent(VoiceIntentType.ignore));
      expect(
        prefixedWaveCookingVerb,
        const VoiceIntent(VoiceIntentType.ignore),
      );
      expect(
        joinedPrefixedWaveCookingVerb,
        const VoiceIntent(VoiceIntentType.ignore),
      );
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
        '내일 일정을 좀 짜줘',
        '내일 일정 좀 짜줘',
        '내일 일정을 조금 짜줘',
        '내일 일정을 약간 더 구체적으로 짜줘',
        '내일 일정좀 짜줘',
        '내일일정을좀짜줘',
        '내일 계획조금 짜줘',
        '내일계획을약간짜줘',
        '내일일정을빠르게좀짜줘',
        '내일일정을빠르게좀짜',
        '내일계획을아주빠르게조금짜',
        '내일 일정 빠르게 짜줘',
        '일정을 고객 회의와 이동 시간을 충분히 고려해서 조금 여유 있게 짜줘',
        '일정을 진짜 좀 잘 짜줘',
        '일정을 진짜로 좀 잘 짜줘',
        '계획을 진짜 약간 여유 있게 짜줘',
        '조금 전에 짠 일정 보여줘',
        '조금 전에 짠 구체적인 주말 여행 계획 보여줘',
        '어제 짰던 계획 좀 바꿔줘',
        '어제 짰던 아주 장기적인 휴가 일정을 바꿔줘',
        '어제 계획을 좀 짰어',
        '조금 전에 짠 계획대로 해줘',
        '계획을 음식 취향에 맞춰 좀 짜줘',
        '계획을 음식 알레르기에 맞춰 약간 여유 있게 짜줘',
        '일정을 요리 수업 시간에 맞춰 조금 여유 있게 짜줘',
        '일정을 바꿔야 하는데 좀 새로 짜줘',
        '계획을 검토했는데 약간 더 구체적으로 짜줘',
        '일정을 짜고 좀 짜줘',
        '일정을 짜고 좀 다시 짜줘',
        '코드 좀 짜줘',
        '코드 좀 짜 줘',
        '문서 구조 좀 짜주세요',
        '기획서 좀 짜 주라',
        '내가 짠 코드가 좀 이상해',
        '다음 주 계획을 미리 다시 짜',
        '인간은 짠해',
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

    test('does not let a planning use hide a later salty problem', () {
      for (final statement in const [
        '일정을 미리 짜고 보니 국이 너무 짜',
        '일정을 정리하다 보니 소스가 약간 짜',
        '일정을 짜. 이거 너무 짜',
        '계획대로 국이 너무 짜',
        '계획대로 국 너무 짜',
        '계획대로 국물 약간 짜',
        '일정 얘기는 나중에 하고 이거 너무 짜',
        '일정은 나중에 보고 국 너무 짰어',
        '김치가 너무 짠데 계획은 그대로야',
        '김치가 너무 짠 데 계획은 그대로야',
        '소스가 약간 짜지만 일정은 바꾸지 마',
        '국물이 좀 짜고 계획은 나중에 세울게',
        '일정은 정리했는데 국물이 진짜 짜',
        '계획을 검토했지만 소스가 뭔가 짜',
        '국물이 일정하게 좀 짜',
        '일정한 간격으로 저었는데 국물이 좀 짜',
        '국이 짠 것 같아',
        '소스가 좀 짰어',
      ]) {
        expect(
          routeOf(statement),
          const VoiceIntent(VoiceIntentType.exceptionQuestion),
          reason: statement,
        );
      }
    });

    test('empty transcript is ignored', () {
      expect(routeOf(' \n\t '), const VoiceIntent(VoiceIntentType.ignore));
    });
  });
}
