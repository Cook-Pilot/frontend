# F-09 후기 초안 로컬 저장 기반

## 목적

사용자가 조리를 완료한 뒤 후기 화면에서 앱을 종료해도 완료한 조리의 문맥과
작성 중인 후기를 잃지 않도록 로컬 복구 단위를 정의한다.

이 PR은 화면을 연결하거나 서버에 후기를 전송하지 않는다. 후속 PR이 사용할
`PendingReviewDraft` 모델과 `SharedPreferences` 저장소만 추가한다.

## 저장 범위

데모에서는 작성 중인 후기 한 건만 보관한다. 새 조리를 완료해 새 초안을
저장하면 이전 초안을 교체한다.

| 필드 | 의미 |
| --- | --- |
| `clientSessionId` | 같은 조리완료 요청을 다시 식별할 UUID |
| `cookedAt` | 실제 조리를 완료한 시각의 UTC instant |
| `setupSnapshot` | 조리 시작 때 확정된 레시피·재료·단계·인분 |
| `timerSecondsByStep` | 조리 중 사용자가 실제로 조정한 단계별 타이머 |
| `rating` | 필수 별점, 1~5 |
| `comment` | 작성 중인 후기 본문 |
| `nextTimeNote` | 다음 조리를 위한 메모 |
| `approvedPersonalVersionCreation` | 개인 버전 생성을 사용자가 승인했는지 여부 |

`setupSnapshot`과 타이머를 함께 보관하는 이유는 앱 재실행 후 현재 서버
레시피를 다시 조회해 후기 문맥을 만들지 않기 위해서다. 예를 들어 사용자가
조리 전에 두부 양을 늘리고 2단계 타이머를 연장했다면, 원본 레시피가 아니라
그 조리에서 실제 사용한 실행 스냅샷과 시간을 복원한다.

개인 버전 승인 여부도 초안의 일부다. 후기 텍스트가 복원되더라도 이 값이
유실되면 앱이 사용자의 승인 없이 개인 버전을 만들거나, 이미 승인한 선택을
다시 묻게 될 수 있기 때문이다.

## 저장 형식

SharedPreferences의 다음 단일 문자열 키에 JSON을 저장한다.

```text
cookpilot.pending_review_draft.v1
```

최상위 JSON에는 `schemaVersion: 1`을 포함한다. 필드가 빠졌거나 알 수 없는
필드가 추가된 값은 현재 코드가 의미를 확정할 수 없으므로 복원하지 않는다.
후기 초안에 포함된 `setupSnapshot`도 현재 버전의 스냅샷·재료·단계 필드
집합과 정확히 일치해야 한다. `personalVersionId`, `originalIngredientId`,
`amount`, `baselineAmount`, `originalStepId`, `timerSeconds`, `cautionNote`처럼
값이 `null`일 수 있는 필드도 키 자체는 반드시 존재해야 한다. 이 엄격한
경계는 후기 복구에만 적용하며, 다른 저장소의 과거 실행 스냅샷을 읽는
`CookingSetupSnapshot.fromJson`의 하위 호환 기본값은 유지한다.

예시는 다음과 같다.

```json
{
  "schemaVersion": 1,
  "clientSessionId": "40000000-0000-0000-0000-000000000001",
  "cookedAt": "2026-07-30T08:30:00.000Z",
  "setupSnapshot": {
    "schemaVersion": 1,
    "recipeId": "10000000-0000-0000-0000-000000000001",
    "title": "두부 조림",
    "description": "짭조름한 두부 반찬",
    "imageUrl": "",
    "baseServings": 2.0,
    "targetServings": 2,
    "source": "base",
    "personalVersionId": null,
    "ingredients": [],
    "steps": []
  },
  "timerSecondsByStep": {
    "0": 180
  },
  "rating": 4,
  "comment": "맛있었어요",
  "nextTimeNote": "다음에는 덜 짜게",
  "approvedPersonalVersionCreation": false
}
```

실제 `setupSnapshot.steps`는 한 개 이상이어야 하므로 위 JSON은 형식 설명을
간단히 하기 위한 축약 예시다.

## 검증 경계

모델 생성과 저장값 복원에 같은 검증을 적용한다.

- `clientSessionId`, 레시피 ID, 개인 버전 ID, 원본 재료·단계 ID는
  소문자 canonical UUID 형식이어야 한다.
- nil UUID는 조리 식별자로 사용하지 않는다.
- `cookedAt` 저장값은 `DateTime.toIso8601String()`이 생성하는 canonical UTC
  형식과 정확히 일치해야 한다. 날짜 normalization, offset, zone 생략,
  비정규 fractional second 표현은 복원하지 않는다.
- 실행 스냅샷의 source와 `personalVersionId` 존재 여부가 일치해야 한다.
- 실행 스냅샷의 `baseServings`는 양의 finite 숫자여야 하며, 각 재료의
  `amount`와 `baselineAmount`는 `null`이거나 finite 숫자여야 한다. `NaN`과
  양·음의 infinity는 거부한다.
