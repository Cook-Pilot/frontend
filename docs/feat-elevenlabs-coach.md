# feat/elevenlabs-coach — 음성 코치 ElevenLabs Agents PoC

## 문제 상황

Gemini Live 직결 코치(only-api)는 실기기(A52)에서 self barge-in을 half-duplex
게이트로 막았지만, 그 대가로 코치 발화 중 음성 가로채기를 잃었다(탭 버튼으로 대체).
레벨(RMS) 기반 음성 판별은 실측으로 불가 판정 — AEC 잔여 에코(RMS ~936)가 사용자
목소리(~305)보다 3배 컸다. 근본 원인은 마이크(record)와 재생(flutter_pcm_sound)이
분리된 플러그인이라 참조 신호 기반 AEC를 쓸 수 없는 구조.

## 검토한 대안

1. **WebRTC APM 네이티브 직접 통합** — 참조 신호 AEC를 우리가 감는 것. Gemini 유지
   가능하지만 네이티브 작업 며칠 + 기기 튜닝. 보류.
2. **LiveKit + Gemini Live** — Gemini 유지 + full-duplex. 백엔드에 에이전트 서버
   운영이 추가돼 PoC로는 무겁다. 장기 후보로 남김.
3. **ElevenLabs Agents SDK** — WebRTC(LiveKit) 스택이 SDK에 내장, 에코 캔슬·음성
   barge-in·턴테이킹이 그대로 나온다. 분당 과금(무료 15분/월)이지만 PoC 목적에
   가장 빠르다 — 채택.

## 최종 결정

- 브랜치는 only-api에서 파생. `CookingCoachEngine` 인터페이스를 추출해 화면이
  엔진을 갈아 끼운다 — Gemini 경로는 그대로 두고 컴파일 타임 선택:
  `--dart-define COACH_ENGINE=elevenlabs` (기본값은 Gemini 직결).
- `cooking/data/elevenlabs_coach_controller.dart` — `elevenlabs_agents` SDK 래퍼.
  오디오 포트 없음(SDK가 마이크·재생·AEC 소유), `interrupt()`는 no-op(음성
  barge-in 내장), 화면의 탭 가로채기 버튼은 이 엔진에서 숨긴다.
- 레시피 컨텍스트는 세션 `overrides.agent.prompt`로 주입(화면이 Recipe로 생성).
  Gemini 경로의 "백엔드가 토큰에 잠금"과 달리 클라이언트 주입이다 — PoC 한정
  타협이고, 정식 도입 시 백엔드 conversation token 발급으로 옮긴다.
- 에이전트 ID는 `--dart-define ELEVENLABS_AGENT_ID=...`(env.dev.json, 미커밋).

## ElevenLabs 대시보드 설정 (수동, 1회)

1. https://elevenlabs.io 가입 → Agents → Create agent
2. 설정: LLM(Gemini Flash 계열 권장), 언어 `Korean`, 목소리 선택,
   first message는 짧은 한국어 인사
3. **Security(또는 Advanced) → Overrides에서 system prompt override 허용** —
   안 켜면 레시피 컨텍스트 주입이 조용히 무시된다
4. PoC는 public agent로 시작(인증 없음) → agent_id 복사
5. `env.dev.json`의 `ELEVENLABS_AGENT_ID`에 붙여넣고
   `flutter run --dart-define-from-file=env.dev.json`

## 검증

- `dart format`·`flutter analyze` 0건, 기존 테스트 회귀 없음(engine 인터페이스
  추출은 기존 팩토리 주입과 호환).
- ElevenLabs 어댑터는 SDK 콘크리트 클래스 래핑이라 단위 테스트 없이 실기기
  검증으로 대신한다(PoC). 정식 도입 시 세션 경계를 포트로 추출해 테스트 추가.
- 실기기 E2E(에이전트 생성 후): 연결 → 한국어 대화 → **말하는 도중 음성으로
  끊기(핵심 검증 항목)** → 화면 이탈 시 자동 종료.

## 이후 작업에서 지킬 것

- 분당 과금 — 무료 티어 15분/월. 테스트 세션은 짧게 끊을 것.
- PoC 판정 기준: 음성 barge-in 체감 + 한국어 턴테이킹 품질이 Gemini 경로 대비
  확실히 나은가. 아니면 LiveKit+Gemini(대안 2)로 회귀.
- 정식 도입 시: private agent + 백엔드 conversation token 발급, 프롬프트 주입을
  서버로 이동, 세션 결과(대화 로그)를 리뷰 흐름에 연결할지 결정.
