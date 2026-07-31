# F-09 후기 흐름 UI 연결

## 목적과 범위

조리 완료 시점의 실행 문맥을 `PendingReviewDraft`로 먼저 보존하고, 후기 화면에서
작성·전송·개인 버전 승인까지의 상태를 같은 초안으로 연결한다. 이 문서는
`lib/features/mvp/cook_flow_screens.dart`의 UI 흐름, Home 복구 진입점과 기존
draft/API 계약의 연결 경계를 설명한다.

## 조리 완료와 draft 전환

마지막 단계에서 `조리 완료`를 누르거나 음성 완료 명령이 들어오면, 화면은 다음
순서로 진행한다.

1. 최초 요청에서만 `clientSessionId`, 완료 시각, 실행 snapshot, 실제 단계별
   타이머, 기본 별점/빈 텍스트/미승인 상태를 가진 draft를 만든다. 저장 실패 뒤
   재시도해도 이 draft를 재사용하므로 완료 사실과 조리 문맥이 바뀌지 않는다.
2. 후기 화면으로 이동하기 전에 draft를 로컬에 저장한다.
3. 저장에 성공하면 active `CookingSessionStore`를 정리하고 `ReviewScreen`으로
   교체 이동한다. active-session 정리가 실패해도 pending draft가 canonical 복구
   단위이므로 이동은 계속한다.
4. draft 저장에 실패하면 네트워크나 화면 전환을 하지 않고, 진행 중 조리 세션을
   유지한 채 오류를 표시한다. 완료 직전 active-session 저장도 실패했을 수 있으므로
   dedupe 여부와 무관하게 같은 세션을 한 번 더 저장한다. 사용자는 같은 완료 버튼으로
   재시도할 수 있다.

완료 처리 중에는 중복 완료를 막고, 완료가 확정된 뒤 타이머·음성 콜백이 active
세션을 다시 저장하지 않도록 차단한다. 최초 완료 요청에서 draft 문맥을 고정한 뒤에는
저장 성공 또는 실패 여부와 무관하게 타이머·단계·도움 행동을 잠가, 화면에서 바꾼
상태와 재시도 draft가 달라지지 않게 한다.

## 후기 작성과 로컬 내구성

후기 화면은 draft에서 별점, 코멘트, 다음 메모, 개인 버전 승인 여부를 초기화한다.
각 입력 변경은 300ms debounce autosave 대상이다. 앱이 `resumed` 이외 lifecycle
상태로 바뀌면 debounce를 기다리지 않고 flush하며, 화면 dispose 시에도 finalized
상태가 아니면 마지막 draft 저장을 시도한다.

시스템 뒤로가기는 최신 draft flush가 끝날 때까지 화면 이탈을 잠근다. 저장에
성공한 뒤에만 route를 닫고, 실패하면 입력을 화면에 유지한 채 오류와 재시도 경로를
보여준다. 따라서 사용자가 autosave 300ms 안에 내용을 고치고 바로 뒤로가더라도,
Home이 dispose 저장보다 먼저 이전 draft를 읽어 최신 입력을 덮는 경합이 생기지
않는다.

비동기 flush가 끝나기 전에 route pop을 허용할 수 없으므로 iOS의 edge-swipe
뒤로가기는 이 화면에서 비활성화한다. AppBar 뒤로가기와 Android 시스템
뒤로가기는 위 저장 경계를 거쳐 정상 동작한다.

## Home 복구 진입점

Home은 화면 진입과 당겨서 새로고침 시 pending review draft를 먼저 조회한다.
초안이 있으면 활성 조리 세션보다 우선해 `후기 작성 이어가기` 카드를 표시하고,
카드를 누르면 저장된 draft 전체를 `ReviewScreen`의 초기값으로 전달한다. 따라서
사용자가 저장 가능한 뒤로가기로 후기 화면을 닫더라도 Home에서 같은 입력과
`acceptedReviewId` 체크포인트로 다시 진입할 수 있다.

저장값은 `PendingReviewDraft` 검증을 통과해야 한다.

- 별점은 1~5다.
- 코멘트는 최대 1,000, 다음 메모는 최대 500 Unicode code point다. Flutter의
  UTF-16 code unit이 아니라 `runes` 기준으로 세므로 `🍳` 같은 emoji도 한 글자로
  취급한다.
- 화면 `TextField`도 같은 code point formatter와 카운터를 사용한다.
- 사용자 입력 공백은 draft에 그대로 보존한다. 서버 전송 시 API가 trim 후 빈 값을
  `null`로 바꾼다.

저장 flush가 실패하면 `임시 저장이 필요해요` 오류를 표시한다. 특히 `조리 기록 저장`
직전 flush가 실패하면 리뷰 API를 호출하지 않는다. 로컬 복구 단위를 확정하지 못한
상태에서 서버만 성공해 재시도 기준을 잃는 것을 막기 위한 경계다.

## 후기 저장과 개인 버전 승인

저장 버튼은 먼저 확정한 draft를 사용해 `POST /api/v1/reviews`를 호출한다. 이 요청은
후기 사실만 보낸다. 실행 재료 diff는 후기 요청에 섞지 않는다.