- 단계 index는 0부터 연속이어야 한다.
- 실행 단계의 기본 타이머와 타이머 map의 override 초 값은 음수가 아니고
  32-bit signed integer 상한을 넘지 않아야 한다. 타이머 map의 index도 실행
  스냅샷 단계 안에 있어야 한다.
- 별점은 필수이며 1~5다.
- `comment`는 Unicode code point 기준 1,000자,
  `nextTimeNote`는 500자까지 허용한다.
- 사용자 입력의 앞뒤 공백은 초안이므로 그대로 보존한다. 서버 확정 전송
  시점의 trim·빈 문자열 정규화는 후속 네트워크 PR이 담당한다.
- PostgreSQL 문자열에 저장할 수 없는 NUL과 짝이 맞지 않는 surrogate는
  거부한다.

문자 수는 Dart의 UTF-16 code unit 수가 아니라 Unicode code point로 센다.
따라서 `🍳` 같은 emoji 하나를 두 글자로 잘못 계산하지 않는다.

## 동시 저장 순서

후기 입력 autosave는 짧은 간격으로 연속 호출될 수 있다. SharedPreferences
쓰기 완료 순서를 그대로 신뢰하면 다음 상황이 생길 수 있다.

1. 별점 3, 본문 `조금 짰다` 저장을 시작한다.
2. 사용자가 별점 4, 본문 `파를 더 넣으면 좋겠다`로 수정해 새 저장을 시작한다.
3. 두 번째 저장이 먼저 끝난다.
4. 늦게 끝난 첫 번째 저장이 최신 초안을 덮어쓴다.

`PendingReviewDraftStore`는 모든 인스턴스가 공유하는 직렬화 큐에서
`save`, `load`, `clear`를 호출 순서대로 처리한다. 따라서 앞선 쓰기가
끝나기 전 다음 쓰기를 시작하지 않으며, 마지막으로 요청한 초안이 최종
저장값이 된다. 한 작업이 실패해도 큐는 다음 작업을 계속 실행한다.
SharedPreferences의 플랫폼 저장이나 삭제가 `false`를 반환하거나 예외를
던지면, 선반영 또는 선삭제된 메모리 캐시를 디스크 상태로 다시 불러온 뒤
오류를 전달한다. 따라서 미저장 초안이 복구값처럼 보이거나, 실제로 남은
초안이 사라진 것처럼 보이지 않는다.

## 손상값 처리

다음 값은 복구하지 않고 해당 SharedPreferences 키를 정리한다.

- 문자열이 아닌 값
- JSON 문법 오류
- 지원하지 않는 schema version
- 누락되거나 추가된 최상위 필드
- 잘못된 UUID·별점·후기 길이·비정규 `cookedAt`
- 손상된 실행 스냅샷
- 실행 단계 밖을 가리키거나 지원 범위를 벗어난 기본·override 타이머 값

손상값 제거 자체가 일시적으로 실패해도 앱에는 그 값을 반환하지 않는다.
다음 `load`에서 정리를 다시 시도한다. 정상 `save`와 명시적 `clear`의 저장소
오류뿐 아니라 저장소를 열지 못한 `load` 오류도 호출자에게 전달한다. 따라서
후속 화면은 저장소 장애를 `복구할 초안 없음`으로 오인하지 않고 재시도를
제공할 수 있다.

## 후속 PR 연결

후속 작업은 이 저장소를 다음 순서로 사용한다.

1. 조리완료 버튼을 누르면 후기 화면으로 이동하기 전에 최초 초안을 저장한다.
2. 별점·후기·다음 메모·개인 버전 승인 변경을 debounce해 같은 초안으로 저장한다.
3. 앱 시작 시 초안이 있으면 후기 복구 진입점을 표시한다.
4. 개인 버전을 승인하지 않았으면 후기 저장 성공 뒤에, 승인했으면 개인 버전
   생성 요청까지 `201` 또는 `204`로 끝난 뒤에만 `clear`한다.

서버 전송 실패나 앱 종료 시에는 초안을 지우지 않는다. 반대로 이 PR만으로는
서버 완료 저장, 멱등 재전송, 후기 화면 자동 복원이 동작하지 않는다.

## 검증

`test/features/review/application/pending_review_draft_store_test.dart`에서
다음을 확인한다.

- 모든 복구 필드의 JSON·SharedPreferences 왕복
- emoji를 포함한 후기 code point 상한
- UUID·별점·NUL·잘못된 Unicode 거부
- canonical UTC `cookedAt`과 잘못된 날짜·offset·fraction 거부
- 실행 스냅샷의 재료 수치·타이머 index·기본/override 초 범위 무결성
- 여러 store 인스턴스의 동시 저장 직렬화
- 앞선 저장 실패 뒤에도 다음 작업이 진행되는 큐 복구
- 플랫폼 저장·삭제 실패 뒤 메모리 캐시와 실제 저장값의 재동기화
- 저장소 초기화 실패를 `초안 없음`으로 숨기지 않는 오류 전달
- 단일 초안 교체와 명시적 clear
- 손상된 타입·JSON·스키마·도메인 값 자동 정리
