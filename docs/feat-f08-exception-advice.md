# F-08 조리 예외 질문 연결

## 범위

F-07이 `exceptionQuestion`으로 분류한 음성 문장과 조리 화면의 직접 입력
질문을 백엔드 조리 코치에 전달한다. Gemini API 키와 모델 호출은 백엔드가
관리하며 Flutter 앱에는 키를 포함하지 않는다.

구현 파일:

- `lib/features/cooking/data/exception_advice_api.dart`
- `lib/features/cooking/application/cooking_ports.dart`
- `lib/features/mvp/cook_flow_screens.dart`

## 요청 계약

`HttpExceptionAdvicePort`는 `POST /api/v1/ai-feedback`을 호출한다.

```json
{
  "recipeId": "10000000-0000-0000-0000-000000000001",
  "stepIndex": 0,
  "userSpeech": "물이 안 끓어요",
  "instruction": "물 500ml를 넣고 끓이세요.",
  "remainingSeconds": 42
}
```

- `X-CookPilot-User-Id`는 `BetaUserSession.requestHeaders`에서 가져온다.
- `stepIndex`는 0부터 시작한다.
- `instruction`은 서버의 기본 레시피를 다시 조회한 값이 아니라 현재 실행
  스냅샷의 단계 문장과 주의사항이다. 개인 버전에서 추가·삭제·수정한 단계도
  이 값으로 Gemini 문맥에 반영한다.
- `remainingSeconds`는 음수를 0으로, 백엔드 계약 상한을 넘는 값은 86,400초로
  제한한다. 화면의 `99:59` 표시 상한과 API 문맥 상한은 분리한다.
- 조리 진행과 세션은 프론트가 관리하므로 로컬 `sessionId`는 보내지 않고
  서버 세션이나 별도 DB 저장을 요구하지 않는다.
- 같은 답변을 기다리는 동안 버튼이나 마이크에서 들어온 추가 질문은 보내지
  않아 무료 API 쿼터의 중복 소비를 막는다.
- 직접 입력은 500자 카운터로 제한하고, STT 결과도 500자를 넘으면 서버로
  보내지 않고 길이를 줄이라는 안내를 표시한다.

## 응답 계약

```json
{
  "mock": false,
  "speechText": "불을 한 단계 높이고 조금 더 기다려보세요.",
  "screenText": "불을 높이고 30초 뒤 기포를 확인하세요.",
  "suggestedAction": {
    "type": "EXTEND_TIMER",
    "seconds": 30
  },
  "eventPayload": {
    "problem": "WATER_NOT_BOILING"
  }
}
```

화면은 `screenText`를 표시한다. 한쪽 텍스트만 내려오는 과도기 응답은
`speechText`와 `screenText` 양쪽에 같은 값으로 보완한다. 텍스트가 모두
없거나 JSON이 아니면 실패 응답으로 처리한다.

`eventPayload`는 계약 호환 및 진단 정보로만 읽고 화면 동작을 결정하는
근거로 사용하지 않는다. `mock`은 배포 호환 안전장치로만 사용한다. 프론트가
새 F-08 백엔드보다 먼저 배포되어 기존 `mock: true` 고정 응답을 받으면
텍스트만 표시하고 행동 제안은 버린다.

## 타이머 행동 승인

현재 허용하는 행동은 `EXTEND_TIMER`의 30초 또는 60초뿐이다. 다른 행동,
문자열이 아닌 초 값, 30/60초 이외의 값은 답변은 표시하되 행동만 버린다.

허용된 제안도 자동 실행하지 않는다. 답변 아래의 `제안 적용` 버튼을 사용자가
직접 누른 뒤에만 기존 `_extendCurrentTimer()` 흐름을 호출한다. 확인 전에
단계를 이동하거나 조리를 완료하면 `_timerSecondsByStep`은 바뀌지 않으므로
F-09 후기 및 개인 버전 계산에도 AI 제안이 섞이지 않는다.

답변을 기다리는 동안 단계가 바뀌면 기존 request version과 단계 번호를
비교해 늦게 도착한 텍스트와 행동 제안을 모두 폐기한다.

## 오류 동작

- 200이 아닌 HTTP 상태
- 네트워크 연결 실패
- 8초 timeout
- JSON 또는 필수 답변 텍스트 형식 오류

위 오류는 조리 진행을 막지 않는다. 화면에는 답변을 불러오지 못했다는 안내를
표시하고 단계 버튼과 로컬 타이머는 계속 사용할 수 있다.

## 무료 API 데이터 안내

음성·직접 입력 질문은 답변 생성을 위해 Google Gemini로 전송될 수 있다.
조리 화면과 직접 입력 시트에 이 사실과 개인정보·건강정보를 말하거나 입력하지
말라는 안내를 표시한다. 앱과 백엔드는 원문 질문을 로컬 후기, 이벤트 payload,
DB 또는 서버 로그에 저장하지 않는다.

## 후속 범위

F-06/F-07 브랜치에는 `SpeechOutputPort` 인터페이스만 있고 실제 TTS 플러그인
어댑터가 없다. 이번 연결은 `speechText`를 보존하지만 음성 재생은 하지 않는다.
실제 TTS 어댑터가 추가되면 현재 단계·request version 검증을 통과한
`speechText`만 재생하고 화면 이탈 및 새 요청 시 이전 재생을 중지해야 한다.
