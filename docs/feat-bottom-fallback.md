# 음성 폴백 도움 입력 명세서 (feat/bottom-fallback)

## 1. 문서 목적

이 문서는 `feat/bottom-fallback` 브랜치에서 진행한 음성 폴백(도움 질문 텍스트 입력) 작업의 배경, 검토한 대안, 최종 결정과 구현 내용을 정의한다.

## 2. 문제 상황

하단 폴백 요구사항(목적: 음성 실패 시 조리 흐름 유지 / 수락: 마이크 권한 없이 조리 세션 완료 가능)에서 다음·반복·타이머 조작과 이벤트 통합 저장은 이미 구현되어 있었지만, **도움(예외 상황 질문) 기능만 음성 발화로만 진입 가능**했다. 예외 조언 흐름(`ExceptionAdvicePort`)은 인식되지 않은 발화를 자유 질문으로 간주해 답을 주는 구조인데, 마이크가 없는 사용자는 질문 자체를 할 방법이 없었다.

또한 실제 앱 조리 화면(`CookSessionScreen`)의 `재료 문제 · 반복 · 타이머 · 도움` 칩 줄은 탭해도 아무 동작이 없는 장식이었다.

## 3. 검토한 대안

| 안 | 내용 | 결과 |
| --- | --- | --- |
| 엔진 화면 퀵 덱에 버튼 추가 | `features/cooking`의 `QuickCommandDeck`에 도움 버튼을 추가하고 `CookingSessionController.requestHelp`로 연결 | 구현은 완료했으나 해당 화면은 실제 앱 라우팅에 없고 `dev/timer_lab.dart` 전용이라 앱에 반영되지 않았다. 코드는 엔진 통합 시 재사용 목적으로 유지 |
| MVP 화면 칩 줄의 도움 칩 활성화 | 기존 Pill 4개 중 도움만 실제 버튼으로 전환 | 나머지 3개가 여전히 장식이라 버튼처럼 보이지 않고, 칩 줄 자체의 존재 이유가 불분명해 폐기 |
| **마이크 카드 탭 (채택)** | 칩 줄을 제거하고 마이크 안내 카드(`"얼마나 익었나요?"`)를 탭하면 질문 입력 시트가 열리게 한다 | 진입점이 하나로 정리된다. 음성이 실제로 붙으면 같은 카드가 "말하기(기본) / 탭해서 입력(폴백)"을 함께 담는다 |

## 4. 최종 결정: 마이크 카드 = 질문 단일 진입점

| 항목 | 내용 |
| --- | --- |
| 진입점 | `CookSessionScreen`의 마이크 안내 `InfoStrip` 탭 (`Key('help-request')`) |
| 입력 UI | `HelpQuestionSheet` 공용 바텀시트 — 자동 포커스 텍스트 필드, 빈 질문은 제출 비활성, 키보드 전송 지원 |
| 질문 처리 | `ExceptionAdvicePort.requestAdvice()`에 현재 단계 맥락(단계 지시문, 남은 타이머 시간, 질문)을 담아 요청 |
| 답변 표시 | 마이크 카드 아래 `InfoStrip`("도움 답변"). 대기 중엔 "답변 준비 중", 실패 시 폴백 안내 |
| 맥락 보호 | 답을 기다리는 사이 단계가 바뀌면 낡은 답변을 폐기한다 (요청 버전 + 단계 검사) |
| AI 연동 지점 | 현재 기본 구현은 `DemoExceptionAdvicePort`(하드코딩 데모 응답). `CookSessionScreen.advicePort` 주입 지점으로 AI 파트 완성 시 실제 구현으로 교체한다 |

### 엔진(`features/cooking`) 쪽 구현 — 유지분

실제 앱에는 아직 안 붙지만, 엔진 통합 PR에서 그대로 쓰일 로직:

- `CookingSessionController.requestHelp(String)` — 텍스트 질문을 음성 발화와 **동일한 이벤트 타입**(`exception_advice_requested/received/failed`)으로 기록한다. `CommandSource`(voice/button)로 출처만 구분되며, 요구사항 "버튼 이벤트를 음성 명령과 동일한 이벤트 타입으로 저장"을 충족한다.
- 요청 진입 시점의 음성 상태(`permissionDenied` 등)를 캡처해 요청 종료 후 복원한다 — 마이크 권한 거부 상태에서 질문해도 권한 안내 UI가 유지된다.
- `QuickCommandDeck`의 도움 버튼과 그리드 전환 확장(5버튼 대응).

## 5. 범위에서 제외한 것

- **기록 버튼** — 이벤트 자동 기록(`CookingSessionController._events`)이 이미 모든 조작을 남기고, 조언 요청 시 `recentEvents`로 AI에 전달되는 구조까지 있어 별도 버튼 없이 요구사항 취지를 충족한다. AI 파트 완성 시 재검토.
- **MVP 화면의 이벤트 기록** — MVP 화면은 `CookingSessionController`를 쓰지 않아 이벤트 로그가 없다. 엔진 통합 PR에서 함께 붙인다 ([feat-session-restore](feat-session-restore.md) 5장 참고).
- **음성 입력(STT) 자체** — 이 브랜치는 폴백(텍스트) 경로만 다룬다.

## 6. 검증

- `cooking_session_controller_test.dart` — 버튼 질문의 이벤트 타입·source 기록, 권한 거부 상태에서 동작·상태 복원, 요청 실패 시 상태 복원, 빈 질문 거절.
- `cooking_screen_test.dart` — 엔진 화면에서 시트 열기 → 제출 → 답변 표시, 빈 질문 제출 비활성.
- `cook_session_help_test.dart` — 실제 앱 화면에서 마이크 카드 탭 → 질문 제출 → 현재 단계 맥락 전달·답변 표시, 실패 시 폴백 안내.

## 7. 이후 작업에서 지킬 것

- AI 파트가 완성되면 `ExceptionAdvicePort` 실 구현을 만들고 `CookSessionScreen.advicePort`(및 엔진의 생성자 주입)에 꽂는다. UI는 수정할 필요 없다.
- 음성 입력을 붙일 때 마이크 카드를 상태 표시(듣는 중/권한 필요 등)와 탭 입력이 공존하는 형태로 확장한다. 탭 진입점(`Key('help-request')`)은 유지한다.
- 엔진 화면을 MVP 플로우에 들일 때 `requestHelp` 경로로 갈아타면 이벤트 기록이 자동으로 붙는다. MVP 화면의 임시 질문 처리(`_openHelpSheet`)는 그때 제거한다.
