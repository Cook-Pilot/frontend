# F9 개인 레시피 승인 API 어댑터

## 목적

후기 저장과 개인 레시피 생성을 분리한 백엔드 PR #37 계약을 프론트에 연결한다.
사용자가 개인 버전 적용을 명시적으로 승인한 경우에만 application/UI caller가 이
어댑터를 호출한다. 이 PR은 승인 UI나 자동 호출을 추가하지 않는다.

기존 `ReviewRepository.submit`도 같은 계약에 맞춘다. `POST /reviews`에는 후기와
조리 사실만 보내고, PR #37에서 제거된 `ingredients`와 `steps` 실행 snapshot은
더 이상 포함하지 않는다. snapshot은 `recipeId`, `targetServings`,
`sourcePersonalVersionId`를 산출하는 데 계속 사용한다.

## 병합 선행 조건

이 PR은 backend #37의 새 엔드포인트가 배포되어야 동작한다. 또한 #37의 현재
리뷰에는 기존 개인 버전을 먼저 조회한 뒤 후기 소유권을 확인해 다른 사용자의
버전 정보를 노출할 수 있다는 P1 지적이 남아 있다. 프론트는 서버가 발급한 자기
후기 ID만 사용하지만 서버 신뢰 경계의 문제이므로, #37에서 사용자 범위 조회로
해결된 뒤 함께 병합해야 한다.

## HTTP 계약

```http
POST /api/v1/reviews/{reviewId}/personal-versions
X-CookPilot-User-Id: {betaUserId}
Content-Type: application/json
```

요청 예시:

```json
{
  "setup": {
    "ingredientAdjustments": [
      {
        "originalIngredientId": "11000000-0000-0000-0000-000000000001",
        "type": "MODIFY",
        "amount": 600,
        "sortOrder": 0
      },
      {
        "type": "ADD",
        "name": "치즈",
        "amount": 1,
        "unit": "장",
        "required": false,
        "sortOrder": 1
      }
    ],
    "stepAdjustments": []
  },
  "cooking": {
    "transcript": "물을 조금 더 넣었어요."
  }
}
```

- `201 Created`: 생성되었거나 같은 `reviewId` 재시도로 이미 존재하는 개인 버전
- `204 No Content`: 원본과 비교해 실제 변경 사항이 없어 버전을 만들지 않음
- 그 외 상태: 상태 코드를 보존한 `PersonalVersionApprovalApiException`

현재 백엔드 PR #37의 `201` body는 `createdAt`이 `null`일 수 있으며 호출 화면도 생성된
버전 상세를 즉시 사용하지 않는다. 따라서 어댑터는 성공 body를 파싱하지 않고 HTTP
status만 `PersonalVersionCreated` marker로 바꾼다. 빈 `201` body도 같은 성공이다.
상세 정보가 필요해지면 백엔드 응답 계약을 먼저 고친 뒤 별도 조회 API를 사용한다.

## snapshot 매핑

`CookingSetupSnapshot`은 조리를 시작할 때 확정된 실행 레시피다. 서버가 화면 상태를
다시 추론하지 않도록 다음 규칙으로 원본 기준 누적 diff를 만든다.

| snapshot 상태 | 요청 adjustment |
| --- | --- |
| `originalIngredientId == null` | `ADD` |
| 원본 재료이며 `omitted == true` | `REMOVE` |
| 원본 재료의 이름 또는 양 변경 | `MODIFY` |
| 이름과 양 모두 그대로 | 전송하지 않음 |
| 추가했다가 취소한 재료 | 전송하지 않음 |

개인 버전을 선택하면 서버의 합성 결과만 snapshot에 그대로 복사하지 않는다. 합성
결과의 `originalIngredientId`를 기본 레시피와 대조해 다음처럼 원본 기준을 복원한다.

- 기본 재료의 이름·양·단위·필수 여부를 `originalName`, `baselineAmount`,
  `baselineUnit`, `baselineIsRequired`로 보존
