# 환경 설정

Flutter에는 `application.yml` 같은 런타임 설정 파일이 없다. 공식 방식은 컴파일 타임
상수 주입(`--dart-define`)이며, 이 프로젝트는 파일로 관리하는 형태를 쓴다.

| 파일 | 용도 | API_BASE_URL |
|---|---|---|
| `dev.json` | 안드로이드 에뮬레이터 (호스트를 10.0.2.2로 봄) | `http://10.0.2.2:8080` |
| `local.json` | iOS 시뮬레이터 / 데스크톱 | `http://localhost:8080` |

```bash
flutter run --dart-define-from-file=config/dev.json
flutter run --dart-define-from-file=config/local.json
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8080  # 실기기
```

값을 주지 않으면 `lib/core/api/api_config.dart`의 플랫폼별 기본값이 쓰인다
(Android → `10.0.2.2:8080`, 그 외 → `localhost:8080`).

백엔드는 `cd ../backend && ./gradlew bootRun` 으로 8080에 뜬다.
운영 값(실제 서버 주소, 키)은 이 디렉터리에 커밋하지 말고 CI 시크릿으로 주입한다.
