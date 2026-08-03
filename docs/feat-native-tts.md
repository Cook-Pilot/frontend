# 네이티브 TTS 조리 안내

## 범위

`NativeSpeechOutput`은 `SpeechOutputPort`를 `flutter_tts`에 연결해 조리 화면의
시각 안내를 한국어 음성으로도 전달한다. 새 조리 세션과 홈에서 복원한 세션 모두
별도 출력 인스턴스를 소유하며, 테스트의 기본값은 네이티브 채널을 열지 않는
`DemoSpeechOutput`이다.

## 재생 규칙

- 알림 권한 초기화와 첫 프레임이 끝난 뒤 현재 단계를 한 번 읽는다.
- 단계 이동, 현재 단계·반복 명령, F-08 예외 답변을 재생한다.
- F-08은 현재 request version과 단계 ownership을 통과한 `speechText`만 읽고,
  안전 설명용 `screenText`는 화면에 그대로 유지한다.
- 새 발화는 이전 재생을 중지한 뒤 시작한다. 단계 이동, 새 질문, 조리 완료,
  뒤로가기, 앱 비활성화와 화면 dispose도 이전 재생을 무효화한다.
- TTS가 오디오 세션을 소유하는 동안 STT를 열지 않는다. 출력이 끝나거나
  사용자가 말하기 버튼으로 출력을 취소한 뒤에만 명시적으로 선택한 핸즈프리를
  다시 시작한다.

## 비동기 안전성

stop, configure, speak 시작은 직렬화하고 각 요청에 version ownership을 둔다.
큐에서 이미 폐기된 요청은 네이티브 stop을 반복하지 않아 고장 난 엔진의
`stopTimeout`이 요청 수만큼 누적되지 않는다.

iOS의 `flutter_tts`는 취소된 발화의 `speak` Future를 완료하지 않을 수 있다.
따라서 네이티브 완료와 로컬 cancellation Future를 경합시켜 새 발화, stop,
dispose 시 화면의 대기를 즉시 해제한다. 늦게 도착한 네이티브 완료나 오류는
소비하되 새 출력의 상태를 바꾸지 않는다.

설정과 재생에는 각각 제한 시간을 둔다. 설치된 한국어 음성이나 TTS 엔진이
없거나 플랫폼 채널이 실패해도 단계 버튼, 타이머, AI 화면 답변과 완료 저장은
계속 사용할 수 있다.

## 플랫폼 설정

- 공통: `ko-KR`, speech rate `0.48`, pitch `1.0`, volume `1.0`, audible
  completion 대기
- Android 11+: manifest의 `android.intent.action.TTS_SERVICE` package
  visibility query
- iOS: 별도 권한은 필요하지 않으며 Flutter 플러그인 등록을 사용한다.

## 검증

- 네이티브 설정 1회와 매 발화 전 queue flush
- 빠른 연속 발화, stop timeout, 폐기된 control queue
- iOS형 미완료 playback의 stop/dispose와 늦은 오류
- 초기 단계, 단계 이동, 반복·현재 안내와 F-08 답변 ownership
- TTS 중 STT 차단과 안전한 핸즈프리 재시작
- 앱 lifecycle, 조리 완료·저장 실패, 뒤로가기와 dispose
- Android debug APK 빌드

iOS 네이티브 빌드는 현재 로컬 도구 체인이 준비되지 않아 정적 분석과 Flutter
테스트까지만 검증했다.
