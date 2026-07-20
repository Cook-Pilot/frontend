import 'package:cookpilot/design/cookpilot_theme.dart';
import 'package:cookpilot/features/cooking/application/cooking_session_controller.dart';
import 'package:cookpilot/features/cooking/application/timer_controller.dart';
import 'package:cookpilot/features/cooking/domain/cooking_session_state.dart';
import 'package:cookpilot/features/cooking/domain/cooking_step.dart';
import 'package:cookpilot/features/cooking/presentation/cooking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/cooking_fakes.dart';

void main() {
  testWidgets('S-03 핵심 정보와 모든 fallback 조작을 표시한다', (tester) async {
    final controller = _buildController();
    addTearDown(controller.dispose);

    await _pumpCookingScreen(tester, controller: controller);

    expect(find.text('라면'), findsOneWidget);
    expect(find.text('1 / 3 단계'), findsOneWidget);
    expect(find.byKey(const Key('current-action')), findsOneWidget);
    expect(find.byKey(const Key('completion-cue')), findsOneWidget);
    expect(find.byKey(const Key('remaining-time')), findsOneWidget);
    expect(find.byKey(const Key('voice-status-bar')), findsOneWidget);
    expect(find.byKey(const Key('previous-step')), findsOneWidget);
    expect(find.byKey(const Key('repeat-instruction')), findsOneWidget);
    expect(find.byKey(const Key('add-minute')), findsOneWidget);
    expect(find.byKey(const Key('next-step')), findsOneWidget);
    expect(find.byKey(const Key('timer-toggle')), findsOneWidget);
    expect(find.byKey(const Key('abort-session')), findsOneWidget);
    expect(find.byKey(const Key('complete-session')), findsOneWidget);
  });

  testWidgets('1분 추가와 타이머 일시정지·재개가 로컬에서 동작한다', (tester) async {
    final controller = _buildController();
    addTearDown(controller.dispose);
    await _pumpCookingScreen(tester, controller: controller);

    expect(find.text('02:14'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-minute')));
    await tester.pump();
    expect(find.text('03:14'), findsOneWidget);

    await tester.tap(find.byKey(const Key('timer-toggle')));
    await tester.pump();
    expect(controller.timer.status, TimerStatus.paused);
    expect(find.text('일시정지'), findsOneWidget);

    await tester.tap(find.byKey(const Key('timer-toggle')));
    await tester.pump();
    expect(controller.timer.status, TimerStatus.running);
  });

  testWidgets('다음 버튼은 Recipe Runner의 현재 단계를 변경한다', (tester) async {
    final controller = _buildController();
    addTearDown(controller.dispose);
    await _pumpCookingScreen(tester, controller: controller);

    await tester.tap(find.byKey(const Key('next-step')));
    await tester.pumpAndSettle();

    expect(controller.state.stepIndex, 1);
    expect(find.text('면과 스프를 넣고 가볍게 풀어주세요.'), findsOneWidget);
    expect(find.text('2 / 3 단계'), findsOneWidget);
    expect(find.textContaining('완료 기준:'), findsWidgets);
    expect(find.textContaining('이미지를 불러오지 못했어요'), findsNothing);
  });

  testWidgets('완료는 확인 뒤 review callback을 한 번 호출한다', (tester) async {
    final controller = _buildController();
    addTearDown(controller.dispose);
    var completed = 0;
    await _pumpCookingScreen(
      tester,
      controller: controller,
      onComplete: () => completed += 1,
    );

    await tester.tap(find.byKey(const Key('complete-session')));
    await tester.pumpAndSettle();
    expect(find.text('조리를 완료할까요?'), findsOneWidget);
    await tester.tap(find.text('완료하기'));
    await tester.pumpAndSettle();

    expect(controller.state.sessionStatus, CookingSessionStatus.review);
    expect(completed, 1);
  });

  testWidgets('작은 화면과 200% 글자에서도 RenderFlex overflow가 없다', (tester) async {
    final controller = _buildController();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: CookPilotTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: CookingScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('timer-instrument')),
      160,
      scrollable: find.descendant(
        of: find.byKey(const Key('cooking-scroll-view')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('next-step')), findsOneWidget);
    expect(find.byKey(const Key('complete-session')), findsOneWidget);
  });

  for (final textScale in <double>[1, 2]) {
    testWidgets('작은 화면 ${textScale}x 글자에서 이미지 실패 fallback이 안전하다', (
      tester,
    ) async {
      const missingMediaSteps = <CookingStep>[
        CookingStep(
          id: 'missing-media',
          instruction: '긴 조리 안내를 화면에서 확인하세요.',
          completionCue: '완료 기준도 화면에서 계속 확인할 수 있어요.',
          timerDuration: Duration(minutes: 1),
          mediaType: StepMediaType.image,
          mediaAsset: 'assets/recipes/missing/not-found.jpg',
          mediaLabel: '불러올 수 없는 조리 이미지',
          mediaCaption: '불러올 수 없는 미디어 설명',
        ),
      ];
      final controller = _buildController(steps: missingMediaSteps);
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: CookPilotTheme.light,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 568),
              textScaler: TextScaler.linear(textScale),
            ),
            child: CookingScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('이미지를 불러오지 못했어요'),
        120,
        scrollable: find.descendant(
          of: find.byKey(const Key('cooking-scroll-view')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('이미지를 불러오지 못했어요'), findsOneWidget);
      expect(find.byKey(const Key('complete-session')), findsOneWidget);
    });
  }

  testWidgets('480×900과 130% 글자에서도 핵심 조작이 유지된다', (tester) async {
    final controller = _buildController();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: CookPilotTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(480, 900),
            textScaler: TextScaler.linear(1.3),
          ),
          child: CookingScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('next-step')), findsOneWidget);
    expect(find.byKey(const Key('complete-session')), findsOneWidget);
  });

  testWidgets('핵심 조작은 Android 최소 터치 영역을 충족한다', (tester) async {
    final controller = _buildController();
    addTearDown(controller.dispose);
    final semantics = tester.ensureSemantics();
    await _pumpCookingScreen(tester, controller: controller);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('본문 읽기 순서는 행동, 미디어, 타이머, 음성 상태를 유지한다', (tester) async {
    final controller = _buildController();
    addTearDown(controller.dispose);
    await _pumpCookingScreen(tester, controller: controller);

    final actionY = tester
        .getTopLeft(find.byKey(const Key('current-action')))
        .dy;
    final mediaY = tester.getTopLeft(find.byKey(const Key('step-media'))).dy;
    final timerY = tester
        .getTopLeft(find.byKey(const Key('timer-instrument')))
        .dy;
    final voiceY = tester
        .getTopLeft(find.byKey(const Key('voice-status-bar')))
        .dy;

    expect(actionY, lessThan(mediaY));
    expect(mediaY, lessThan(timerY));
    expect(timerY, lessThan(voiceY));
  });

  testWidgets('시스템 Back은 중단 확인을 거친다', (tester) async {
    final controller = _buildController();
    addTearDown(controller.dispose);
    await _pumpCookingScreen(tester, controller: controller);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('조리를 중단하고 나갈까요?'), findsOneWidget);
    expect(controller.state.sessionStatus, CookingSessionStatus.cooking);
    await tester.tap(find.text('계속 조리'));
    await tester.pumpAndSettle();
    expect(controller.state.sessionStatus, CookingSessionStatus.cooking);
  });

  testWidgets('권한 거절 상태에서 앱 설정 callback을 제공한다', (tester) async {
    final controller = _buildController();
    addTearDown(controller.dispose);
    var settingsOpened = 0;
    await _pumpCookingScreen(
      tester,
      controller: controller,
      onOpenAppSettings: () => settingsOpened += 1,
    );

    controller.setMicrophonePermissionDenied();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-app-settings')));
    await tester.pump();

    expect(settingsOpened, 1);
  });
}

CookingSessionController _buildController({
  List<CookingStep> steps = ramenDemoSteps,
}) {
  return CookingSessionController(
    sessionId: 'widget-test',
    recipeId: 'ramen',
    recipeVersionId: 'base-v1',
    steps: steps,
    timer: LocalTimerController(clock: FakeMonotonicClock(), autoTick: false),
    speechInput: FakeSpeechInput(),
    speechOutput: FakeSpeechOutput(),
    exceptionAdvice: FakeExceptionAdvicePort(),
  );
}

Future<void> _pumpCookingScreen(
  WidgetTester tester, {
  required CookingSessionController controller,
  VoidCallback? onComplete,
  VoidCallback? onOpenAppSettings,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: CookPilotTheme.light,
      home: CookingScreen(
        controller: controller,
        onComplete: onComplete,
        onOpenAppSettings: onOpenAppSettings,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
