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
        '타이머 시작은 하지 마',
        '조리 시작만 하지 마',
        '시간 재기는 절대 안 해',
        '타이머 시작이라도 하지 마',
        '타이머 시작을 금지',
      ]) {
        expect(
          routeOf(command),
          const VoiceIntent(VoiceIntentType.ignore),
          reason: command,
        );
      }

      expect(
        routeOf('타이머 시작만 하고 재료 손질은 안 해'),
        const VoiceIntent(VoiceIntentType.startTimer),
      );
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
        '조리 완료만 하지 마',
        '요리 끝만 내지 마',
        '조리 완료라도 하지 마',
        '조리 완료를 하지 마',
        '조리 완료하지 못했어',
        '조리 완료 금지',
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

    test('routes contextual questions to the coach', () {
      const questions = [
        '지금 불 줄여야 할까?',
        '불이 너무 센 것 같아?',
        '간이 맞아?',
        '팬이 너무 뜨거워?',
        '팬은요?',
        '고기 다 익었어?',
        '소스가 묽은데 어떻게 해야 해?',
        '토마토는 얼마나 더 익혀?',
        '마늘 더 넣는 게 맞아?',
        '면 얼마나 더 삶아야 해?',
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

    test('keeps single-character ingredient words as cooking context', () {
      final waterQuestion = router.route(
        '물 더 넣어야 해?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '약불에서 익힌다',
      );
      expect(
        waterQuestion,
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );

      // 단어 경계: '물어봐도 돼?'의 '물'은 재료 단어가 아니다.
      final lexicalWater = router.route(
        '물어봐도 돼?',
        recipeTitle: '밥',
        ingredientNames: const ['물', '쌀', '파'],
        currentStepInstruction: '약불에서 익힌다',
      );
      expect(lexicalWater, const VoiceIntent(VoiceIntentType.ignore));
    });
  });

  group('CookingVoiceRouter coach gate problems', () {
    test('routes problem statements without question wording', () {
      const problems = [
        '물이 아직 안 끓어',
        '국이 너무 짜',
        '맛이 짜',
        '국물이 짜졌어',
        '소스가 짜더라',
        '국이 짠 것 같아',
        '고기가 덜 익었어',
        '면이 안 익어',
        '소스가 너무 묽어',
        '양파가 좀 탔네',
        '재료가 없어',
        '양파가 다 떨어졌어',
        '양파를 다 썼어',
      ];

      for (final problem in problems) {
        expect(
          routeOf(problem),
          const VoiceIntent(VoiceIntentType.exceptionQuestion),
          reason: problem,
        );
      }
    });

    test('routes kitchen safety statements', () {
      const safetyProblems = [
        '기름에 불 붙었어',
        '가스 냄새가 나',
        '재료에 곰팡이가 있어',
        '닭이 안 익었어',
        '칼에 손을 베였어',
        '생고기를 먹었어',
        '생고기를 먹어도 돼?',
        '생고기가 위험해',
      ];

      for (final problem in safetyProblems) {
        expect(
          routeOf(problem),
          const VoiceIntent(VoiceIntentType.exceptionQuestion),
          reason: problem,
        );
      }
    });

    test('leaves precise judgement to the backend coach', () {
      // 게이트는 애매하면 보낸다 — 판정 본체는 서버가 소유하고, 여기서 오탐의
      // 비용은 코치 호출 1번이다. 아래는 허용하기로 한 대표 오탐의 기록이다.
      const acceptedFalsePositives = ['이번 주 요리 계획을 짜', '고객 불만 줄여야 할까?'];

      for (final statement in acceptedFalsePositives) {
        expect(
          routeOf(statement),
          const VoiceIntent(VoiceIntentType.exceptionQuestion),
          reason: statement,
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
        '불이익은요?',
        '팬클럽은요?',
        '이불의 세기 괜찮아?',
      ];

      for (final question in unrelatedQuestions) {
        expect(
          routeOf(question),
          const VoiceIntent(VoiceIntentType.ignore),
          reason: question,
        );
      }
    });

    test('ignores lexical salty words but keeps real salty reports', () {
      const statements = [
        '음식이 짜장면이야',
        '요리가 짜릿해',
        '음식 때문에 짜증나',
        '그 영화가 너무 짠해',
        '그 사람은 좀 짠돌이야',
        '날짜 좀 알려줘',
        '짜임새가 좀 좋아',
        '진짜',
        '가짜',
      ];

      for (final statement in statements) {
        expect(
          routeOf(statement),
          const VoiceIntent(VoiceIntentType.ignore),
          reason: statement,
        );
      }

      // 블록 어휘를 걷어낸 뒤 남는 짠맛 신호는 살아 있어야 한다.
      expect(
        routeOf('국물이 진짜 짜'),
        const VoiceIntent(VoiceIntentType.exceptionQuestion),
      );
    });

    test('ignores cooking statements that do not describe a problem', () {
      const statements = [
        '소스 좀 더 넣었어',
        '양파를 다 썰었어',
        '물이 끓어',
        '다 됐다 이제',
        '다음 주에 장 보러 가자',
        '오늘 시간이 없어',
      ];

      for (final statement in statements) {
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
