# fix/cook-appbar-pause-button-#44 — 조리 중 화면 앱바의 동작 없는 일시정지 버튼 제거

## 문제 상황

조리 중 화면(`CookSessionScreen`) 앱바 우측에 일시정지 아이콘 버튼이 있었지만
`onPressed`가 빈 콜백이라 눌러도 아무 일도 일어나지 않았다.

```dart
actions: [
  IconButton(
    onPressed: _completionLocked ? null : () {},
    icon: const Icon(Icons.pause_rounded),
  ),
],
```

동작하는 부분은 `_completionLocked`(완료 저장 중)일 때 비활성화되는 것뿐이었다.
UI 목업 단계에서 자리만 잡아둔 placeholder가 그대로 남은 것으로,
F-09 작업(`e7ec50f`)에서 잠금 조건만 덧붙었을 뿐 기능은 채워진 적이 없다.

사용자에게는 정지 버튼처럼 보여서 "조리를 멈추는 버튼"으로 오해를 준다.

## 검토한 대안

| 대안 | 판단 |
| --- | --- |
| 버튼 제거 | **채택.** 아래 참고 |
| 타이머 일시정지에 연결 | 본문 타이머 버튼(`_toggleTimer`)과 기능이 완전히 중복된다 |
| 세션 일시정지 기능 신규 구현 | `docs/`에 해당 기능 명세가 없다. 명세 없는 기능을 임의로 만들지 않는다 |

앱바가 담당해야 할 동작은 이미 다른 곳에 있다.

- **타이머 일시정지/재개** → 본문 타이머 카드 버튼(`_toggleTimer`). 상태에 따라
  `타이머 시작` / `일시정지` / `계속` 라벨로 바뀐다.
- **조리 세션 중단** → 앱바 좌측 나가기(`Icons.close_rounded`, `_closeCookingSession`).

즉 앱바 우측 버튼이 맡을 고유한 역할이 없으므로 제거가 가장 작은 변경이다.

## 최종 결정

`CookSessionScreen`의 `AppBar.actions`를 통째로 삭제했다. 앱바에는 나가기 버튼과
제목(레시피명 · 인분)만 남는다. `_completionLocked`는 다른 곳에서 계속 쓰이므로 그대로 둔다.

## 검증

- `test/features/mvp/cook_session_app_bar_test.dart` 추가 — 앱바에 나가기 버튼이 있고
  일시정지 아이콘은 없음을 확인한다. 수정 전 코드에서는 실패하는 것을 확인했다.
- `dart format .`, `flutter analyze`, `flutter test` 통과.

## 이후 작업에서 지킬 것

- 앱바에 동작 없는 placeholder 버튼을 다시 두지 않는다. 위 테스트가 회귀를 막는다.
- 세션 일시정지가 실제로 필요해지면 먼저 `docs/`에 명세를 남기고,
  타이머 일시정지와 역할이 어떻게 다른지 정한 뒤 구현한다.
