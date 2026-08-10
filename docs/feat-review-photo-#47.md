# feat/review-photo-#47 — 리뷰 제출 시 사진 촬영·첨부

이슈 #47. 후기 작성 화면에서 요리 사진을 카메라로 찍거나 갤러리에서 골라
첨부하고, 리뷰 제출 시 서버에 함께 저장한다.

## 문제 상황

- 후기에 사진을 넣을 수단이 없었다.
- backend PR #49(2026-08-10 머지)로 `POST /api/v1/reviews`가
  `photoUrls: List<String>`(최대 10장, 순서 보존, URL 형식 검증 없음)을
  받지만, **파일 업로드 API는 없다**. 서버는 URL 문자열만 저장한다.
- 서버 멱등 규칙: 같은 `clientSessionId` 재전송 시 body의 photoUrls는
  무시되고 기존 리뷰가 반환된다. 제출 후 사진 수정 API도 없다. 따라서
  **사진 업로드는 첫 리뷰 POST 전에 전부 완료**되어야 하며, 사진 없이
  저장된 후기에는 영구히 첨부할 수 없다.

## 검토한 대안

- **압축 base64 data URL을 photoUrls에 직접 저장** — 인프라 0으로 즉시
  동작하지만 리뷰 조회 응답이 장당 수백 KB로 비대해져 기각.
- **Firebase Storage 프론트 직접 업로드** — 프로젝트 생성·보안 규칙·익명
  접근 설계가 필요해 기각.
- **백엔드 경유 S3 (채택)** — 프론트가 백엔드에 멀티파트 업로드, 백엔드가
  S3 저장 후 URL 반환. 프론트는 스토리지의 존재를 모른다. S3가 준비되기
  전이므로 계약을 먼저 합의하고, 프론트는 포트로 추상화해 fake로 개발한다.

## 백엔드에 제안하는 업로드 계약

```
POST /api/v1/reviews/photos
헤더:  기존 베타 유저 헤더(X-CookPilot-User-Id)
바디:  multipart/form-data, 파트명 "file" 1개 (장당 1요청 — 실패한 장만 재시도)
제약:  jpeg/png/webp/heic, 최대 10MB
201:   {"url": "https://..."}  ← 이 문자열을 그대로 photoUrls에 사용
오류:  400/413(형식·용량), 401(유저 헤더), 500
비고:  리뷰 미연결 고아 객체(첨부 후 미제출·재업로드 잔여물) GC는 백엔드
       책임(예: 24h 후 미참조 삭제)
```

경로·파트명은 `review_photo_upload_api.dart`의 상수에 국소화했다 — 계약이
다르게 확정되면 이 파일만 수정한다.

## 최종 결정

| 영역 | 내용 |
|---|---|
| 의존성 | `image_picker`(촬영·선택), `path_provider`(문서 디렉토리). `permission_handler` 불필요 |
| 권한 | Android 매니페스트 무변경 — image_picker는 카메라 인텐트/Photo Picker라 런타임 권한 불요(CAMERA를 선언하면 오히려 런타임 승인 필수가 되므로 선언 금지). iOS는 `NSCameraUsageDescription`·`NSPhotoLibraryUsageDescription` 추가. 권한 거부는 `PlatformException(*_access_denied)` → 설정 안내 SnackBar |
| draft v3 | `PendingReviewDraft.photoPaths: List<String>` — 문서 디렉토리 기준 **상대경로**(iOS 컨테이너 UUID 변동 대비). v1·v2는 빈 목록으로 마이그레이션. 검증: 최대 10장, 빈 문자열·NUL·절대경로·`..` 거부 |
| 파일 보관 | `ReviewPhotoFileStore` — 픽커 결과는 OS가 지울 수 있는 캐시라 즉시 `review_photos/<clientSessionId>/<uuid>.jpg`로 복사. 복원 시 `pruneMissing`으로 유실 파일 제외 + 안내. 저장 성공 후 세션 디렉토리 정리 |
| 업로드 | `ReviewPhotoUploadPort` + `ReviewPhotoUploadApi`(멀티파트, 8s×2 timeout). **선업로드(eager)**: 첨부 즉시 백그라운드 업로드 시작(동시 3장 제한, 1600px·품질 80 압축), 장당 상태(업로드 중/실패 배지+재시도)를 화면 세션 인메모리로 관리. URL 캐시로 성공분 재업로드 회피 |
| 저장 흐름 | `_save()`는 진행 중 업로드를 기다리고 미업로드분만 올린 뒤, 한 장이라도 실패면 **리뷰 POST를 보내지 않고** 중단(재시도 유도). `acceptedReviewId`가 이미 있으면(서버가 photoUrls를 무시) 업로드 전체 스킵. 성공 시 `submit(photoUrls:)`에 draft 순서대로 전달 |
| UI | 후기 화면 '다음에는'과 개인 버전 스위치 사이에 사진 스트립(가로 썸네일 + 삭제 배지 + `n/10` 추가 타일, 10장 시 숨김) + 카메라/갤러리 바텀시트. 잠금 조건은 기존 후기 입력과 동일 |

사진 없는 후기는 파일 시스템을 아예 건드리지 않아 기존 플로우의 동작·실패
표면을 그대로 유지한다(기존 테스트 무수정 통과가 그 증거).

## 검증

`dart format` 0변경 / `flutter analyze` 0건 / `flutter test` **393개 전부
통과**(신규 15개: draft v3 마이그레이션·검증 3, 파일 보관소 3, 업로드
어댑터 2, submit body 2, 후기 화면 통합 6 — 선업로드 시작, 저장 시 대기,
실패 시 제출 중단·재시도, 멱등 재진입 업로드 0회, 10장 상한, 유실 prune).

`docs/openapi.json`을 backend main(PR #49 반영)으로 동기화했다.

수동 검증(백엔드 엔드포인트 대기): 에뮬레이터에서 조리 완료 → 사진 첨부 →
앱 강제 종료 → 재실행 시 draft·사진 복원 확인. 실서버 E2E는 백엔드 업로드
API 구현 후 `--dart-define=COOKPILOT_API_BASE_URL=...`로 진행한다.

## 이후 작업에서 지킬 것

- **사진이 붙는 저장은 "업로드 전부 성공 → 단 한 번의 리뷰 POST" 순서를
  깨지 않는다.** 서버 멱등이 재전송의 photoUrls를 버리기 때문이다.
- 픽커가 돌려주는 경로를 draft에 저장하지 않는다 — 캐시라 사라진다. 반드시
  문서 디렉토리로 복사한 상대경로만 저장한다.
- Android 매니페스트에 CAMERA 권한을 추가하지 않는다(플러그인 동작 조건).

## 남은 작업

- 백엔드 업로드 엔드포인트 구현(위 계약) + S3 연결, 고아 객체 GC.
- 조리 이력·리뷰 조회 화면에서 사진 표시(`GET /api/v1/cooking-history`에는
  사진 필드 자체가 없어 백엔드 추가 필요) — 별도 이슈.
- 업로드 진행률("n/10") 표시, "사진 빼고 저장" 우회 버튼 — UX 검토 후.
