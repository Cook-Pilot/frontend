import 'dart:async';

import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/cooking/presentation/native_speech_output.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:cookpilot/features/review/application/pending_review_draft_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/cooking_fakes.dart';

void main() {
  const recipe = Recipe(
    id: '10000000-0000-0000-0000-000000000021',
    title: 'TTS 조리 테스트',
    description: '네이티브 음성 출력을 검증한다.',
    baseServings: 2,
    imageUrl: '',
    ingredients: <Ingredient>[],
    steps: <CookStep>[
      CookStep(
        stepIndex: 0,
        instruction: '물을 끓이세요.',
        timerSeconds: 60,
        cautionNote: '뜨거운 증기를 조심하세요.',
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
  const oneStepRecipe = Recipe(
    id: '10000000-0000-0000-0000-000000000022',
    title: 'TTS 완료 테스트',
    description: '종료 정리를 검증한다.',
    baseServings: 1,
    imageUrl: '',
    ingredients: <Ingredient>[],
    steps: <CookStep>[
      CookStep(
        stepIndex: 0,
        instruction: '불을 끄세요.',
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
    required SpeechOutputPort speechOutput,
    Recipe testRecipe = recipe,
    SpeechInputPort? speechInput,
    bool handsFreeVoiceEnabled = false,
    ExceptionAdvicePort? advicePort,
    PendingReviewDraftGateway? pendingReviewDraftStore,
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
          speechInput: speechInput ?? FakeSpeechInput(),
          speechOutput: speechOutput,
          handsFreeVoiceEnabled: handsFreeVoiceEnabled,
          pendingReviewDraftStore: pendingReviewDraftStore,
        ),
      ),
    );
    for (var attempt = 0; attempt < 10; attempt += 1) {
      await tester.pump();
    }
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

  testWidgets(
    'initial guidance finishes before opted-in hands-free STT starts',
    (tester) async {
      final output = DeferredSpeechOutput();
      final input = FakeSpeechInput();
      await pumpSession(
        tester,
        speechOutput: output,
        speechInput: input,
        handsFreeVoiceEnabled: true,
      );

      expect(output.spoken, <String>['1단계. 물을 끓이세요.\n주의: 뜨거운 증기를 조심하세요.']);
      expect(input.startCount, 0);

      output.completions.single.complete();
      await tester.pumpAndSettle();

      expect(input.startCount, 1);
      expect(find.text('듣는 중'), findsOneWidget);
    },
  );

  testWidgets(
    'moving steps stops the old native utterance before speaking the latest step',
    (tester) async {
      final engine = _WidgetSpeechSynthesisEngine();
      final output = NativeSpeechOutput(engine: engine);
      await pumpSession(tester, speechOutput: output);
      await pumpUntil(tester, () => engine.spoken.length == 1);
      expect(engine.spoken, <String>['1단계. 물을 끓이세요.\n주의: 뜨거운 증기를 조심하세요.']);

      await tester.tap(find.widgetWithText(FilledButton, '다음 단계'));
      await pumpUntil(tester, () => engine.spoken.length == 2);

      expect(engine.spoken.last, '2단계. 면을 넣으세요.');
      expect(engine.stopCount, 2);
      expect(engine.playbacks.first.isCompleted, isTrue);
      engine.completeLatest();
      await tester.pump();
    },
  );

  testWidgets(
    'only owned advice speaks speechText while screenText stays visual',
    (tester) async {
      final output = FakeSpeechOutput();
      final advice = FakeExceptionAdvicePort(
        response: const ExceptionAdvice(
          screenText: '화면에는 자세한 안전 안내를 보여줘요.',
          speechText: '불을 낮추고 잠시 확인하세요.',
        ),
      );
      await pumpSession(tester, speechOutput: output, advicePort: advice);

      await submitQuestion(tester, '물이 넘쳐요');
      await pumpUntil(tester, () => output.spoken.length == 2);

      expect(find.text('화면에는 자세한 안전 안내를 보여줘요.'), findsOneWidget);
      expect(output.spoken.last, '불을 낮추고 잠시 확인하세요.');
      expect(output.spoken, isNot(contains('화면에는 자세한 안전 안내를 보여줘요.')));
      expect(output.stopCount, 1);
    },
  );

  testWidgets('an advice response that lost step ownership is never spoken', (
    tester,
  ) async {
    final output = FakeSpeechOutput();
    final advice = DeferredExceptionAdvicePort();
    await pumpSession(tester, speechOutput: output, advicePort: advice);

    await submitQuestion(tester, '물이 안 끓어요');
    await tester.tap(find.widgetWithText(FilledButton, '다음 단계'));
    await pumpUntil(tester, () => output.spoken.length == 2);

    advice.completer.complete(
      const ExceptionAdvice(
        screenText: '낡은 첫 단계 화면 답변',
        speechText: '낡은 첫 단계 음성 답변',
      ),
    );
    await tester.pumpAndSettle();

    expect(output.spoken, isNot(contains('낡은 첫 단계 음성 답변')));
    expect(find.text('낡은 첫 단계 화면 답변'), findsNothing);
  });

  testWidgets('a new advice request stops the previous advice utterance', (
    tester,
  ) async {
    final output = DeferredSpeechOutput();
    final advice = FakeExceptionAdvicePort(
      response: const ExceptionAdvice(screenText: '화면 답변', speechText: '음성 답변'),
    );
    await pumpSession(tester, speechOutput: output, advicePort: advice);

    await submitQuestion(tester, '첫 질문');
    await pumpUntil(tester, () => output.spoken.length == 2);
    expect(output.stopCount, 1);

    await submitQuestion(tester, '두 번째 질문');
    await pumpUntil(tester, () => output.spoken.length == 3);

    expect(output.stopCount, 2);
    expect(advice.requests, hasLength(2));
  });

  testWidgets('TTS failures never hide an owned AI answer or block controls', (
    tester,
  ) async {
    final output = FakeSpeechOutput()..error = StateError('no native voice');
    final advice = FakeExceptionAdvicePort(
      response: const ExceptionAdvice(
        screenText: '화면 안전 답변은 유지돼요.',
        speechText: '재생할 수 없는 답변',
      ),
    );
    await pumpSession(tester, speechOutput: output, advicePort: advice);

    await submitQuestion(tester, '질문');

    expect(find.text('화면 안전 답변은 유지돼요.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '다음 단계'), findsOneWidget);
  });

  testWidgets(
    'finishing stops playback and widget disposal releases the port once',
    (tester) async {
      final output = DeferredSpeechOutput();
      final pendingStore = _DeferredPendingReviewDraftStore();
      await pumpSession(
        tester,
        speechOutput: output,
        testRecipe: oneStepRecipe,
        pendingReviewDraftStore: pendingStore,
      );

      await tester.tap(find.widgetWithText(FilledButton, '조리 완료'));
      await tester.pump();

      expect(output.stopCount, 1);
      expect(pendingStore.saved, hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      expect(output.disposeCount, 1);
      pendingStore.completeSave();
      await tester.pump();
    },
  );

  testWidgets('a rejected output stop never blocks completion persistence', (
    tester,
  ) async {
    final output = FakeSpeechOutput();
    final pendingStore = _DeferredPendingReviewDraftStore();
    await pumpSession(
      tester,
      speechOutput: output,
      testRecipe: oneStepRecipe,
      pendingReviewDraftStore: pendingStore,
    );
    output.stopError = StateError('native stop failed');

    await tester.tap(find.widgetWithText(FilledButton, '조리 완료'));
    await tester.pump();

    expect(output.stopCount, 1);
    expect(pendingStore.saved, hasLength(1));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    pendingStore.completeSave();
    await tester.pump();
  });
}

Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 30 && !condition(); attempt += 1) {
    await tester.pump();
  }
  expect(
    condition(),
    isTrue,
    reason: 'asynchronous speech state did not settle',
  );
}

final class _WidgetSpeechSynthesisEngine implements SpeechSynthesisEngine {
  final List<String> spoken = <String>[];
  final List<Completer<void>> playbacks = <Completer<void>>[];
  int stopCount = 0;

  @override
  Future<void> configure() async {}

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    final playback = Completer<void>();
    playbacks.add(playback);
    return playback.future;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    for (final playback in playbacks) {
      if (!playback.isCompleted) {
        playback.complete();
      }
    }
  }

  void completeLatest() {
    final playback = playbacks.last;
    if (!playback.isCompleted) {
      playback.complete();
    }
  }
}

final class _DeferredPendingReviewDraftStore
    implements PendingReviewDraftGateway {
  final List<PendingReviewDraft> saved = <PendingReviewDraft>[];
  final Completer<void> _saveCompletion = Completer<void>();

  @override
  Future<void> save(PendingReviewDraft draft) {
    saved.add(draft);
    return _saveCompletion.future;
  }

  @override
  Future<PendingReviewDraft?> load() async => null;

  @override
  Future<void> clear() async {}

  void completeSave() {
    if (!_saveCompletion.isCompleted) {
      _saveCompletion.complete();
    }
  }
}
