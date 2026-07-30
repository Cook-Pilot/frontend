import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/cooking_fakes.dart';

void main() {
  const recipe = Recipe(
    id: '10000000-0000-0000-0000-000000000006',
    title: '음성 조리 테스트 레시피',
    description: '음성 명령 통합 흐름을 검증한다.',
    baseServings: 2,
    imageUrl: '',
    ingredients: <Ingredient>[
      Ingredient(name: '물', amount: 500, unit: 'ml', isRequired: true),
    ],
    steps: <CookStep>[
      CookStep(
        stepIndex: 0,
        instruction: '재료를 준비하세요.',
        timerSeconds: null,
        cautionNote: null,
        imageUrl: '',
      ),
      CookStep(
        stepIndex: 1,
        instruction: '물을 2분간 끓이세요.',
        timerSeconds: 120,
        cautionNote: null,
        imageUrl: '',
      ),
      CookStep(
        stepIndex: 2,
        instruction: '불을 끄고 마무리하세요.',
        timerSeconds: 60,
        cautionNote: null,
        imageUrl: '',
      ),
    ],
    hasPersonalVersion: false,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpSession(
    WidgetTester tester, {
    required FakeSpeechInput speechInput,
    ExceptionAdvicePort? advicePort,
    Recipe testRecipe = recipe,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CookSessionScreen(
          recipe: testRecipe,
          servings: 2,
          alarm: const SilentTimerAlarm(),
          advicePort: advicePort,
          speechInput: speechInput,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapVoiceButton(WidgetTester tester) async {
    final button = find.byKey(const Key('voice-input-toggle'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('권한 실패 상태를 표시하고 직접 입력 질문은 계속 처리한다', (tester) async {
    final speech = FakeSpeechInput();
    final advice = FakeExceptionAdvicePort();
    await pumpSession(tester, speechInput: speech, advicePort: advice);

    expect(find.text('직접 입력'), findsOneWidget);
    await tapVoiceButton(tester);
    expect(speech.startCount, 1);
    expect(find.text('듣는 중'), findsOneWidget);

    speech.emitFailure(SpeechInputFailure.permissionDenied);
    await tester.pump();
    expect(find.text('마이크 권한 필요'), findsOneWidget);
    expect(find.textContaining('직접 입력으로 질문'), findsOneWidget);

    final fallback = find.byKey(const Key('help-request'));
    await tester.ensureVisible(fallback);
    await tester.tap(fallback);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('help-question-field')),
      '물이 안 끓어요',
    );
    await tester.tap(find.byKey(const Key('help-question-submit')));
    await tester.pumpAndSettle();

    expect(advice.requests.single.utterance, '물이 안 끓어요');
    expect(find.textContaining('30초'), findsOneWidget);
  });

  testWidgets('한 듣기 세션의 첫 문장만 처리하고 stop 뒤 늦은 콜백은 버린다', (tester) async {
    final speech = FakeSpeechInput();
    await pumpSession(tester, speechInput: speech);

    await tapVoiceButton(tester);
    final firstHandler = speech.utteranceHandlers.single;
    firstHandler('다음 단계', 'utterance-1');
    await tester.pump();
    expect(find.text('2 / 3 단계'), findsOneWidget);

    // 같은 네이티브 세션이 결과를 다시 보내도 한 단계 더 이동하지 않는다.
    firstHandler('다음 단계', 'utterance-1-duplicate');
    await tester.pump();
    expect(find.text('2 / 3 단계'), findsOneWidget);

    await tapVoiceButton(tester);
    final secondHandler = speech.utteranceHandlers.last;
    await tapVoiceButton(tester);
    expect(speech.stopCount, greaterThanOrEqualTo(1));

    // 사용자가 듣기를 중지한 뒤 도착한 결과도 새 단계에 반영하지 않는다.
    secondHandler('다음 단계', 'utterance-2');
    await tester.pump();
    expect(find.text('2 / 3 단계'), findsOneWidget);
  });

  testWidgets('타이머 없는 단계는 명령을 막고 타이머 단계에서는 로컬로 즉시 실행한다', (tester) async {
    final speech = FakeSpeechInput();
    await pumpSession(tester, speechInput: speech);

    await tapVoiceButton(tester);
    speech.emitUtterance('타이머 시작', utteranceId: 'timerless');
    await tester.pump();
    expect(find.textContaining('설정된 타이머가 없어요'), findsOneWidget);
    expect(find.text('타이머 없음'), findsOneWidget);

    await tapVoiceButton(tester);
    speech.emitUtterance('다음 단계', utteranceId: 'next');
    await tester.pump();
    await tapVoiceButton(tester);
    speech.emitUtterance('타이머 시작', utteranceId: 'timer-start');
    await tester.pump();
    expect(find.text('일시정지'), findsOneWidget);

    await tapVoiceButton(tester);
    speech.emitUtterance('2분 추가', utteranceId: 'timer-extend');
    await tester.pump();
    expect(find.textContaining('타이머에 2분을 추가했어요'), findsOneWidget);

    await tapVoiceButton(tester);
    speech.emitUtterance('타이머 일시정지', utteranceId: 'timer-pause');
    await tester.pump();
    expect(find.text('계속'), findsOneWidget);

    await tapVoiceButton(tester);
    speech.emitUtterance('타이머 재개', utteranceId: 'timer-resume');
    await tester.pump();
    expect(find.text('일시정지'), findsOneWidget);
  });

  testWidgets('조리 예외 질문만 조언 포트로 보내고 일반 문장은 보내지 않는다', (tester) async {
    final speech = FakeSpeechInput();
    final advice = FakeExceptionAdvicePort();
    await pumpSession(tester, speechInput: speech, advicePort: advice);

    await tapVoiceButton(tester);
    speech.emitUtterance('오늘 날씨 어때', utteranceId: 'ignored');
    await tester.pump();
    expect(advice.requests, isEmpty);
    expect(find.textContaining('명령을 이해하지 못했어요'), findsOneWidget);

    await tapVoiceButton(tester);
    speech.emitUtterance('물이 안 끓어요', utteranceId: 'question');
    await tester.pumpAndSettle();
    expect(advice.requests.single.utterance, '물이 안 끓어요');
    expect(advice.requests.single.stepIndex, 0);
  });

  testWidgets('백그라운드 진입 시 마이크를 멈추고 이전 콜백을 무효화한다', (tester) async {
    final speech = FakeSpeechInput();
    await pumpSession(tester, speechInput: speech);

    await tapVoiceButton(tester);
    final staleHandler = speech.utteranceHandlers.single;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(speech.stopCount, greaterThanOrEqualTo(1));
    staleHandler('다음 단계', 'stale-after-pause');
    await tester.pump();
    expect(find.text('1 / 3 단계'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('마지막 단계의 다음 명령은 막고 완료 명령은 후기 화면으로 한 번만 이동한다', (tester) async {
    final speech = FakeSpeechInput();
    const oneStepRecipe = Recipe(
      id: '10000000-0000-0000-0000-000000000007',
      title: '한 단계 레시피',
      description: '완료 경계를 검증한다.',
      baseServings: 1,
      imageUrl: '',
      ingredients: <Ingredient>[],
      steps: <CookStep>[
        CookStep(
          stepIndex: 0,
          instruction: '마무리하세요.',
          timerSeconds: null,
          cautionNote: null,
          imageUrl: '',
        ),
      ],
      hasPersonalVersion: false,
    );
    await pumpSession(tester, speechInput: speech, testRecipe: oneStepRecipe);

    await tapVoiceButton(tester);
    speech.emitUtterance('다음 단계', utteranceId: 'last-next');
    await tester.pump();
    expect(find.textContaining('마지막 단계예요'), findsOneWidget);
    expect(find.byType(ReviewScreen), findsNothing);

    await tapVoiceButton(tester);
    final finishHandler = speech.onUtterance!;
    finishHandler('조리 완료', 'finish');
    // 동일 완료 콜백이 한 번 더 와도 첫 전환에서 이미 무효화된다.
    finishHandler('조리 완료', 'finish-duplicate');
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsOneWidget);
  });
}
