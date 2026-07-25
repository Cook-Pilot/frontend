import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/mvp/mock_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/cooking_fakes.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpSession(
    WidgetTester tester, {
    required ExceptionAdvicePort advicePort,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CookSessionScreen(
          recipe: recipes.first,
          servings: 2,
          alarm: const SilentTimerAlarm(),
          advicePort: advicePort,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('도움 버튼은 질문 시트를 열고 현재 단계 맥락으로 답변을 표시한다', (tester) async {
    final advice = FakeExceptionAdvicePort();
    await pumpSession(tester, advicePort: advice);

    await tester.scrollUntilVisible(find.byKey(const Key('help-request')), 200);
    await tester.tap(find.byKey(const Key('help-request')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('help-question-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('help-question-field')),
      '물이 안 끓어요',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('help-question-submit')));
    await tester.pumpAndSettle();

    final context = advice.requests.single;
    expect(context.utterance, '물이 안 끓어요');
    expect(context.stepIndex, 0);
    expect(context.instruction, recipes.first.steps.first.description);
    expect(find.textContaining('30초'), findsOneWidget);
  });

  testWidgets('답변 요청 실패 시 폴백 안내를 표시한다', (tester) async {
    final advice = FakeExceptionAdvicePort()..error = StateError('network');
    await pumpSession(tester, advicePort: advice);

    await tester.scrollUntilVisible(find.byKey(const Key('help-request')), 200);
    await tester.tap(find.byKey(const Key('help-request')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('help-question-field')),
      '물이 안 끓어요',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('help-question-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('답변을 불러오지 못했어요'), findsOneWidget);
  });
}
