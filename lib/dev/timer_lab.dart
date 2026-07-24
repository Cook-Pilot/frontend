// 타이머(화면 off 지속 + 백그라운드 알림) 실기기 검증용 엔트리포인트.
//
// 실행: flutter run -t lib/dev/timer_lab.dart
//
// 실제 CookingSessionController + WallAnchoredMonotonicClock(기본 클럭) +
// LocalNotificationTimerAlarm 을 붙여, 짧은 타이머로 다음을 확인한다.
//   1) 타이머 실행 중 화면을 끈다 → 잠시 뒤 화면을 켜면 남은 시간이 정확히 줄어 있다.
//   2) 타이머 실행 중 앱을 백그라운드로 보내거나 화면을 끈다 → 완료 시각에 OS 알림이 울린다.
import 'package:flutter/material.dart';

import '../design/cookpilot_theme.dart';
import '../features/cooking/application/cooking_ports.dart';
import '../features/cooking/application/cooking_session_controller.dart';
import '../features/cooking/application/timer_controller.dart';
import '../features/cooking/domain/cooking_step.dart';
import '../features/cooking/presentation/cooking_screen.dart';
import '../features/cooking/presentation/local_notification_timer_alarm.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final alarm = await LocalNotificationTimerAlarm.initialize();
  runApp(TimerLabApp(alarm: alarm));
}

const _labSteps = <CookingStep>[
  CookingStep(
    id: 'lab-10s',
    instruction: '10초 타이머입니다. 지금 화면을 끄거나 앱을 백그라운드로 보내세요.',
    completionCue: '알림음이 울리면 백그라운드 알림 성공입니다.',
    timerDuration: Duration(seconds: 10),
    mediaType: StepMediaType.none,
    mediaAsset: null,
    mediaLabel: '테스트 단계에는 이미지가 없습니다',
    mediaCaption: '완료 기준을 확인하세요',
  ),
  CookingStep(
    id: 'lab-30s',
    instruction: '30초 타이머입니다. 일시정지·재개·1분 추가도 눌러보세요.',
    completionCue: '화면을 껐다 켜서 남은 시간이 정확한지 확인하세요.',
    timerDuration: Duration(seconds: 30),
    mediaType: StepMediaType.none,
    mediaAsset: null,
    mediaLabel: '테스트 단계에는 이미지가 없습니다',
    mediaCaption: '완료 기준을 확인하세요',
  ),
  CookingStep(
    id: 'lab-done',
    instruction: '마지막 단계입니다. 완료를 눌러 세션을 종료하세요.',
    completionCue: '종료 시 예약된 알림이 취소됩니다.',
    timerDuration: Duration.zero,
    mediaType: StepMediaType.none,
    mediaAsset: null,
    mediaLabel: '테스트 단계에는 이미지가 없습니다',
    mediaCaption: '완료 기준을 확인하세요',
  ),
];

class TimerLabApp extends StatefulWidget {
  const TimerLabApp({required this.alarm, super.key});

  final TimerAlarmPort alarm;

  @override
  State<TimerLabApp> createState() => _TimerLabAppState();
}

class _TimerLabAppState extends State<TimerLabApp> {
  late final CookingSessionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CookingSessionController(
      recipeId: 'timer-lab',
      recipeVersionId: 'lab-v1',
      steps: _labSteps,
      timer: LocalTimerController(),
      speechInput: DemoSpeechInput(),
      speechOutput: DemoSpeechOutput(),
      exceptionAdvice: DemoExceptionAdvicePort(),
      alarm: widget.alarm,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CookPilotTheme.light,
      home: CookingScreen(
        controller: _controller,
        recipeName: '타이머 테스트 · 실기기',
      ),
    );
  }
}
