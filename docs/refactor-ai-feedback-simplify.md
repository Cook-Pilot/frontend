# AI 피드백 응답 축소 대응

## 문제 상황

실기기에서 F-08 도움 답변이 "질문과 상관없는 고정 문구만 나온다"는 증상을
추적하다 backend 계약이 바뀐 것을 확인했다.

실서버(`POST /api/v1/ai-feedback`)에 직접 요청해 받은 응답:

```json
{"mock":true,"speechText":"아직 끓지 않으면 1분 더 끓이고, 기포가 올라오면 다음 단계로 넘어가세요."}
```

김치볶음밥 + "불이 너무 센 것 같아요"로 물어도 같은 문구가 돌아왔고,
`screenText`·`suggestedAction`·`eventPayload`가 모두 없었다.

원인은 backend `29c0c99 조리 중 AI 피드백 정말 단순하게 질문-답변만 구현 (#41)`
이다. `AiFeedbackResponse`에서 `screenText`, `suggestedAction`, `eventPayload`와
`SuggestedAction` 스키마 자체가 사라졌다. 사본 `docs/openapi.json`은 이 커밋
직전에 떠 온 것이라 3시간 만에 낡았고, `openapi-drift` 잡이 이를 잡아냈다.

요청 쪽 `AiFeedbackRequest`는 원래부터 `recipeId`·`stepIndex`·`userSpeech`
셋뿐이었다. 프론트는 여기에 `instruction`과 `remainingSeconds`를 더 보내고
있었는데, Spring이 모르는 필드를 무시하는 기본 설정 덕에 400이 나지 않고
조용히 버려지고 있었다. 스펙 필드만 담은 요청과 앱이 실제로 보내는 요청을
각각 던져 응답이 완전히 같음을 확인했다.

## 검토한 대안

1. **프론트를 그대로 두고 backend 복구를 기다린다** — 계약에 없는 필드를
   계속 보내고, 서버가 절대 주지 않는 `suggestedAction`을 기다리는 코드가
   남는다. 언제 돌아올지 모르는 값을 위해 UI와 검증 로직을 유지하는 비용이
   크고, 코드가 실제 동작을 설명하지 못하게 된다.
2. **응답을 관대하게 읽어 두 계약을 모두 지원한다** — 요청하지 않은
   유연성이다. 지금 서버가 주지 않는 필드를 파싱하는 분기는 테스트로만
   덮이는 죽은 경로가 된다.
3. **현재 스펙에 정확히 맞춘다(채택)** — 보내는 것과 받는 것을 지금 계약과
   일치시킨다. 되돌릴 필요가 생기면 backend가 스키마를 되살릴 때 함께
   복구한다.

## 최종 결정

- `docs/openapi.json`을 backend main과 바이트 동일하게 갱신했다.
- 요청 본문에서 `instruction`, `remainingSeconds`를 뺐다. 이에 따라
  `ExceptionAdviceContext`에서도 두 필드를 제거했다. 서버가 읽지 않는 값을
  화면이 계산해 넘기는 구조를 남겨두면 코드가 거짓말을 한다.
- 응답에서 `screenText` 읽기를 없앴다. `ExceptionAdvice`의 화면/음성 텍스트
  분리 자체는 TTS 수명 주기가 쓰는 구분이라 유지하고, HTTP 어댑터가 두 값을
  같은 `speechText`로 채운다.
- `suggestedAction`·`eventPayload` 관련 코드를 걷어냈다.
  `ExceptionAdviceSuggestedAction`, `ExceptionAdviceActionType`,
  `_decodeSuggestedAction`, `_decodeEventPayload`, `_safeSuggestedAction`,
  `_applySuggestedAction`, `제안 적용` 버튼(`help-suggested-action`)이 대상이다.
  타이머 연장은 음성 명령(F-07)과 화면 버튼 경로에만 남는다.
- `mock`은 계약에 남아 있으므로 계속 읽되, 억제할 행동 제안이 없으므로 표시
  동작을 바꾸지 않는다.
- 로컬 개발용 `env.dev.json`을 `.gitignore`에 넣고 `env.example.json`을 추가했다.
  개인 백엔드 주소가 커밋에 섞이지 않게 하고, 실행에 필요한 키 이름은 예시
  파일로 남긴다.

## 검증

- `dart format .` / `flutter analyze`(0건) / `flutter test`(377개 통과)
- 실기기(SM A528N)에 설치해 구동하고, PC와 기기 양쪽에서 실서버에 직접 요청해
  `users/anonymous` 201, `recipes` 200, `ai-feedback` 200을 확인했다.
- 스펙 필드만 담은 요청과 기존 요청의 응답이 동일함을 확인해
  `instruction`·`remainingSeconds`가 서버에서 무시된다는 것을 실증했다.
- `diff docs/openapi.json <backend main>`이 비어 있어 `openapi-drift` 잡을
  통과한다.

## 이후 작업에서 지킬 것

- 단계 문맥을 Gemini에 반영하려면 프론트에서 필드를 되살리는 게 아니라
  backend `AiFeedbackRequest`가 `instruction`·`remainingSeconds`를 받아야
  한다. 개인 버전에서 ADD/REMOVE로 재인덱싱된 실행 스냅샷은 `stepIndex`만으로
  복원할 수 없다.
- `suggestedAction`이 backend에 돌아오면 이 커밋을 참고해 UI와 30/60초
  화이트리스트 검증을 함께 복구한다. 화이트리스트 없이 되살리지 않는다.
- 배포된 서버가 아직 `mock: true` 고정 답변을 준다. 실제 Gemini 연동 확인은
  배포 이후에 다시 한다.
