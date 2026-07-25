# #7 레시피 목록·상세 API 연동

## 목적

화면에 하드코딩된 레시피 목데이터를 제거하고 PostgreSQL에 저장된
레시피 목록과 상세를 백엔드 API로 조회한다.

## API

| Method | URL | 역할 |
| --- | --- | --- |
| `GET` | `/api/v1/recipes` | 레시피 요약 목록 |
| `GET` | `/api/v1/recipes/{recipeId}` | 재료와 조리 단계를 포함한 상세 |

모든 요청은 익명 베타 사용자 세션이 준비된 경우
`X-CookPilot-User-Id` 헤더를 함께 전송한다.

## 모델 분리

- `RecipeSummary`
  - 목록에 필요한 ID, 제목, 설명, 이미지, 개인 버전·즐겨찾기 상태만 보관한다.
- `Recipe`
  - 상세 재료, 조리 단계, 기준 인분과 타이머 정보를 보관한다.
- API JSON 파싱은 `RecipeRepository`에서 처리하고 화면은 도메인 모델만 사용한다.

목록에서 레시피를 선택하면 요약의 ID로 상세 API를 다시 호출한다.
상세의 `recipeId`가 요청 ID와 다르거나 필수 JSON 형식이 잘못되면 오류로 처리한다.

## 화면 동작

- 홈과 검색 화면에서 서버 레시피 목록 표시
- 목록 선택 시 해당 ID의 상세 화면 이동
- 실제 재료와 조리 단계 표시
- 개인 레시피가 있으면 개인 버전 상태 표시
- 개인 버전이 없으면 기본 레시피로 조리 진행
- 이미지 URL이 없거나 로딩에 실패하면 앱 기본 음식 표시 사용

## 상태 처리

- 로딩 중: 진행 표시
- 빈 목록: 등록된 레시피가 없다는 안내
- 통신·파싱 실패: 서버 연결 안내와 다시 시도 버튼
- 상세 데이터 없음: 상세 화면 안에서 안전한 빈 상태 표시

## 조리 세션 복원과의 연결

진행 중 조리 세션은 로컬에 레시피 제목과 단계·타이머 상태를 저장한다.
앱 재시작 후 홈에서는 서버 레시피 목록에서 같은 제목을 찾고 상세 API를 호출해
실제 재료와 조리 단계를 복원한 뒤 `이어서 요리하기`를 표시한다.

서버에 더 이상 같은 레시피가 없으면 복원할 수 없는 저장본을 정리한다.
네트워크 오류일 때는 일시적인 장애일 수 있으므로 로컬 저장본을 삭제하지 않는다.
목데이터를 삭제한 뒤에도 조리 세션 테스트는 독립적인 테스트 레시피 fixture를 사용해
저장·단계 이동·타이머 복원·완료 후 삭제 동작을 계속 검증한다.

## 주요 변경 파일

- `lib/features/recipe/data/recipe_api.dart`
- `lib/features/recipe/domain/recipe.dart`
- `lib/features/mvp/main_shell.dart`
- `lib/features/mvp/cook_flow_screens.dart`
- `lib/features/mvp/mock_data.dart` 삭제
- `test/features/cooking/application/cooking_session_restore_test.dart`
  - API 전환 후에도 독립 fixture로 로컬 조리 세션 회귀 테스트 유지

## 검증

- 목록 응답과 개인 버전 필드 파싱
- 상세 재료·단계·기준 인분 파싱
- 사용자 식별 헤더 전달
- 잘못된 상태 코드와 JSON 응답 오류 처리
- `flutter analyze`
- 전체 Flutter 테스트
- Android 에뮬레이터에서 DB 레시피 8개와 상세 화면 확인

## 제외

레시피 등록·수정, 추천 알고리즘, 냉장고 재료 기반 필터링은 이 이슈에 포함하지 않는다.
