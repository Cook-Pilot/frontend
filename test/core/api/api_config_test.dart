import 'package:cookpilot/core/api/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android 에뮬레이터는 호스트 별칭을 기본 주소로 사용한다', () {
    expect(
      defaultApiBaseUrlFor(isWeb: false, platform: TargetPlatform.android),
      'http://10.0.2.2:8080',
    );
  });

  test('iOS 시뮬레이터와 데스크톱은 localhost를 사용한다', () {
    expect(
      defaultApiBaseUrlFor(isWeb: false, platform: TargetPlatform.iOS),
      'http://localhost:8080',
    );
    expect(
      defaultApiBaseUrlFor(isWeb: false, platform: TargetPlatform.macOS),
      'http://localhost:8080',
    );
  });

  test('웹은 실행 플랫폼과 무관하게 localhost를 사용한다', () {
    expect(
      defaultApiBaseUrlFor(isWeb: true, platform: TargetPlatform.android),
      'http://localhost:8080',
    );
  });
}
