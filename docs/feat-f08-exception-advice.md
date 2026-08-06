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
  "userSpeech": "물이 안 끓어요"
}
```

- `X-CookPilot-User-Id`는 `BetaUserSession.requestHeaders`에서 가져온다.
- `stepIndex`는 0부터 시작한다.
- `AiFeedbackRequest`가 받는 필드는 위 셋뿐이다. 이전에는 현재 단계 문장
  `instruction`과 남은 시간 `remainingSeconds`도 보냈지만 서버가 읽지 않고
  버리므로 전송하지 않는다. 개인 버전에서 재인덱싱된 단계 문맥을 Gemini에
  반영하려면 backend가 요청 스키마에 이 두 필드를 다시 받아야 한다.
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
  "speechText": "불을 한 단계 높이고 조금 더 기다려보세요."
}
```

`AiFeedbackResponse`는 위 두 필드뿐이다. 화면과 음성 모두 `speechText`를
쓴다. `speechText`가 없거나 공백뿐이거나 JSON이 아니면 실패 응답으로
처리한다.

`ExceptionAdvice`는 화면용 `screenText`와 음성용 `speechText`를 계속 나눠
들고 있고, HTTP 어댑터는 둘 다 같은 값으로 채운다. 분리 자체는 TTS 수명
주기(`feat-native-tts.md`)가 쓰는 구분이라 유지한다.

`mock`은 백엔드가 아직 Gemini 대신 고정 데모 답변을 주는 상태를 나타낸다.
현재는 표시 동작을 바꾸지 않는다.

## 타이머 행동 승인

없다. AI 답변은 조리 상태를 바꾸지 못하고 텍스트만 표시한다.

backend가 `suggestedAction`(`EXTEND_TIMER` 30/60초)과 `eventPayload`를 응답
스키마에서 제거했으므로, 답변 아래 `제안 적용` 버튼과 30/60초 화이트리스트
검증도 함께 걷어냈다. 타이머 연장은 사용자의 음성 명령(F-07)과 화면 버튼
경로에만 남는다. 따라서 F-09 후기 및 개인 버전 계산에 AI 제안이 섞일 경로가
구조적으로 없다.

답변을 기다리는 동안 단계가 바뀌면 기존 request version과 단계 번호를
비교해 늦게 도착한 텍스트를 폐기한다.

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

## TTS 연동

후속 `NativeSpeechOutput`이 현재 단계와 request version 검증을 통과한
`speechText`만 재생한다. 새 질문·단계 이동·완료·화면 이탈은 이전 재생을
중지하며, 화면에 표시하는 `screenText`와 음성용 `speechText`의 자리는 계속
분리한다(현재 서버 응답에서는 두 값이 같다).
세부 수명 주기와 실패 동작은 `feat-native-tts.md`에 정리한다.
