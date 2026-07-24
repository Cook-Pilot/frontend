# 조리 타이머 기능 명세서 (feat/clock)

## 1. 문서 목적

이 문서는 `feat/clock` 브랜치에서 구현한 조리 세션 타이머의 동작 방식, 구성 요소, 플랫폼 설정을 정의한다.

핵심 목표는 두 가지다.

- 화면이 꺼지거나 앱이 백그라운드로 내려가도 타이머가 실제 시간 기준으로 이어진다.
- 앱이 잠들어 있어도 타이머 완료 시각에 OS 알림음이 울린다.

## 2. 해결한 문제

Flutter의 `Stopwatch`는 단조 시계(Android `CLOCK_MONOTONIC`, iOS `mach_absolute_time`)를 사용한다. 기기가 딥슬립에 들어가면 이 시계가 멈추기 때문에, 화면을 다시 켰을 때 잠들어 있던 시간이 반영되지 않아 타이머가 실제보다 느리게 간다.

또한 앱 프로세스가 동결되면 Dart 쪽 `Timer`가 돌지 않으므로, 완료 시각에 소리를 내려면 OS 수준의 예약 알림이 필요하다.

## 3. 구성 요소

| 파일 | 역할 |
| --- | --- |
| `lib/features/cooking/application/monotonic_clock.dart` | `MonotonicClock` 인터페이스와 두 구현. `WallAnchoredMonotonicClock`이 핵심 |
| `lib/features/cooking/application/timer_controller.dart` | `LocalTimerController`. 타이머 상태머신과 남은 시간 계산 |
| `lib/features/cooking/presentation/local_notification_timer_alarm.dart` | 완료 시각에 울리는 로컬 알림 예약 (`TimerAlarmPort` 구현) |
| `lib/features/cooking/presentation/timer_alarm_provider.dart` | 앱 전체에서 알림 플러그인을 한 번만 초기화하는 `resolveTimerAlarm()` |
| `lib/features/mvp/cook_flow_screens.dart` (`CookSessionScreen`) | 메인 조리 화면 연결. 디자인은 유지하고 시계만 실제로 동작 |
| `lib/dev/timer_lab.dart` | 타이머 동작 확인용 개발 실험 화면 |

## 4. 핵심 동작 방식

### 4.1 WallAnchoredMonotonicClock

단조 시계와 벽시계(`DateTime`)를 함께 앵커로 두고, 매 순간 경과값으로 **둘 중 큰 값**을 취한다.

- 딥슬립 동안 단조 시계가 멈추면 벽시계가 실제 경과를 채운다.
- 사용자가 시스템 시각을 과거로 되돌리면 벽시계는 줄지만, 단조 시계는 뒤로 가지 않으므로 하한을 지킨다.

### 4.2 LocalTimerController

| 항목 | 내용 |
| --- | --- |
| 상태 | `idle` → `running` ↔ `paused` → `elapsed` |
| 남은 시간 | 앵커 시점 남은 시간 − 클럭 경과. 매 tick 누적이 아니라 항상 클럭 기준 재계산 |
| tick | 250ms 주기 `Timer`로 UI 갱신 및 종료 감지 (`sync()`) |
| `add(Duration)` | 시간 연장. 일시정지·종료 상태여도 다시 진행시킨다 |
| `snapshot()` / `restore()` | 세션 상태 저장·복원. 복원 시 음수/초과값을 보정한다 |

### 4.3 백그라운드 완료 알림

`LocalNotificationTimerAlarm`이 `flutter_local_notifications` + `timezone`으로 완료 시각에 로컬 알림을 예약한다.

- 예약: 타이머 시작, 재개, 1분 추가 시 `현재 시각 + 남은 시간`으로 `zonedSchedule` (`exactAllowWhileIdle`).
- 취소: 일시정지, 단계 변경(리셋), 화면 이탈(dispose) 시 예약을 취소한다.
- 포그라운드 종료: 앱이 떠 있는 상태로 시간이 끝나면 시스템 사운드 + 진동을 즉시 재생하고 예약 알림은 취소한다.
- 알림 id는 7001 하나를 재사용한다(타이머 알림은 항상 하나만 유지).
- 초기화 시 알림 권한과 정확 알람 권한(Android 12+)을 요청하며, 거부되면 inexact 알람으로 대체된다.

### 4.4 CookSessionScreen 연결

- 화면 디자인은 기존 그대로 두고 시계 표시만 `LocalTimerController` 기준으로 매초 갱신한다.
- `AppLifecycleState.resumed` 시 `sync()`를 호출해 잠든 사이 흐른 시간을 즉시 반영한다.
- 타이머 카드에 **1분 추가** / **리셋** 아웃라인 버튼을 제공한다.
- 버튼 라벨은 상태에 따라 `타이머 시작` / `일시정지` / `계속` / `시간 종료`로 바뀌고, 단계에 시간이 없으면 `타이머 없음`을 표시한다.

## 5. 플랫폼 설정

### 5.1 Android

| 항목 | 내용 |
| --- | --- |
| 권한 | `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE` |
| Receiver | `ScheduledNotificationReceiver`(예약 알림 표시), `ScheduledNotificationBootReceiver`(재부팅 후 재예약) |
| Gradle | `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs 2.1.4` (flutter_local_notifications 요구사항) |

### 5.2 의존성

| 패키지 | 용도 |
| --- | --- |
| `flutter_local_notifications ^19.4.2` | 완료 시각 로컬 알림 예약 |
| `timezone ^0.10.1` | `zonedSchedule`에 필요한 타임존 데이터 |

## 6. 테스트

| 파일 | 검증 내용 |
| --- | --- |
| `test/features/cooking/application/monotonic_clock_test.dart` | 딥슬립(단조 시계 정지) 복원, 시스템 시각 역행 시 하한 유지 |
| `test/features/cooking/application/timer_controller_test.dart` | 상태 전이, 남은 시간 계산, 연장, 스냅샷 복원 |
| `test/features/cooking/application/cooking_session_controller_test.dart` | 세션 컨트롤러와 알람 포트 연동 |

## 7. 한계와 후속 과제

- 알림 권한 또는 정확 알람 권한을 거부하면 완료 알림이 늦거나 오지 않을 수 있다(타이머 자체는 정상 동작).
- 앱을 강제 종료(태스크 킬)하면 화면 복귀 시 타이머 상태가 복원되지 않는다. 세션 스냅샷의 로컬 영속화가 필요하다.
- 알림음은 시스템 기본음을 사용한다. 전용 알람음/무한 반복 울림은 백로그.