- 합성 결과에서 빠진 기본 재료를 `omitted: true`로 추가해 누적 `REMOVE` 보존
- 원본 ID가 없는 합성 재료는 누적 `ADD`로 보존
- 개인 버전에서 이미 바뀐 이름·양·단위·필수 여부는 현재값으로 유지해 누적
  `MODIFY` 보존

이 복원이 없으면 개인 버전으로 다시 조리할 때 기존 변경이 baseline처럼 보이므로
요청이 `204`가 되거나 이번 조리에서 새로 바꾼 값만 전송된다.

`MODIFY`에는 실제로 달라진 `name`, `amount`, `unit`, `required`만 넣는다.
현재 CookSetup UI가 단위와 필수 여부를 직접 편집하지 않더라도, 선택한 기존 개인
버전에 이미 있던 변경은 다음 누적 버전에서 원본으로 되돌아가면 안 되므로 그대로
재전송한다. `ADD`는 새 재료를 복원할 수 있도록 네 값을 모두 보낸다.

양 비교에는 화면의 변경 요약과 같은 작은 부동소수점 오차 허용값을 사용한다.
snapshot의 양은 이미 조리 인분 기준이며, 백엔드는 저장된 후기의
`targetServings`로 1인분 기준 값을 계산한다.

개인 버전 합성 응답이 원본에 없는 ID를 참조하거나 같은 원본 ID를 두 번
포함하면 개인 버전을 적용하지 않는다. 이런 응답을 새 재료나 무변경으로
추측하면 누적 diff 일부가 조용히 사라질 수 있기 때문이다.

## 단계와 타이머

현재 조리 준비 화면은 setup 단계 편집을 지원하지 않으므로
`stepAdjustments`는 항상 빈 배열이다.

조리 중 타이머 연장은 실행 보조 상태이지 조리 전 레시피 편집이 아니다. 이 어댑터는
타이머 상태를 인자로 받지 않으므로 타이머 연장을 setup diff로 잘못 저장하지 않는다.

데모 범위에서는 기존 개인 버전에 이미 들어 있던 단계 instruction·timer·caution
변경도 다음 버전으로 승계하지 않는다. 백엔드 #37은 부모 diff를 자동 상속하지
않으므로 단계 개인화를 지원할 때는 원본 기준 누적 `stepAdjustments`를 snapshot에
함께 보존하는 후속 계약이 필요하다.

## 호출 경계

이 어댑터는 승인 여부를 판단하지 않는다.

1. 실행 diff 없이 후기를 먼저 저장하고 안정적인 `reviewId`를 받는다.
2. 사용자에게 개인 버전 적용 여부를 묻는다.
3. 승인했을 때만 `createFromApprovedReview`를 호출한다.
4. `201`이면 생성 완료로, `204`이면 변경 없음으로 종료한다.

같은 `reviewId` 재시도는 백엔드에서 멱등 처리된다. 프론트는 네트워크 응답 유실 뒤에도
동일한 `reviewId`로 안전하게 다시 호출할 수 있다.

## 이번 변경에 포함하지 않은 것

- 후기 초안 또는 조리 완료 로컬 저장
- 승인 UI 및 ReviewScreen wiring
- 자동 개인 버전 생성
- setup 단계 편집
- 조리 중 transcript 수집 정책

## 검증

```bash
flutter test test/features/review/data/personal_version_approval_api_test.dart
flutter analyze
```

focused 테스트는 다음을 확인한다.

- 베타 사용자 헤더, URL, JSON 계약
- `ADD` / `REMOVE` / `MODIFY` 매핑과 무변경 제외
- 개인 버전 합성 결과의 누적 `ADD` / `REMOVE` / `MODIFY` 보존
- 빈 `stepAdjustments`와 타이머 비포함
- `createdAt: null` 또는 빈 body인 `201` 생성 marker
- `204` 변경 없음
- HTTP 오류 및 timeout 변환
