# frontend
Cook-Pilot의 Frontend 레포입니다.

---

# CookPilot Flutter MVP

요리할수록 사용자의 입맛을 기억하는 실시간 AI 조리 코치의 Flutter 클라이언트입니다.

## 현재 구현 범위

- 로그인 / 게스트 진입
- 입맛 프로필 콜드스타트 화면
- 홈 / 검색 / 레시피 메모리 탭
- 레시피 상세 / 조리 전 설정
- 조리 중 단계 안내 / 타이머 / 음성 코치 자리 표시
- 조리 후 리뷰 / 저장 방식 선택

## 문서

- [프론트 기능 명세서](docs/frontend-feature-spec.md)

## 개발 환경

```bash
flutter --version
flutter pub get
flutter analyze
flutter run
```

Android Studio에서 열 때는 이 레포 루트를 엽니다.

```text
/Users/jeondonghun/Documents/Codex/2026-07-10/https-github-com-cook-pilot-https/frontend
```

이 작업에서 사용한 로컬 Flutter SDK 경로는 다음과 같습니다.

```text
/Users/jeondonghun/Documents/Codex/2026-07-10/https-github-com-cook-pilot-https/work/flutter_sdk
```

Apple Silicon Mac에서 `flutter test`가 `darwin-x64/impellerc` 아키텍처 오류로 실패하면 Rosetta 설치 후 다시 실행합니다.

```bash
sudo softwareupdate --install-rosetta --agree-to-license
flutter test
```

---

# Git Convention

## TAG

| 태그 | 설명 |
| --- | --- |
| `feat` | 새로운 기능 / 코드 추가 |
| `fix` | 버그 · 문제점 수정 |
| `refactor` | 동작 변화 없는 코드 리팩토링 |
| `comment` | 주석 추가 · 수정 (코드 변경 X), 오타 수정 |
| `docs` | README 등 문서 수정 |
| `rename` | 파일 · 폴더명 수정 또는 이동 |
| `chore` | 패키지 추가, 설정 변경 등 그 외 잡일 |

## Branch Name

```
(TAG)/(주요내용)
```
**예시**

```
feat/login-page
fix/token-expire-#99
chore/eslint-config
```
## Commit Message

```
(TAG)((ISSUE)) : 제목
```
- 이슈 번호는 있을 때만, 없으면 생략.

**예시**

```
feat(#123) : 로그인 API 연동을 구현하였다.
- auth.ts 추가
- 토큰 갱신 로직 처리
```

```
chore : eslint, prettier 패키지 추가
```

## Pull Request

- 제목: `(TAG) : 요약`
  - 예) `feat : 로그인 페이지 구현`
  - PR 번호는 GitHub이 자동으로 붙이므로 직접 적지 않습니다.
- `main`은 직접 push 금지. **PR로만 머지**합니다.
