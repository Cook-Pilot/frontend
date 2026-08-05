# F-06 네이티브 STT 어댑터

## 범위

`NativeSpeechInput`은 기존 `SpeechInputPort`를 Android/iOS의
`speech_to_text` 플러그인에 연결한다. 화면과 F-07 Command Router는 후속
스택에서 연결됐고, 네이티브 출력은 `NativeSpeechOutput`으로 구현했다.
입출력 오디오 세션의 인계 규칙은 `feat-native-tts.md`를 따른다.

## 동작

- 조리 화면에서 전달한 `start` 한 번당 네이티브 인식 세션 하나만 연다.
- 한국어 locale `ko_KR`과 짧은 명령용 confirmation mode를 사용한다.
- 중간 인식 결과는 버리고 비어 있지 않은 final transcript만 전달한다.
- 각 final transcript에는 어댑터가 만든 고유 utterance ID를 붙인다.
- 중복 `start`는 현재 초기화·인식 세션을 교체하지 않고 무시한다.
- `stop`과 `cancel`은 모두 현재 결과를 폐기하는 네이티브 cancel로 닫는다.
  화면은 사용자가 중지를 누른 뒤의 final 결과를 사용하지 않으므로, 이전
  세션의 늦은 final이 빠르게 재시작한 다음 세션에 섞이는 것을 막는 쪽을
  택했다. 두 경우 모두 먼저 현재 generation을 무효화한다.
- 초기화, listen, stop/cancel은 직렬화되어 이전 세션 종료가 새 세션을
  취소하지 않는다.
- `speech_to_text`의 프로세스 singleton과 동일하게 production driver도
  하나를 공유한다. 재진입 시 전역 플러그인 listener가 현재 조리 화면의
  handler로 전달되도록 갱신한다.

## 실패 매핑

| 네이티브 상태 | `SpeechInputFailure` |
| --- | --- |
| 마이크·음성 인식 권한 거부 | `permissionDenied` |
| no-match, 음성 timeout, 네트워크, busy, 일시적 서버 오류 | `retryRequired` |
| 언어 미지원, recognizer 생성 실패·비활성/미설치, 플러그인 사용 불가 | `unavailable` |
| final transcript 없는 정상 종료 | `retryRequired` |

플러그인이 Android 오류를 대부분 permanent로 표시하므로 permanent 값만
사용하지 않고 알려진 오류 코드를 먼저 분류한다.

## 플랫폼 권한

- Android: `android.permission.RECORD_AUDIO`, Android 11+ 음성 인식 서비스
  package visibility query
- iOS: `NSSpeechRecognitionUsageDescription`,
  `NSMicrophoneUsageDescription`

## 검증

- final-only 전달과 `ko_KR`
- 중복 start 방지
- 세 실패 유형 매핑
- final 없는 종료 재시도
- stop/cancel 이후 늦은 callback 폐기
- 초기화와 stop의 비동기 경합
- 두 번째 조리 화면으로 callback handler 재연결
- `ListenFailedException`의 message/details 기반 오류 분류
