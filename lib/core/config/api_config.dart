import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// 백엔드 base URL.
///
/// Flutter에는 application.yml 같은 런타임 설정이 없다. 컴파일 타임 상수를 주입한다:
///   flutter run --dart-define-from-file=config/dev.json
/// 값을 주지 않으면 플랫폼별 기본값을 쓴다 (안드로이드 에뮬레이터는 호스트를 10.0.2.2로 본다).
class ApiConfig {
  const ApiConfig._();

  static const _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }

  static const apiPrefix = '/api/v1';

  static String get apiBaseUrl => '$baseUrl$apiPrefix';

  static const connectTimeout = Duration(seconds: 5);
  static const receiveTimeout = Duration(seconds: 10);
}
