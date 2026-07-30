import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:cookpilot/features/review/application/pending_review_draft_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/cooking_fakes.dart';

void main() {
  const recipe = Recipe(
    id: '10000000-0000-0000-0000-000000000001',
    title: '도움 질문 테스트 레시피',
    description: '도움 질문 흐름을 검증한다.',
    baseServings: 2,
    imageUrl: '',
    ingredients: <Ingredient>[],
    steps: <CookStep>[
      CookStep(
        stepIndex: 0,
        instruction: '물을 끓이세요.',
        timerSeconds: 180,
        cautionNote: '뜨거운 증기를 조심하세요.',
        imageUrl: '',
      ),
    ],
    hasPersonalVersion: false,
  );
  const twoStepRecipe = Recipe(
    id: '10000000-0000-0000-0000-000000000002',
    title: '단계 변경 테스트 레시피',
    description: '오래된 도움 답변을 검증한다.',
    baseServings: 2,
    imageUrl: '',
    ingredients: <Ingredient>[],
    steps: <CookStep>[
      CookStep(
        stepIndex: 0,
        instruction: '물을 끓이세요.',
        timerSeconds: 180,
        cautionNote: null,
        imageUrl: '',
      ),
      CookStep(
        stepIndex: 1,
        instruction: '면을 넣으세요.',
        timerSeconds: 120,
        cautionNote: null,
        imageUrl: '',
      ),
    ],
    hasPersonalVersion: false,
  );
  const timerlessRecipe = Recipe(
    id: '10000000-0000-0000-0000-000000000003',
    title: '타이머 없는 레시피',
    description: '타이머 행동 경계를 검증한다.',
    baseServings: 2,
    imageUrl: '',
    ingredients: <Ingredient>[],
    steps: <CookStep>[
      CookStep(
        stepIndex: 0,
        instruction: '재료를 섞으세요.',
        timerSeconds: null,
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
    required ExceptionAdvicePort advicePort,
    Recipe testRecipe = recipe,
    SpeechInputPort? speechInput,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CookSessionScreen(
          recipe: testRecipe,
          servings: 2,
          alarm: const SilentTimerAlarm(),
          advicePort: advicePort,
          speechInput: speechInput,
          pendingReviewDraftStore: _MemoryPendingReviewDraftStore(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> submitQuestion(WidgetTester tester, String question) async {
    await tester.scrollUntilVisible(find.byKey(const Key('help-request')), 200);
    await tester.tap(find.byKey(const Key('help-request')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('help-question-field')),
      question,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('help-question-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('도움 버튼은 질문 시트를 열고 현재 단계 맥락으로 답변을 표시한다', (tester) async {
    final advice = FakeExceptionAdvicePort();
    await pumpSession(tester, advicePort: advice);

    await submitQuestion(tester, '물이 안 끓어요');

    final context = advice.requests.single;
    expect(find.byKey(const Key('ai-data-disclosure')), findsOneWidget);
    expect(context.utterance, '물이 안 끓어요');
    expect(context.stepIndex, 0);
    expect(context.instruction, recipe.steps.first.description);
    expect(context.instruction, contains('주의: 뜨거운 증기를 조심하세요.'));
    expect(find.textContaining('30초'), findsOneWidget);
  });

  testWidgets('답변 요청 실패 시 폴백 안내를 표시한다', (tester) async {
    final advice = FakeExceptionAdvicePort()..error = StateError('network');
    await pumpSession(tester, advicePort: advice);

    await submitQuestion(tester, '물이 안 끓어요');

    expect(find.textContaining('답변을 불러오지 못했어요'), findsOneWidget);
  });

  testWidgets('500자를 넘는 STT 질문은 서버로 보내지 않고 길이 안내를 표시한다', (tester) async {
    final advice = FakeExceptionAdvicePort();
    final speech = FakeSpeechInput();
    await pumpSession(tester, advicePort: advice, speechInput: speech);

    await tester.tap(find.byKey(const Key('voice-input-toggle')));
    await tester.pump();
    speech.emitUtterance('물이 안 끓어요 ${'가' * 500}', utteranceId: 'too-long');
    await tester.pump();

    expect(advice.requests, isEmpty);
    expect(find.textContaining('500자 이하'), findsOneWidget);
  });

  testWidgets('단계가 바뀐 뒤 도착한 답변과 행동 제안은 표시하지 않는다', (tester) async {
    final advice = DeferredExceptionAdvicePort();
    await pumpSession(tester, advicePort: advice, testRecipe: twoStepRecipe);

    await submitQuestion(tester, '물이 안 끓어요');
    expect(advice.request?.stepIndex, 0);

    final nextButton = find.widgetWithText(FilledButton, '다음 단계');
    expect(nextButton, findsOneWidget);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2 단계'), findsOneWidget);

    advice.completer.complete(
      const ExceptionAdvice(
        screenText: '첫 단계에만 해당하는 답변',
        speechText: '첫 단계에만 해당하는 답변',
        suggestedAction: ExceptionAdviceSuggestedAction(
          type: ExceptionAdviceActionType.extendTimer,
          seconds: 60,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('첫 단계에만 해당하는 답변'), findsNothing);
    expect(find.byKey(const Key('help-suggested-action')), findsNothing);
  });

  testWidgets('이전 단계 요청 중에도 새 단계 질문을 허용하고 최신 요청만 화면을 소유한다', (tester) async {
    final advice = QueuedExceptionAdvicePort();
    await pumpSession(tester, advicePort: advice, testRecipe: twoStepRecipe);

    await submitQuestion(tester, '물이 안 끓어요');
    await tester.tap(find.widgetWithText(FilledButton, '다음 단계'));
    await tester.pumpAndSettle();

    final availableHelpButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('help-request')),
    );
    expect(availableHelpButton.onPressed, isNotNull);

    await submitQuestion(tester, '면을 얼마나 더 끓여야 해요?');
    expect(advice.requests, hasLength(2));
    expect(advice.requests.first.stepIndex, 0);
    expect(advice.requests.last.stepIndex, 1);
    expect(
      advice.requests.last.requestContextVersion,
      greaterThan(advice.requests.first.requestContextVersion),
    );

    advice.completions.first.complete(
      const ExceptionAdvice(screenText: '이전 단계 답변', speechText: '이전 단계 답변'),
    );
    await tester.pump();

    expect(find.text('이전 단계 답변'), findsNothing);
    expect(find.text('답변 준비 중'), findsOneWidget);
    final stillOwnedByLatest = tester.widget<OutlinedButton>(
      find.byKey(const Key('help-request')),
    );
    expect(stillOwnedByLatest.onPressed, isNull);

    advice.completions.last.complete(
      const ExceptionAdvice(screenText: '새 단계 답변', speechText: '새 단계 답변'),
    );
    await tester.pumpAndSettle();

    expect(find.text('새 단계 답변'), findsOneWidget);
    expect(find.text('답변 준비 중'), findsNothing);
    final releasedHelpButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('help-request')),
    );
    expect(releasedHelpButton.onPressed, isNotNull);
  });

  testWidgets('이전 질문이 대기 중이어도 음성 단계 이동 뒤 새 음성 질문을 전송한다', (tester) async {
    final advice = QueuedExceptionAdvicePort();
    final speech = FakeSpeechInput();
    await pumpSession(
      tester,
      advicePort: advice,
      testRecipe: twoStepRecipe,
      speechInput: speech,
    );

    await submitQuestion(tester, '물이 안 끓어요');
    await tester.tap(find.byKey(const Key('voice-input-toggle')));
    await tester.pumpAndSettle();
    speech.emitUtterance('다음 단계', utteranceId: 'voice-next');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('voice-input-toggle')));
    await tester.pumpAndSettle();
    speech.emitUtterance('면을 더 끓여야 해?', utteranceId: 'voice-question');
    await tester.pump();

    expect(advice.requests, hasLength(2));
    expect(advice.requests.last.stepIndex, 1);
    expect(advice.requests.last.utterance, '면을 더 끓여야 해?');

    advice.completions.last.complete(
      const ExceptionAdvice(message: '새 단계 음성 답변'),
    );
    advice.completions.first.complete(
      const ExceptionAdvice(message: '이전 단계 음성 답변'),
    );
    await tester.pumpAndSettle();

    expect(find.text('새 단계 음성 답변'), findsOneWidget);
    expect(find.text('이전 단계 음성 답변'), findsNothing);
  });

  testWidgets('진행 중에는 버튼과 음성의 중복 F8 요청을 보내지 않는다', (tester) async {
    final advice = QueuedExceptionAdvicePort();
    final speech = FakeSpeechInput();
    await pumpSession(tester, advicePort: advice, speechInput: speech);

    await submitQuestion(tester, '물이 안 끓어요');
    expect(advice.requests, hasLength(1));
    final helpButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('help-request')),
    );
    expect(helpButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('voice-input-toggle')));
    await tester.pump();
    speech.emitUtterance('물이 안 끓어요', utteranceId: 'duplicate');
    await tester.pump();
    expect(advice.requests, hasLength(1));

    advice.completions.single.complete(
      const ExceptionAdvice(message: '30초 뒤 다시 확인하세요.'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('타이머 제안은 확인 전에는 조리 기록을 바꾸지 않는다', (tester) async {
    final advice = FakeExceptionAdvicePort(
      response: const ExceptionAdvice(
        speechText: '30초 더 기다려보세요.',
        screenText: '30초 더 기다린 뒤 확인하세요.',
        suggestedAction: ExceptionAdviceSuggestedAction(
          type: ExceptionAdviceActionType.extendTimer,
          seconds: 30,
        ),
      ),
    );
    await pumpSession(tester, advicePort: advice);

    await submitQuestion(tester, '물이 안 끓어요');
    expect(find.byKey(const Key('help-suggested-action')), findsOneWidget);
    expect(find.text('03:00'), findsOneWidget);

    // 적용 버튼을 누르지 않고 완료하면 F9가 받는 실제 타이머 기록도 비어 있다.
    await tester.tap(find.widgetWithText(FilledButton, '조리 완료'));
    await tester.pumpAndSettle();
    final review = tester.widget<ReviewScreen>(find.byType(ReviewScreen));
    expect(review.timerSecondsByStep, isEmpty);
  });

  testWidgets('허용된 타이머 제안은 사용자가 누른 뒤에만 적용한다', (tester) async {
    final advice = FakeExceptionAdvicePort(
      response: const ExceptionAdvice(
        speechText: '1분 더 기다려보세요.',
        screenText: '1분 더 기다린 뒤 확인하세요.',
        suggestedAction: ExceptionAdviceSuggestedAction(
          type: ExceptionAdviceActionType.extendTimer,
          seconds: 60,
        ),
      ),
    );
    await pumpSession(tester, advicePort: advice);

    await submitQuestion(tester, '물이 안 끓어요');
    expect(find.text('03:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('help-suggested-action')));
    await tester.pump();
    expect(find.byKey(const Key('help-suggested-action')), findsNothing);
    expect(find.text('04:00'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '조리 완료'));
    await tester.pumpAndSettle();
    final review = tester.widget<ReviewScreen>(find.byType(ReviewScreen));
    expect(review.timerSecondsByStep, <int, int>{0: 240});
  });

  testWidgets('허용 범위를 벗어난 행동은 확인 버튼을 만들지 않는다', (tester) async {
    final advice = FakeExceptionAdvicePort(
      response: const ExceptionAdvice(
        speechText: '확인하세요.',
        screenText: '현재 상태를 확인하세요.',
        suggestedAction: ExceptionAdviceSuggestedAction(
          type: ExceptionAdviceActionType.extendTimer,
          seconds: 90,
        ),
      ),
    );
    await pumpSession(tester, advicePort: advice);

    await submitQuestion(tester, '물이 안 끓어요');

    expect(find.text('현재 상태를 확인하세요.'), findsOneWidget);
    expect(find.byKey(const Key('help-suggested-action')), findsNothing);
    expect(find.text('03:00'), findsOneWidget);
  });

  testWidgets('mock 답변은 허용된 형태의 타이머 행동도 확인 버튼을 만들지 않는다', (tester) async {
    final advice = FakeExceptionAdvicePort(
      response: const ExceptionAdvice(
        speechText: '고정 데모 답변',
        screenText: '고정 데모 답변',
        isMock: true,
        suggestedAction: ExceptionAdviceSuggestedAction(
          type: ExceptionAdviceActionType.extendTimer,
          seconds: 60,
        ),
      ),
    );
    await pumpSession(tester, advicePort: advice);

    await submitQuestion(tester, '물이 안 끓어요');

    expect(find.text('고정 데모 답변'), findsOneWidget);
    expect(find.byKey(const Key('help-suggested-action')), findsNothing);
    expect(find.text('03:00'), findsOneWidget);
  });

  testWidgets('타이머가 없는 단계에서는 연장 제안도 확인 버튼을 만들지 않는다', (tester) async {
    final advice = FakeExceptionAdvicePort(
      response: const ExceptionAdvice(
        speechText: '30초 뒤 확인하세요.',
        screenText: '30초 뒤 상태를 확인하세요.',
        suggestedAction: ExceptionAdviceSuggestedAction(
          type: ExceptionAdviceActionType.extendTimer,
          seconds: 30,
        ),
      ),
    );
    await pumpSession(tester, advicePort: advice, testRecipe: timerlessRecipe);

    await submitQuestion(tester, '반죽이 너무 묽어요');

    expect(find.text('30초 뒤 상태를 확인하세요.'), findsOneWidget);
    expect(find.byKey(const Key('help-suggested-action')), findsNothing);
    expect(find.text('타이머 없음'), findsOneWidget);
  });
}

final class _MemoryPendingReviewDraftStore
    implements PendingReviewDraftGateway {
  PendingReviewDraft? _draft;

  @override
  Future<void> save(PendingReviewDraft draft) async {
    _draft = draft;
  }

  @override
  Future<PendingReviewDraft?> load() async => _draft;

  @override
  Future<void> clear() async {
    _draft = null;
  }
}
