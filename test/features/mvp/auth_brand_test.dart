import 'package:cookpilot/app/cooklog_mark.dart';
import 'package:cookpilot/features/mvp/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('로그인 화면에 심볼과 워드마크가 뜬다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pump();

    expect(find.byType(CookLogMark), findsOneWidget);

    final wordmark = tester.widget<Image>(find.byType(Image));
    expect(
      (wordmark.image as AssetImage).assetName,
      'assets/logo/cooklog-wordmark.png',
    );
  });
}
