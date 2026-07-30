# F-07 조리 음성 명령 라우터

## 목적

`CookingVoiceRouter`는 STT가 확정한 한 문장을 조리 화면이 처리할
`VoiceIntent`로 분류한다. 순수 Dart 코드이며 STT SDK, 화면 상태, 네트워크,
F-08 답변 로직에 의존하지 않는다.

구현 파일:
`lib/features/cooking/domain/cooking_voice_router.dart`

## 공개 계약

```dart
enum VoiceIntentType {
  next,
  previous,
  repeat,
  currentStep,
  startTimer,
  extendTimer,
  pauseTimer,
  resumeTimer,
  finish,
  exceptionQuestion,
  ignore,
}

final class VoiceIntent {
  const VoiceIntent(this.type, {this.seconds = 0});
}

const CookingVoiceRouter().route(
  transcript,
  recipeTitle: recipeTitle,
  ingredientNames: ingredientNames,
  currentStepInstruction: currentStepInstruction,
);
```

`seconds`는 `extendTimer`에서만 사용한다. 숫자 또는 제한된 한국어 분 표현을
초로 변환하고, 기존 MVP의 안전 범위와 동일하게 15초 이상 600초 이하로
보정한다. 다른 intent에서는 항상 기본값 0이다.

## 분류 우선순위

한 문장에 여러 단서가 있으면 다음 순서를 적용한다.

1. 명시적인 조리 문제·안전 패턴
2. 질문 신호와 조리 문맥의 동시 존재
3. 로컬 타이머 명령
4. 완료·단계 이동·반복·현재 단계 명령
5. 그 외 `ignore`

문제·질문을 로컬 substring 명령보다 먼저 검사하는 것이 핵심이다.

예를 들어 `다음에 소금 넣는 게 맞아?`에는 `다음`이 있지만, `맞아`라는
질문 신호와 현재 레시피 재료 `소금`이 함께 있다. 따라서 `next`가 아니라
`exceptionQuestion`으로 분류한다.

## 질문과 문제 서술

질문은 `어떻게`, `왜`, `뭐`, `몇`, `얼마나`, `맞아`, `해야`, `할까`,
물음표 등의 신호와 조리 문맥이 모두 있어야 한다. 조리 문맥은 다음 두
종류를 합쳐 매 호출마다 만든다.

- 공통 문맥: 온도, 시간, 소스, 반죽, 양념, 냄비, 팬, 고기, 기름, 불, 간,
  끓임 등
- 현재 레시피 문맥: 레시피 제목·현재 단계 문장의 2글자 이상 토큰과
  `물`, `면`, `쌀`, `파` 같은 한 글자 한국어 재료명

질문형이 아니어도 사용자가 바로 도움을 받아야 하는 문제 서술은
`exceptionQuestion`으로 보낸다.

- 조리 실패: `물이 안 끓어`, `덜 익었어`, `안 익어`, `너무 짜`,
  `너무 묽어`, `눌어붙었어`
- 재료 부족: `재료가 없어`, 현재 재료 이름과 `없어/다 썼어/떨어졌어`
- 안전: 기름불, 가스 냄새, 변질·곰팡이, 덜 익은 육류, 화상·칼 베임

이 라우터는 답을 만들지 않는다. `exceptionQuestion`을 받은 상위 계층이
F-08의 로컬 안전 응답 또는 원격 조리 코치로 전달해야 한다.

## 로컬 명령

| intent | 대표 발화 |
| --- | --- |
| `next` | `다음 단계`, `넘어가` |
| `previous` | `이전으로`, `전 단계`, `뒤로` |
| `repeat` | `다시 말해줘`, `한 번 더 읽어줘`, `못 들었어` |
| `currentStep` | `지금 뭐 해야 해?`, `현재 단계` |
| `startTimer` | `타이머 시작`, `요리 시작` |
| `extendTimer` | `30초 더`, `2분 추가`, `삼 분 연장` |
| `pauseTimer` | `타이머 멈춰`, `일시 정지` |
| `resumeTimer` | `다시 시작`, `타이머 재개`, `계속해` |
| `finish` | `조리 완료`, `요리 끝`, `다 끝났어` |

명확한 전체 조리 완료 문구는 단계 완료에 쓰이는 `됐어`보다 우선한다.
재개 문구도 `다시 말해줘`와 충돌하지 않도록 반복보다 먼저 검사한다.

## 오탐 방지 경계

- `오늘 어떻게 집에 가지?`처럼 질문이지만 조리 문맥이 없으면 `ignore`
- `소스를 넣었어`처럼 조리 문맥만 있고 문제·질문 신호가 없으면 `ignore`
- `오늘 시간이 없어`의 `없어`는 재료 부족으로 보지 않음
- `진짜`, `가짜`, `요리 계획을 짜`의 `짜`는 짠맛 문제로 보지 않음
- `다음 주에 장 보러 가자`의 `다음`은 단계 이동 명령으로 보지 않음

## 테스트

`test/features/cooking/domain/cooking_voice_router_test.dart`에서 다음을
검증한다.

- 단계·타이머·완료 명령과 intent 값
- 숫자/한국어 타이머 연장 및 15~600초 보정
- 질문이 substring 명령보다 우선하는 충돌
- 질문형이 아닌 조리 문제·안전 서술
- 한 글자 한국어 재료가 포함된 질문·재료 부족 서술
- 무관한 질문, 정상 조리 서술, 알려진 한국어 substring 오탐

## 범위 밖

- STT 권한과 인식 시작/종료
- 타이머 또는 조리 세션 상태 변경
- 예외 질문의 로컬/원격 답변 생성
- TTS 출력

이 항목들은 라우터의 반환값을 소비하는 application/presentation 계층에서
연결한다.
