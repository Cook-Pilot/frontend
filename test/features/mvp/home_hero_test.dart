import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/features/mvp/mvp_widgets.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe _recipe() => const Recipe(
  id: 'r1',
  title: '해산물 옥수수 오븐구이',
  description: '',
  baseServings: 1,
  imageUrl: '',
  hasPersonalVersion: false,
  ingredients: [],
  steps: [
    CookStep(
      stepIndex: 0,
      instruction: 'a',
      imageUrl: '',
      timerSeconds: 600,
      cautionNote: null,
    ),
    CookStep(
      stepIndex: 1,
      instruction: 'b',
      imageUrl: '',
      timerSeconds: 600,
      cautionNote: null,
    ),
  ],
);

void main() {
  testWidgets('히어로는 눈썹·제목·메타를 위에서 아래로 겹치지 않게 쌓는다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCookPilotTheme(),
        home: Scaffold(
          body: ListView(children: [RecipeHeroCard(recipe: _recipe())]),
        ),
      ),
    );

    // 테마가 버튼에 Size.fromHeight(56)(폭 무한)을 걸어 두어, 가로로 늘어놓으면
    // 레이아웃이 터지고 글자가 한자리에 겹쳐 그려진 적이 있다.
    expect(tester.takeException(), isNull);

    final eyebrow = tester.getRect(find.text('오늘의 추천'));
    final title = tester.getRect(find.text('해산물 옥수수 오븐구이'));
    final meta = tester.getRect(find.text('20분 · 2단계 · 1인분'));

    expect(eyebrow.bottom, lessThanOrEqualTo(title.top));
    expect(title.bottom, lessThanOrEqualTo(meta.top));

    // 히어로는 화면 폭을 가득 채운다 — 좌우 여백이 남으면 안 된다.
    final hero = tester.getRect(find.byType(RecipeHeroCard));
    expect(hero.left, 0);
    expect(
      hero.width,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );
  });

  testWidgets('히어로에 요리 시작과 저장 버튼이 있다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCookPilotTheme(),
        home: Scaffold(
          body: ListView(children: [RecipeHeroCard(recipe: _recipe())]),
        ),
      ),
    );

    expect(find.byKey(const Key('home-hero-start')), findsOneWidget);
    expect(find.byKey(const Key('home-hero-save')), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
  });
}
