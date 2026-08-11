# only-api — 조리 중 음성 코치를 Gemini Live 오디오 직결로 전환

## 문제 상황

조리 중 AI 도움은 텍스트 한 턴짜리 백엔드 프록시(`POST /api/v1/ai-feedback`)였다. 음성 코치를
Live 급 지연(첫 오디오 1초 미만)으로 만들려면 STT→LLM→TTS 조립로는 부족해서, 백엔드 `only-api`
브랜치가 Gemini Live API(WebSocket 오디오 양방향)를 전제로 **ephemeral token 발급 엔드포인트**
(`POST /api/v1/ai-sessions`, 커밋 `f23b95b`)를 추가했다. 프론트가 Live WebSocket에 직접 붙어야
한다.

## 검토한 대안

1. **앱에 API 키를 넣고 텍스트 한 턴 직결** — 중간에 실제로 구현까지 했다가 폐기. 키가 앱
   바이너리에 박혀 추출 가능하고, 백엔드 ephemeral 설계(AUDIO 모달리티 잠금)와 호환되지 않는다.
2. **백엔드 WebSocket 프록시** — 홉 지연과 오디오 중계 코드만 늘린다(백엔드 문서의 판단 공유).
3. **오디오 풀 직결 + 서버는 토큰 발급만** — 채택.

## 최종 결정

### 백엔드 계약

- `POST /api/v1/ai-sessions` 요청 `{recipeId}` → 응답 `{token, model}`.
  400/404/409(키 미설정 — 조용한 fallback 없이 사용자에게 실패를 그대로 보여준다).
- 토큰은 `auth_tokens/...` 1회용, 발급 후 1분 내 연결 시작, 전체 30분. 모델·AUDIO 모달리티·
  systemInstruction(안전 원칙 + 레시피 전문)이 토큰에 잠겨 있어 클라이언트는 오디오만 흘린다.

### Live WebSocket 와이어 포맷

- 엔드포인트: `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.`
  `v1beta.GenerativeService.BidiGenerateContentConstrained?access_token=<token>`
  (ephemeral token은 v1beta의 Constrained 메서드에서만 인증된다. 처음 붙였던
  v1alpha `BidiGenerateContent`는 1008 unregistered callers로 거절 — 2026-08-11 실측.)
- setup은 `{"setup": {"model": "models/<model>"}}`만 보내고 `setupComplete`를 기다린다.
- 업로드: `realtimeInput.audio = {data: base64, mimeType: "audio/pcm;rate=16000"}`
  (PCM16 LE·16kHz·모노). 수신: `serverContent.modelTurn.parts[].inlineData`(24kHz PCM16).
- `serverContent.interrupted == true`(barge-in) → 재생 큐 즉시 비움. 그 외 메시지는 무시.
- 메시지는 바이너리 프레임일 수 있어 UTF-8 디코드 후 JSON 파싱한다.

### 프론트 구조 (포트/어댑터 패턴 유지)

- `cooking/application/cooking_ports.dart` — `AiLiveSessionPort`(토큰 발급),
  `CoachLiveSessionPort`(1회용 Live 세션), `CoachAudioInputPort`(마이크 16kHz),
  `CoachAudioOutputPort`(재생 24kHz, flush=barge-in), `CoachSessionException`.
- `cooking/data/ai_live_session_api.dart` — 토큰 발급 HTTP 어댑터. 상태코드를 한국어 안내로 번역.
- `cooking/data/gemini_live_coach_session.dart` — WebSocket 세션. `GeminiLiveConnection`
  추상화로 테스트에서 fake 전송 계층 주입.
- `cooking/application/cooking_coach_controller.dart` — 세션 수명 소유: 토큰 발급→즉시 연결
  (1분 제한)→재생 준비→마이크 스트림 업로드. 세대(generation) 가드로 낡은 콜백 차단.
  **half-duplex 게이트**: 재생 잔량+400ms 동안 마이크 업로드 중단 — 실기기(A52)에서
  하드웨어 AEC(voiceCommunication 경로)로도 self barge-in을 못 막아 채택.
  **가로채기는 탭**: 레벨(RMS) 기반 음성 barge-in은 폐기 — A52 실측에서 AEC 잔여
  에코(RMS ~936)가 사용자 목소리(~305)보다 3배 커서 문턱값이 존재하지 않는다.
  대신 `interrupt()`(코치 패널 `coach-interrupt` 버튼)가 재생을 비우고 마이크를
  열며, 서버가 스트리밍 중이던 턴의 나머지는 턴 경계(turnComplete/interrupted)까지
  버린다. 코치 침묵 후 0.4초부터는 음성이 자연히 통한다.
- `cooking/presentation/record_coach_audio_input.dart` — record 패키지, PCM16·16kHz·모노,
  에코 캔슬 켬 + 통화용 경로(voiceCommunication·modeInCommunication·speakerphone)로
  하드웨어 AEC를 걸어 에코 자체를 줄인다(게이트의 보조).
- `cooking/presentation/pcm_coach_audio_output.dart` — flutter_pcm_sound. 큐 비우기 API가
  없어 flush는 release+setup 재초기화. iOS는 `playAndRecord` 카테고리(마이크 동시 사용).
- `CookSessionScreen` — "AI 코치" 토글 버튼(`coach-toggle`). 마이크는 하나뿐이므로 코치를 켤 때
  명령 STT·TTS를 내리고 핸즈프리 재가동을 막는다. 코치 활성 중 말하기 버튼은 안내만 표시.
  화면 이탈(paused/hidden/detached)·조리 완료 시 코치 자동 종료.
- 타이핑 도움 질문(HelpQuestionSheet)은 기존 `/api/v1/ai-feedback` 경로 유지.

### UI 배치 제약

버튼 Row 아래에 전폭 버튼을 추가하면 도움 답변 영역이 ListView lazy-build 범위 밖으로 밀려
`cook_session_help_test`의 501자 안내 테스트가 깨진다. 코치 버튼은 기존 Row의 세 번째 칸에
넣어 레이아웃 높이를 바꾸지 않았다.

## 검증

- 신규 테스트: `ai_live_session_api_test`(발급·상태코드 번역), `gemini_live_coach_session_test`
  (setup/오디오 인코딩/interrupted/서버 종료 vs 로컬 종료), `cooking_coach_controller_test`
  (수명·실패 경로·dispose 가드). `dart format`·`flutter analyze` 0건, `flutter test` 410개 통과.
- 실기기 E2E(실키 백엔드 → 토큰 발급 → 오디오 대화)는 아직 안 함 — 아래 후속.

## 이후 작업에서 지킬 것

- 토큰은 발급 즉시 연결에 쓰고 보관·재사용하지 않는다(uses=1, 1분 제한).
- 코치와 명령 STT는 마이크를 공유할 수 없다 — 어느 쪽이든 켜기 전에 상대를 내린다.
- 후속: 실기기 E2E(모델 preview 이름 변동 시 백엔드 `GEMINI_LIVE_MODEL`로 교체),
  Live 세션 상한 도달 시 resume 토큰 대응, 세션 결과를 리뷰에 싣는 계약(프론트·백엔드 미확정),
  코치 청취 상태 시각 피드백 등 UX 다듬기.
