# F-12 개인 재료 탭·홈 소진 임박 추천 연동

## 목표

하단 네비게이션에 '개인 재료' 탭을 신설해 이모티콘으로 냉장고 재료를
가볍게 담고, 홈 화면에서 그 재료를 실제로 쓰는 레시피를 소진 임박 순으로
추천받는다. 추천은 백엔드 규칙 엔진 결과를 그대로 보여줄 뿐 레시피나
개인 버전을 프론트에서 직접 계산하거나 수정하지 않는다.

## 화면 흐름

1. 하단 탭 '개인 재료' 진입 시 이모티콘 카탈로그와 현재 담은 재료 목록을
   함께 불러온다.
2. 이모티콘을 탭하면 바로 담긴다(수량·소진일 직접 입력 없음). 이미 담은
   재료를 다시 탭하면 백엔드가 소진 예정일만 최신값으로 갱신한다.
3. 담은 재료는 소진 임박순으로 정렬되고, 남은 일수를 `D-N` 배지로
   보여준다. 각 재료를 삭제해 다 썼거나 버렸음을 표시할 수 있다.
4. 홈 화면은 재료 목록과 별도로 소진 임박 레시피 추천을 조회해 '이런
   재료가 있네요~ 이런 요리 어때요?' 섹션에 최대 3건까지 보여준다. 카드를
   누르면 레시피 상세로 이동한다.

## 실패 처리

- 카탈로그·보유 재료 조회 실패: 다시 시도 버튼을 보여준다.
- 담기/삭제 실패: 스낵바로만 안내하고 화면은 이전 상태를 유지한다.
- 홈 화면 추천 조회 실패: 추천 섹션만 숨기고 나머지 홈 화면은 그대로
  보여준다(다른 홈 섹션과 동일한 degrade 방식).

## API

- `GET /api/v1/pantry/ingredient-catalog`
- `GET /api/v1/pantry/items`
- `POST /api/v1/pantry/items`
- `DELETE /api/v1/pantry/items/{itemId}`
- `GET /api/v1/pantry/recipe-suggestions`

모든 요청은 현재 베타 사용자 헤더를 사용한다.

## 주요 변경 파일

- `lib/features/pantry/data/pantry_api.dart`
  - 카탈로그·보유 재료·추천 모델, 조회·담기·삭제 API
- `lib/features/pantry/presentation/pantry_screen.dart`
  - '개인 재료' 탭 화면(이모티콘 담기, 보유 재료 목록/삭제)
- `lib/features/mvp/main_shell.dart`
  - 하단 탭에 '개인 재료' 추가, 홈 화면에 소진 임박 추천 섹션 연동
- `test/features/pantry/data/pantry_api_test.dart`
  - 응답 파싱, 사용자 헤더, 담기/삭제 요청 검증
- `test/features/pantry/presentation/pantry_screen_test.dart`
  - 이모티콘 담기·삭제 상호작용 검증

## 검증

```bash
flutter analyze
flutter test
git diff --check
```

이 브랜치 작업 환경에는 Flutter SDK가 없어 위 명령을 직접 실행하지
못했다. 머지 전 로컬에서 한 번 확인이 필요하다.
