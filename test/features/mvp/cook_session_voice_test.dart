import 'dart:async';

import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/cooking/application/cooking_session_store.dart';
import 'package:cookpilot/features/cooking/presentation/timer_alarm_provider.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:cookpilot/features/review/application/pending_review_draft_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/cooking_fakes.dart';

final class _DeferredAlarmResolver {
  final Completer<TimerAlarmPort> _completion = Completer<TimerAlarmPort>();
  TimerAlarmPermissionFlowChanged? _onPermissionFlowChanged;
  bool _listenerCancelled = false;

  bool get listenerCancelled => _listenerCancelled;

  TimerAlarmRegistration call(
    TimerAlarmPermissionFlowChanged onPermissionFlowChanged,
  ) {
    _onPermissionFlowChanged = onPermissionFlowChanged;
    return TimerAlarmRegistration(
      alarm: _completion.future,
      onCancel: () => _listenerCancelled = true,
    );
  }

  void beginPermissionFlow() => _notifyPermissionFlow(true);

  void endPermissionFlow() => _notifyPermissionFlow(false);

  void complete() => _completion.complete(const SilentTimerAlarm());

  void _notifyPermissionFlow(bool active) {
    if (!_listenerCancelled) {
      _onPermissionFlowChanged!(active);
    }
  }
}

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
    bool handsFreeVoiceEnabled = false,
    TimerAlarmPort? alarm = const SilentTimerAlarm(),
    TimerAlarmResolver? alarmResolver,
    PendingReviewDraftGateway? pendingReviewDraftStore,
    CookingSessionGateway? cookingSessionStore,
  }) async {
    // The cooking controls live in one scrollable screen. Give the widget test
    // enough vertical room to build both the timer and voice controls so these
    // tests exercise state changes instead of depending on ListView laziness.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CookSessionScreen(
          recipe: testRecipe,
          servings: 2,
          alarm: alarm,
          alarmResolver: alarmResolver,
          advicePort: advicePort,
          speechInput: speechInput,
          handsFreeVoiceEnabled: handsFreeVoiceEnabled,
          pendingReviewDraftStore: pendingReviewDraftStore,
          cookingSessionStore: cookingSessionStore,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapVoiceButton(WidgetTester tester) async {
    final button = find.byKey(const Key('voice-input-toggle'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    // A new session may wait for the previous asynchronous stop to finish.
    await tester.pumpAndSettle();
  }

  void backgroundApp(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  }

  void resumeApp(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  Future<void> finishOwnedAlarmFlowWhileBackgrounded(
    WidgetTester tester,
    _DeferredAlarmResolver alarm,
  ) async {
    backgroundApp(tester);
    alarm.endPermissionFlow();
    alarm.complete();
    await tester.pumpAndSettle();
    resumeApp(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('핸즈프리는 명령 처리 후 이전 마이크가 닫힌 뒤 다시 듣는다', (tester) async {
    final speech = FakeSpeechInput()..hangOnStop = true;
    await pumpSession(
      tester,
      speechInput: speech,
      handsFreeVoiceEnabled: true,
      pendingReviewDraftStore: _MemoryPendingReviewDraftStore(),
      cookingSessionStore: _MemoryCookingSessionStore(),
    );

    expect(speech.startCount, 1);
    expect(find.text('듣는 중'), findsOneWidget);

    final staleHandler = speech.utteranceHandlers.single;
    speech.emitUtterance('다음 단계', utteranceId: 'hands-free-next');
    await tester.pump();

    expect(find.text('2 / 3 단계'), findsOneWidget);
    expect(speech.stopCount, 1);
    expect(speech.startCount, 1);

    speech.completePendingStop();
    await tester.pumpAndSettle();

    expect(speech.startCount, 2);
    expect(find.text('듣는 중'), findsOneWidget);

    staleHandler('다음 단계', 'late-old-session');
    await tester.pump();
    expect(find.text('2 / 3 단계'), findsOneWidget);
  });

  testWidgets('핸즈프리 중 화면 단계 버튼은 이전 세션을 닫고 새 단계에서 다시 듣는다', (tester) async {
    final speech = FakeSpeechInput()..hangOnStop = true;
    await pumpSession(
      tester,
      speechInput: speech,
      handsFreeVoiceEnabled: true,
      pendingReviewDraftStore: _MemoryPendingReviewDraftStore(),
      cookingSessionStore: _MemoryCookingSessionStore(),
    );
    final staleHandler = speech.utteranceHandlers.single;

    await tester.tap(find.widgetWithText(FilledButton, '다음 단계'));
    await tester.pump();

    expect(find.text('2 / 3 단계'), findsOneWidget);
    expect(speech.stopCount, 1);
    expect(speech.startCount, 1);
    staleHandler('다음 단계', 'stale-before-new-step');
    await tester.pump();
    expect(find.text('2 / 3 단계'), findsOneWidget);

    speech.completePendingStop();
    await tester.pumpAndSettle();
    expect(speech.startCount, 2);
    expect(find.text('듣는 중'), findsOneWidget);
  });

  testWidgets('inactive에서 예약된 최초 핸즈프리는 resumed 뒤 정확히 한 번 시작한다', (tester) async {
    final speech = FakeSpeechInput();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

    await pumpSession(
      tester,
      speechInput: speech,
      handsFreeVoiceEnabled: true,
      pendingReviewDraftStore: _MemoryPendingReviewDraftStore(),
      cookingSessionStore: _MemoryCookingSessionStore(),
    );
    expect(speech.startCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(speech.startCount, 1);
    expect(find.text('듣는 중'), findsOneWidget);
  });

  testWidgets('알림 권한 완료가 resumed보다 먼저여도 핸즈프리는 한 번만 시작한다', (tester) async {
    final speech = FakeSpeechInput();
    final alarm = _DeferredAlarmResolver();
    await pumpSession(
      tester,
      speechInput: speech,
      handsFreeVoiceEnabled: true,
      alarm: null,
      alarmResolver: alarm.call,
    );
    expect(speech.startCount, 0);

    alarm.beginPermissionFlow();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    alarm.endPermissionFlow();
    alarm.complete();
    await tester.pump();
    expect(speech.startCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(speech.startCount, 1);

    speech.emitUtterance('현재 단계', utteranceId: 'alarm-before-resume');
    await tester.pumpAndSettle();
    expect(speech.startCount, 2);
  });

  testWidgets('resumed가 알림 권한 완료보다 먼저여도 초기 음성 권한 요청을 직렬화한다', (tester) async {
    final speech = FakeSpeechInput();
    final alarm = _DeferredAlarmResolver();
    await pumpSession(
      tester,
      speechInput: speech,
      handsFreeVoiceEnabled: true,
      alarm: null,
      alarmResolver: alarm.call,
    );

    alarm.beginPermissionFlow();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(speech.startCount, 0);

    alarm.endPermissionFlow();
    alarm.complete();
    await tester.pumpAndSettle();
    expect(speech.startCount, 1);

    speech.emitUtterance('현재 단계', utteranceId: 'resume-before-alarm');
    await tester.pumpAndSettle();
    expect(speech.startCount, 2);
  });

  testWidgets('정확 알람 설정의 hidden과 paused 뒤에도 최초 핸즈프리 opt-in을 보존한다', (
    tester,
  ) async {
    final speech = FakeSpeechInput();
    final alarm = _DeferredAlarmResolver();
    await pumpSession(
      tester,
      speechInput: speech,
      handsFreeVoiceEnabled: true,
      alarm: null,
      alarmResolver: alarm.call,
    );

    alarm.beginPermissionFlow();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    alarm.endPermissionFlow();
    alarm.complete();
    await tester.pumpAndSettle();
    expect(speech.startCount, 0);

    resumeApp(tester);
    await tester.pumpAndSettle();
    expect(speech.startCount, 1);
    expect(find.text('듣는 중'), findsOneWidget);
  });

  testWidgets('owned 권한-flow여도 detached는 최초 핸즈프리 pending을 취소한다', (
    tester,
  ) async {
    final speech = FakeSpeechInput();
    final alarm = _DeferredAlarmResolver();
    await pumpSession(
      tester,
      speechInput: speech,
      handsFreeVoiceEnabled: true,
      alarm: null,
      alarmResolver: alarm.call,
    );

    alarm.beginPermissionFlow();
    backgroundApp(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    alarm.endPermissionFlow();
    alarm.complete();
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(speech.startCount, 0);
    expect(find.text('듣는 중'), findsNothing);
  });

  testWidgets('owned 권한-flow여도 detached는 수동 말하기 pending을 취소한다', (tester) async {
    final speech = FakeSpeechInput();
    final alarm = _DeferredAlarmResolver();
    await pumpSession(
      tester,
      speechInput: speech,
      alarm: null,
      alarmResolver: alarm.call,
    );

    alarm.beginPermissionFlow();
    final voiceButton = find.byKey(const Key('voice-input-toggle'));
    await tester.ensureVisible(voiceButton);
    await tester.tap(voiceButton);
    await tester.pump();
    backgroundApp(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    alarm.endPermissionFlow();
    alarm.complete();
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(speech.startCount, 0);
    expect(find.text('듣는 중'), findsNothing);
  });

  testWidgets('기본 말하기는 알림 초기화와 resumed 뒤에 한 번만 시작한다', (tester) async {
    final speech = FakeSpeechInput();
    final alarm = _DeferredAlarmResolver();
    await pumpSession(
      tester,
      speechInput: speech,
      alarm: null,
      alarmResolver: alarm.call,
    );

    alarm.beginPermissionFlow();
    final button = find.byKey(const Key('voice-input-toggle'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(speech.startCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    alarm.endPermissionFlow();
    alarm.complete();
    await tester.pumpAndSettle();
    expect(speech.startCount, 0);

    resumeApp(tester);
    await tester.pumpAndSettle();
    expect(speech.startCount, 1);
    expect(find.text('듣는 중'), findsOneWidget);
  });

  testWidgets('알림 초기화 대기 중 말하기를 다시 누르면 pending 시작을 취소한다', (tester) async {
    final speech = FakeSpeechInput();
    final alarm = _DeferredAlarmResolver();
    await pumpSession(
      tester,
      speechInput: speech,
      alarm: null,
      alarmResolver: alarm.call,
    );

    final voiceButton = find.byKey(const Key('voice-input-toggle'));
    await tester.ensureVisible(voiceButton);
    await tester.tap(voiceButton);
    await tester.pump();
    expect(speech.startCount, 0);

    await tester.tap(voiceButton);
    await tester.pump();
    alarm.complete();
    await tester.pumpAndSettle();

    expect(speech.startCount, 0);
    expect(find.text('듣는 중'), findsNothing);
  });

  testWidgets('단계 이동은 이전 단계에서 대기 중인 수동 말하기를 취소한다', (tester) async {
    final speech = FakeSpeechInput();
    final alarm = _DeferredAlarmResolver();
    await pumpSession(
      tester,
      speechInput: speech,
      alarm: null,
      alarmResolver: alarm.call,
    );

    final voiceButton = find.byKey(const Key('voice-input-toggle'));
    await tester.ensureVisible(voiceButton);
    await tester.tap(voiceButton);
    await tester.pump();
    expect(speech.startCount, 0);

    await tester.tap(find.widgetWithText(FilledButton, '다음 단계'));
    await tester.pump();
    expect(find.text('2 / ${recipe.steps.length} 단계'), findsOneWidget);

    alarm.complete();
    await tester.pumpAndSettle();

    expect(speech.startCount, 0);
    expect(find.text('듣는 중'), findsNothing);
  });

  testWidgets('알림 초기화 중 실제 background는 최초 핸즈프리 pending을 취소한다', (tester) async {
    final speech = FakeSpeechInput();
    final alarm = _DeferredAlarmResolver();
    await pumpSession(
      tester,
      speechInput: speech,
      handsFreeVoiceEnabled: true,
      alarm: null,
      alarmResolver: alarm.call,
    );

    backgroundApp(tester);
    await tester.pump();
    resumeApp(tester);
    alarm.complete();
    await tester.pumpAndSettle();

    expect(speech.startCount, 0);
    expect(find.text('듣는 중'), findsNothing);
  });

  testWidgets('알림 초기화 중 실제 background는 수동 말하기 pending도 취소한다', (tester) async {
    final speech = FakeSpeechInput();
    final alarm = _DeferredAlarmResolver();
    await pumpSession(
      tester,
      speechInput: speech,
      alarm: null,
      alarmResolver: alarm.call,
    );

    final voiceButton = find.byKey(const Key('voice-input-toggle'));
    await tester.ensureVisible(voiceButton);
    await tester.tap(voiceButton);
    await tester.pump();
    expect(speech.startCount, 0);

    backgroundApp(tester);
    resumeApp(tester);
    alarm.complete();
    await tester.pumpAndSettle();

    expect(speech.startCount, 0);
    expect(find.text('듣는 중'), findsNothing);
  });

  testWidgets('알림 초기화 대기 중 조리 완료는 핸즈프리 pending을 취소한다', (tester) async {
    final speech = FakeSpeechInput();
    final alarm = _DeferredAlarmResolver();
    const oneStepRecipe = Recipe(
      id: '10000000-0000-0000-0000-000000000009',
      title: '초기화 대기 완료 레시피',
      description: '완료 취소 경계를 검증한다.',
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
    await pumpSession(
      tester,
      speechInput: speech,
      testRecipe: oneStepRecipe,
      handsFreeVoiceEnabled: true,
      alarm: null,
      alarmResolver: alarm.call,
    );
    alarm.beginPermissionFlow();

    await tester.tap(find.widgetWithText(FilledButton, '조리 완료'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsOneWidget);

    await finishOwnedAlarmFlowWhileBackgrounded(tester, alarm);
    expect(speech.startCount, 0);
  });

  testWidgets('알림 초기화 대기 중 닫기는 수동 말하기 pending을 취소한다', (tester) async {
    final speech = FakeSpeechInput();
    final alarm = _DeferredAlarmResolver();
    await pumpSession(
      tester,
      speechInput: speech,
      alarm: null,
      alarmResolver: alarm.call,
    );
    alarm.beginPermissionFlow();

    final voiceButton = find.byKey(const Key('voice-input-toggle'));
    await tester.ensureVisible(voiceButton);
    await tester.tap(voiceButton);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    await finishOwnedAlarmFlowWhileBackgrounded(tester, alarm);
    expect(speech.startCount, 0);
  });

  testWidgets('알림 초기화 대기 중 직접 입력은 수동 말하기 pending을 취소한다', (tester) async {
    final speech = FakeSpeechInput();
    final alarm = _DeferredAlarmResolver();
    await pumpSession(
      tester,
      speechInput: speech,
      alarm: null,
      alarmResolver: alarm.call,
    );
    alarm.beginPermissionFlow();

    final voiceButton = find.byKey(const Key('voice-input-toggle'));
    await tester.ensureVisible(voiceButton);
    await tester.tap(voiceButton);
    await tester.pump();
    await tester.tap(find.byKey(const Key('help-request')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('help-question-field')), findsOneWidget);

    await finishOwnedAlarmFlowWhileBackgrounded(tester, alarm);
    expect(speech.startCount, 0);
  });

  testWidgets('화면 dispose는 alarm listener와 pending 마이크 시작을 즉시 취소한다', (
    tester,
  ) async {
    final speech = FakeSpeechInput();
    final alarm = _DeferredAlarmResolver();
    await pumpSession(
      tester,
      speechInput: speech,
      handsFreeVoiceEnabled: true,
      alarm: null,
      alarmResolver: alarm.call,
    );
    alarm.beginPermissionFlow();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(alarm.listenerCancelled, isTrue);

    alarm.endPermissionFlow();
    alarm.complete();
    await tester.pumpAndSettle();
    expect(speech.startCount, 0);
  });

  testWidgets('시스템 back은 이전 화면을 열기 전에 음성 세션을 무효화하고 stop한다', (tester) async {
    final speech = FakeSpeechInput();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const Key('open-cook-session'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CookSessionScreen(
                    recipe: recipe,
                    servings: 2,
                    alarm: const SilentTimerAlarm(),
                    speechInput: speech,
                    handsFreeVoiceEnabled: true,
                  ),
                ),
              ),
              child: const Text('조리 화면 열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-cook-session')));
    await tester.pumpAndSettle();
    expect(speech.startCount, 1);
    final staleHandler = speech.utteranceHandlers.single;

    await tester.binding.handlePopRoute();
    expect(speech.stopCount, greaterThanOrEqualTo(1));
    staleHandler('다음 단계', 'stale-after-system-back');
    await tester.pumpAndSettle();

    expect(find.byType(CookSessionScreen), findsNothing);
    expect(find.text('조리 화면 열기'), findsOneWidget);
  });

  testWidgets('핸즈프리도 백그라운드에서 멈춘 뒤 자동으로 다시 시작하지 않는다', (tester) async {
    final speech = FakeSpeechInput();
    await pumpSession(
      tester,
      speechInput: speech,
      handsFreeVoiceEnabled: true,
      pendingReviewDraftStore: _MemoryPendingReviewDraftStore(),
      cookingSessionStore: _MemoryCookingSessionStore(),
    );
    expect(speech.startCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(speech.stopCount, greaterThanOrEqualTo(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(speech.startCount, 1);
  });

  testWidgets('핸즈프리에서 직접 입력을 열면 닫은 뒤에도 자동 듣기를 재개하지 않는다', (tester) async {
    final speech = FakeSpeechInput();
    await pumpSession(
      tester,
      speechInput: speech,
      handsFreeVoiceEnabled: true,
      pendingReviewDraftStore: _MemoryPendingReviewDraftStore(),
      cookingSessionStore: _MemoryCookingSessionStore(),
    );
    expect(speech.startCount, 1);

    await tester.tap(find.byKey(const Key('help-request')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('help-question-field')), findsOneWidget);
    expect(speech.stopCount, greaterThanOrEqualTo(1));

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(speech.startCount, 1);

    await tapVoiceButton(tester);
    expect(speech.startCount, 2);
    expect(find.text('듣는 중'), findsOneWidget);
  });

  testWidgets('핸즈프리 완료 명령 뒤에는 새 듣기 세션을 시작하지 않는다', (tester) async {
    final speech = FakeSpeechInput();
    const oneStepRecipe = Recipe(
      id: '10000000-0000-0000-0000-000000000008',
      title: '핸즈프리 완료 레시피',
      description: '완료 뒤 자동 재시작을 검증한다.',
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
    await pumpSession(
      tester,
      speechInput: speech,
      testRecipe: oneStepRecipe,
      handsFreeVoiceEnabled: true,
      pendingReviewDraftStore: _MemoryPendingReviewDraftStore(),
      cookingSessionStore: _MemoryCookingSessionStore(),
    );
    expect(speech.startCount, 1);

    // 1회차 완료 명령은 확인만 요청하고 종료하지 않는다. 확인 발화를 들으러
    // 핸즈프리 마이크는 다시 열린다.
    speech.emitUtterance('조리 완료', utteranceId: 'hands-free-finish');
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsNothing);
    expect(find.textContaining('완료할까요'), findsOneWidget);
    expect(speech.startCount, 2);

    // 확인 발화가 오면 완료하고, 그 뒤에는 새 듣기 세션을 시작하지 않는다.
    speech.emitUtterance('조리 완료', utteranceId: 'hands-free-finish-confirm');
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(speech.startCount, 2);
  });

  testWidgets('완료 확인 대기 중 다른 명령이 오면 확인이 취소된다', (tester) async {
    final speech = FakeSpeechInput();
    await pumpSession(
      tester,
      speechInput: speech,
      handsFreeVoiceEnabled: true,
      pendingReviewDraftStore: _MemoryPendingReviewDraftStore(),
      cookingSessionStore: _MemoryCookingSessionStore(),
    );

    speech.emitUtterance('조리 완료', utteranceId: 'finish-ask');
    await tester.pumpAndSettle();
    expect(find.textContaining('완료할까요'), findsOneWidget);

    // 다른 명령이 확인을 번복한다. (핸즈프리 재개 문구가 이동 안내를 덮을 수
    // 있으므로 확인 문구가 사라졌는지로 취소를 검증한다.)
    speech.emitUtterance('다음 단계', utteranceId: 'finish-cancel-move');
    await tester.pumpAndSettle();
    expect(find.textContaining('완료할까요'), findsNothing);

    // 취소 이후의 완료 명령은 다시 확인부터 요청한다.
    speech.emitUtterance('조리 완료', utteranceId: 'finish-ask-again');
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsNothing);
    expect(find.textContaining('완료할까요'), findsOneWidget);
  });

  testWidgets('완료 확인 대기 중 소음(ignore)은 확인을 유지한다', (tester) async {
    final speech = FakeSpeechInput();
    await pumpSession(
      tester,
      speechInput: speech,
      handsFreeVoiceEnabled: true,
      pendingReviewDraftStore: _MemoryPendingReviewDraftStore(),
      cookingSessionStore: _MemoryCookingSessionStore(),
    );

    speech.emitUtterance('조리 완료', utteranceId: 'noise-finish-ask');
    await tester.pumpAndSettle();
    expect(find.textContaining('완료할까요'), findsOneWidget);

    // 잡담·소음은 확인 상태를 풀지 않고 확인 안내를 다시 보여준다.
    speech.emitUtterance('어쩌구저쩌구', utteranceId: 'noise-chatter');
    await tester.pumpAndSettle();
    expect(find.textContaining('완료 확인 중이에요'), findsOneWidget);

    speech.emitUtterance('조리 완료', utteranceId: 'noise-finish-confirm');
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsOneWidget);
  });

  testWidgets('마지막 단계 이전의 완료 명령은 두 갈래를 안내하고 중도 종료도 허용한다', (tester) async {
    final speech = FakeSpeechInput();
    await pumpSession(
      tester,
      speechInput: speech,
      handsFreeVoiceEnabled: true,
      pendingReviewDraftStore: _MemoryPendingReviewDraftStore(),
      cookingSessionStore: _MemoryCookingSessionStore(),
    );

    // 1/3단계에서의 완료 명령은 단계 문맥을 알려주고 두 갈래를 안내한다.
    speech.emitUtterance('조리 완료', utteranceId: 'early-finish-ask');
    await tester.pumpAndSettle();
    expect(find.textContaining('마지막 단계가 아니에요'), findsOneWidget);
    expect(find.byType(ReviewScreen), findsNothing);

    // 그래도 완료를 반복하면 중도 종료를 허용한다.
    speech.emitUtterance('조리 완료', utteranceId: 'early-finish-confirm');
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsOneWidget);
  });

  testWidgets('백그라운드에 다녀오면 완료 확인이 만료된다', (tester) async {
    final speech = FakeSpeechInput();
    await pumpSession(tester, speechInput: speech);

    await tapVoiceButton(tester);
    speech.onUtterance!('조리 완료', 'expiry-finish-ask');
    await tester.pumpAndSettle();
    expect(find.textContaining('완료할까요'), findsOneWidget);

    backgroundApp(tester);
    await tester.pumpAndSettle();
    resumeApp(tester);
    await tester.pumpAndSettle();

    // 복귀 후 첫 완료 명령은 즉시 종료하지 않고 다시 확인부터 받는다.
    await tapVoiceButton(tester);
    speech.onUtterance!('조리 완료', 'expiry-finish-after-resume');
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsNothing);
    expect(find.textContaining('완료할까요'), findsOneWidget);
  });

  testWidgets('권한 실패 상태를 표시하고 직접 입력 질문은 계속 처리한다', (tester) async {
    final speech = FakeSpeechInput();
    final advice = FakeExceptionAdvicePort();
    await pumpSession(tester, speechInput: speech, advicePort: advice);

    expect(find.text('질문하기'), findsOneWidget);
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
    await tester.pump();
    await tester.tap(find.byKey(const Key('help-question-submit')));
    await tester.pumpAndSettle();

    expect(advice.requests.single.utterance, '물이 안 끓어요');
    expect(find.textContaining('30초'), findsOneWidget);
  });

  testWidgets('듣는 중 직접 입력을 열면 마이크 상태도 중지 안내로 바뀐다', (tester) async {
    final speech = FakeSpeechInput();
    await pumpSession(tester, speechInput: speech);

    await tapVoiceButton(tester);
    await tester.tap(find.byKey(const Key('help-request')));
    await tester.pumpAndSettle();
    expect(speech.stopCount, greaterThanOrEqualTo(1));
    expect(find.byKey(const Key('help-question-field')), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('음성으로 조리하기'), findsOneWidget);
    expect(find.textContaining('질문을 직접 입력해주세요'), findsOneWidget);
    expect(find.textContaining('듣고 있어요'), findsNothing);
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
    expect(find.text('이 단계는 타이머 없음'), findsOneWidget);

    await tapVoiceButton(tester);
    speech.emitUtterance('다음 단계', utteranceId: 'next');
    await tester.pump();
    await tapVoiceButton(tester);
    speech.emitUtterance('타이머 시작', utteranceId: 'timer-start');
    await tester.pump();
    expect(find.text('일시정지'), findsOneWidget);

    await tapVoiceButton(tester);
    expect(speech.startCount, 4);
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

    await tapVoiceButton(tester);
    speech.emitUtterance('다음 단계', utteranceId: 'next-after-extension');
    await tester.pump();
    await tapVoiceButton(tester);
    speech.emitUtterance('이전 단계', utteranceId: 'previous-to-extension');
    await tester.pump();
    expect(find.text('2 / 3 단계'), findsOneWidget);
    expect(find.text('04:00'), findsOneWidget);
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

  testWidgets('권한 다이얼로그의 starting 세션은 닫고 resumed 뒤 다시 시작한다', (tester) async {
    final speech = FakeSpeechInput()
      ..autoReady = false
      ..hangOnStop = true;
    await pumpSession(tester, speechInput: speech);

    await tapVoiceButton(tester);
    final staleReady = speech.onReady!;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    // 동일 inactive가 중복 전달돼도 resume 재시작 의도를 잃지 않는다.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(speech.stopCount, greaterThanOrEqualTo(1));
    staleReady();
    await tester.pump();
    expect(find.text('듣는 중'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(speech.startCount, 1);

    speech.completePendingStop();
    await tester.pumpAndSettle();
    expect(speech.startCount, 2);
    expect(find.text('마이크 준비 중'), findsOneWidget);

    speech.emitReady();
    await tester.pump();
    expect(find.text('듣는 중'), findsOneWidget);
    speech.emitUtterance('다음 단계', utteranceId: 'after-permission-dialog');
    await tester.pump();
    expect(find.text('2 / 3 단계'), findsOneWidget);
  });

  testWidgets('Control Center의 starting inactive도 중지하고 늦은 ready를 버린다', (
    tester,
  ) async {
    final speech = FakeSpeechInput()..autoReady = false;
    await pumpSession(tester, speechInput: speech);

    await tapVoiceButton(tester);
    final staleReady = speech.onReady!;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(speech.stopCount, greaterThanOrEqualTo(1));
    staleReady();
    await tester.pump();
    expect(find.text('듣는 중'), findsNothing);
    expect(find.textContaining('화면을 벗어나 음성 입력을 멈췄어요'), findsOneWidget);
    expect(speech.startCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(speech.startCount, 2);
    expect(find.text('마이크 준비 중'), findsOneWidget);
  });

  testWidgets('resumed가 아닌 동안에는 새 음성 세션을 시작하지 않는다', (tester) async {
    final speech = FakeSpeechInput();
    await pumpSession(tester, speechInput: speech);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tapVoiceButton(tester);

    expect(speech.startCount, 0);
    expect(find.text('듣는 중'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('듣는 중 inactive 상태는 마이크를 닫고 idle 백그라운드는 문구를 덮지 않는다', (
    tester,
  ) async {
    final speech = FakeSpeechInput();
    await pumpSession(tester, speechInput: speech);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.textContaining('화면을 벗어나 음성 입력을 멈췄어요'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tapVoiceButton(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(speech.stopCount, greaterThanOrEqualTo(2));
    expect(find.textContaining('화면을 벗어나 음성 입력을 멈췄어요'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(speech.startCount, 1);
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
    await pumpSession(
      tester,
      speechInput: speech,
      testRecipe: oneStepRecipe,
      pendingReviewDraftStore: _MemoryPendingReviewDraftStore(),
      cookingSessionStore: _MemoryCookingSessionStore(),
    );

    await tapVoiceButton(tester);
    speech.emitUtterance('다음 단계', utteranceId: 'last-next');
    await tester.pump();
    expect(find.textContaining('마지막 단계예요'), findsOneWidget);
    expect(find.byType(ReviewScreen), findsNothing);

    await tapVoiceButton(tester);
    // 1회차 완료 명령은 확인을 요청한다.
    speech.onUtterance!('조리 완료', 'finish');
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsNothing);
    expect(find.textContaining('완료할까요'), findsOneWidget);

    // 수동 모드에서는 확인 발화를 위해 마이크를 다시 연다.
    await tapVoiceButton(tester);
    final confirmHandler = speech.onUtterance!;
    confirmHandler('조리 완료', 'finish-confirm');
    // 동일 완료 콜백이 한 번 더 와도 첫 전환에서 이미 무효화된다.
    confirmHandler('조리 완료', 'finish-duplicate');
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsOneWidget);
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

final class _MemoryCookingSessionStore implements CookingSessionGateway {
  PersistedCookingSession? _session;

  @override
  Future<void> save(PersistedCookingSession session) async {
    _session = session;
  }

  @override
  Future<PersistedCookingSession?> load() async => _session;

  @override
  Future<void> clear() async {
    _session = null;
  }
}
