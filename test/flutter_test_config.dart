import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// 테스트 전역 설정.
///
/// 모션을 끈 상태로 돌린다. 헤더 로고의 김은 끝없이 반복하는 애니메이션이라,
/// 켜 두면 `pumpAndSettle` 이 영원히 끝나지 않는다.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestWidgetsFlutterBinding
      .instance
      .platformDispatcher
      .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
    disableAnimations: true,
  );
  await testMain();
}