사용자가 개인 버전 생성을 승인한 경우에만, 후기 `201 Created`로 받은 `reviewId`에
대해 `POST /api/v1/reviews/{reviewId}/personal-versions`를 호출한다.

- 후기 POST 성공 직후에는 승인 API보다 먼저 `reviewId`를 draft의
  `acceptedReviewId`로 저장한다. 이 체크포인트 저장에 실패하면 승인 API를
  호출하지 않고 화면을 잠근 채 로컬 저장부터 재시도한다.
- 개인 버전 API의 `201 Created`는 생성 성공이고, `204 No Content`는 적용할 변경이
  없는 성공이다. 둘 다 최종 완료로 처리한다.
- 후기 저장은 성공했지만 승인 API가 실패하면 후기 API를 다시 보내지 않는다.
  같은 화면에서 저장 버튼을 다시 누르거나 화면을 나갔다가 Home 복구로 재진입해도
  보관한 `reviewId`로 승인 API만 재시도한다. 서버의 동일 reviewId 요청 멱등성도
  이 경로의 전제다.
- 사용자가 승인을 선택하지 않으면 후기 저장 성공만으로 최종 완료한다.

## 최종화와 정리 실패

후기와 필요한 승인 API가 성공한 뒤 autosave timer를 취소하고 `finalized` guard를
먼저 설정한다. 늦게 끝난 autosave나 lifecycle/dispose 저장이 clear 뒤 draft를
되살리는 것을 막는다.

그 다음 pending draft와 active cooking session을 각각 정리한다. 둘 중 하나의 정리가
실패해도 이미 서버에 저장된 조리 기록을 실패로 바꾸지 않는다. 성공 화면에
임시 데이터가 홈에 다시 표시될 수 있다는 경고를 함께 표시한다. 남은 draft가
복원되면 동일 `clientSessionId`와 `reviewId` 멱등 계약으로 안전하게 다시 완료할
수 있으며, Home의 `후기 작성 이어가기` 진입점에서 재개한다.

`CookingSessionStore`는 저장·삭제 API의 `false` 결과와 저장소 접근 예외를 성공으로
숨기지 않는다. 따라서 active session만 남은 정리 실패도 위 경고에 포함된다.

## 병합 전제

개인 버전 승인 API는 backend #37의 새 엔드포인트 계약을 전제로 한다. #37에는
기존 개인 버전을 사용자 범위로 조회하기 전에 후기 소유권을 확인할 수 있는 P1
ownership 지적이 있었으므로, 서버에서 사용자 범위 조회로 해결된 뒤 프론트와 함께
병합한다. 프론트가 자기 후기 ID만 보내더라도 서버 신뢰 경계 문제를 우회할 수는
없다.

## 테스트 체크리스트

- [x] 완료 탭/음성 완료에서 draft가 먼저 저장되고 성공 후에만 active 세션이
  정리되며 후기 화면으로 전환된다.
- [x] 완료 draft의 로컬 저장 실패는 전환과 네트워크를 막고, 같은 frozen draft로
  재시도할 수 있으며 active 세션 저장도 강제로 다시 시도한다.
- [x] 별점·두 텍스트·승인 토글의 300ms autosave, lifecycle flush, dispose flush가
  최신값을 보존한다.
- [x] 뒤로가기는 최신 draft 저장 완료를 기다리고, flush 실패 시 화면과 입력을
  유지해 이전 draft로 복구되는 경합을 막는다.
- [x] emoji를 포함해 코멘트 1,000 / 다음 메모 500 Unicode code point 경계가
  formatter와 `PendingReviewDraft` 양쪽에서 일치한다.
- [x] 저장 직전 draft flush 실패 시 `ReviewRepository.submit`가 호출되지 않는다.
- [x] 후기 `201` 후 승인 선택 시 개인 버전 `201` 및 `204`가 모두 완료 화면으로
  가고 draft/session이 정리된다.
- [x] 승인 API 실패 뒤 재시도는 후기 POST를 중복 호출하지 않고 같은 reviewId로
  승인 요청만 다시 보낸다.
- [x] 후기 ID 체크포인트 저장 실패는 승인 호출을 막고, 승인 실패 뒤 시스템
  뒤로가기·재진입도 같은 reviewId로 승인만 재시도한다.
- [x] 후기 화면을 뒤로 닫은 뒤 Home은 pending draft를 활성 조리 세션보다 먼저
  표시하고, 저장된 draft 전체를 같은 후기 흐름으로 다시 전달한다.
- [x] finalized 뒤 늦은 autosave/lifecycle/dispose 콜백이 clear된 draft를 되살리지
  않으며, draft 또는 session clear 실패는 성공 메시지와 cleanup warning을 함께
  표시한다.

관련 단위 테스트는 `test/features/review/application/pending_review_draft_store_test.dart`,
`test/features/review/data/review_api_test.dart`,
`test/features/review/data/personal_version_approval_api_test.dart` 및
`test/features/cooking/application/cooking_session_restore_test.dart`,
`test/features/mvp/review_flow_test.dart`,
`test/features/mvp/home_review_recovery_test.dart`에 둔다. 전체 테스트 수와 정적
분석 결과는 PR의 `확인` 항목에 기록한다.
