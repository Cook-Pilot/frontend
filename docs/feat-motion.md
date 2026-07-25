# 모션 정리 명세서 (feat/motion)

## 1. 문서 목적

이 문서는 `feat/motion` 브랜치에서 진행한 애니메이션 정리 작업의 배경, 검토한 대안, 최종 결정과 구현 내용을 정의한다.

## 2. 문제 상황

PR #6(디자인·모션 고도화)에서 도입한 장식용 애니메이션이 실기기(Galaxy A52s)에서 씹히고 겹쳐 보이는 문제가 있었다. 원인은 세 가지 구조적 중첩이었다.

1. **캐러셀 스크롤 재애니메이션** — 홈 캐러셀의 `ListView` itemBuilder 안에 `FadeSlideIn`이 있어, 카드가 뷰포트를 벗어났다 돌아올 때마다 매번 다시 페이드·슬라이드됐다.
2. **3중 전환 중첩** — 화면 push 시 커스텀 페이지 전환(페이드+슬라이드), Hero 이미지 비행, 콘텐츠별 `FadeSlideIn` 스태거가 동시에 재생됐다.
3. **이중 슬라이드** — 조리 단계·인분 수의 `AnimatedSwitcher`가 나가는 위젯과 들어오는 위젯을 동시에 슬라이드시켜, 빠르게 조작하면 두 콘텐츠가 겹쳐 보였다.

## 3. 검토한 대안

| 안 | 내용 | 결과 |
| --- | --- | --- |
| 충돌 완화 | 원인 3곳만 정밀 수정 (스태거 제거·라우트 전환 후 1회 재생, 캐러셀 통째 진입, 페이지 전환 페이드만, 나가는 위젯 페이드만) | 구현 후 실기기 확인 결과 여전히 만족스럽지 않아 폐기 (`3662927`) |
| **전면 제거 (채택)** | 장식용 모션 전부 삭제, 선택·터치 피드백만 유지 | 실기기 확인 후 확정 (`ac1908a`) |

## 4. 최종 결정: 장식용 모션 제거, 피드백 모션 유지

### 4.1 제거한 것

| 항목 | 위치 | 처리 |
| --- | --- | --- |
| `FadeSlideIn` 진입 페이드·슬라이드 | `lib/features/mvp/mvp_widgets.dart` | 클래스 자체 삭제, 호출부 전부 언랩 |
| 페이지 전환 애니메이션 | `lib/app/app_theme.dart` | `buildTransitions`가 `child`를 그대로 반환 (즉시 전환) |
| Hero 이미지 비행 | `mvp_widgets.dart`, `cook_flow_screens.dart`, `main_shell.dart` | `Hero` 래핑과 `heroTag` 파라미터 제거 |
| 조리 단계 전환 `AnimatedSwitcher` | `cook_flow_screens.dart` | 일반 `Column`으로 교체 |
| 인분 수 전환 `AnimatedSwitcher` | `cook_flow_screens.dart` | 일반 `Text`로 교체 |
| 진행바 `TweenAnimationBuilder` | `cook_flow_screens.dart` | 정적 `LinearProgressIndicator`로 교체 |

### 4.2 유지한 것 (선택·터치 피드백)

| 항목 | 이유 |
| --- | --- |
| `PressableScale` 누름 스케일 | 터치 반응 피드백. 단일 위젯 스코프라 겹침과 무관 |
| 선택 상태 `AnimatedContainer` (취향 옵션, 저장 방식 카드 등) | 선택했다는 피드백의 핵심 |
| 별점 탭 `ScaleTransition`, 저장 방식 체크 전환 | 선택 피드백 |
| 타이머 시계 `AnimatedBuilder` | 애니메이션이 아니라 매초 상태 갱신 (기능) |

`AppMotion` 토큰(`app_theme.dart`)은 유지 중인 피드백 모션이 계속 사용하므로 남겨둔다.

## 5. 검증

- `flutter analyze` 0건, 테스트 93개 전부 통과.
- Galaxy A52s(SM A528N) 실기기에서 홈 진입, 스크롤 복귀, 화면 전환을 확인. 씹힘·겹침 없음.

## 6. 이후 모션을 다시 넣을 때 지킬 것

- 스크롤 가능한 리스트의 itemBuilder 안에 진입 애니메이션을 넣지 않는다 (뷰포트 복귀 시 재생된다).
- 페이지 전환·Hero·콘텐츠 진입 중 동시에 재생되는 레이어는 1개로 제한한다.
- `AnimatedSwitcher`에서 나가는 위젯과 들어오는 위젯을 같은 축으로 동시에 움직이지 않는다.
