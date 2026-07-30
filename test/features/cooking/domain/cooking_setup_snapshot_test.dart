import 'package:cookpilot/features/cooking/domain/cooking_setup_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('실행 스냅샷은 JSON 왕복 후에도 개인 버전과 재료 설정을 유지한다', () {
    final snapshot = CookingSetupSnapshot(
      recipeId: 'recipe-id',
      title: '계란볶음밥',
      description: '설명',
      imageUrl: 'https://example.test/image.png',
      baseServings: 1,
      targetServings: 2,
      source: CookingRecipeSource.personal,
      personalVersionId: 'personal-version-id',
      ingredients: const [
        CookingSetupIngredient(
          originalName: '대파',
          name: '쪽파',
          amount: 1,
          baselineUnit: '단',
          baselineIsRequired: false,
          unit: '대',
          isRequired: true,
        ),
        CookingSetupIngredient(
          originalName: '계란',
          name: '계란',
          amount: 4,
          unit: '개',
          isRequired: true,
          omitted: true,
        ),
      ],
      steps: const [
        CookingSetupStep(
          stepIndex: 0,
          instruction: '볶으세요.',
          timerSeconds: 60,
          cautionNote: null,
          imageUrl: '',
        ),
      ],
    );

    final restored = CookingSetupSnapshot.fromJson(snapshot.toJson());

    expect(
      snapshot.toJson()['schemaVersion'],
      CookingSetupSnapshot.currentSchemaVersion,
    );
    expect(restored, isNotNull);
    expect(restored!.source, CookingRecipeSource.personal);
    expect(restored.personalVersionId, 'personal-version-id');
    expect(restored.ingredients.first.isSubstituted, isTrue);
    expect(restored.ingredients.first.baselineUnit, '단');
    expect(restored.ingredients.first.baselineIsRequired, isFalse);
    expect(restored.ingredients.last.omitted, isTrue);
    expect(restored.steps.single.timerSeconds, 60);
  });

  test('조리 화면용 레시피에서는 생략 재료를 제외한다', () {
    final snapshot = CookingSetupSnapshot(
      recipeId: 'recipe-id',
      title: '계란볶음밥',
      description: '',
      imageUrl: '',
      baseServings: 1,
      targetServings: 2,
      source: CookingRecipeSource.base,
      personalVersionId: null,
      ingredients: const [
        CookingSetupIngredient(
          originalName: '밥',
          name: '밥',
          amount: 2,
          unit: '공기',
          isRequired: true,
        ),
        CookingSetupIngredient(
          originalName: '계란',
          name: '계란',
          amount: 4,
          unit: '개',
          isRequired: true,
          omitted: true,
        ),
      ],
      steps: const [
        CookingSetupStep(
          stepIndex: 0,
          instruction: '볶으세요.',
          timerSeconds: 60,
          cautionNote: null,
          imageUrl: '',
        ),
      ],
    );

    final recipe = snapshot.toExecutionRecipe();

    expect(recipe.baseServings, 2);
    expect(recipe.hasPersonalVersion, isFalse);
    expect(recipe.latestPersonalVersionId, isNull);
    expect(recipe.ingredients, hasLength(1));
    expect(recipe.ingredients.single.name, '밥');
    expect(recipe.ingredients.single.amount, 2);
  });

  test('잘못된 인분이나 조리 단계가 없는 저장값은 복원하지 않는다', () {
    final json = <String, Object?>{
      'recipeId': 'recipe-id',
      'title': '계란볶음밥',
      'description': '',
      'imageUrl': '',
      'baseServings': 1,
      'targetServings': 0,
      'source': CookingRecipeSource.base.name,
      'personalVersionId': null,
      'ingredients': <Object?>[],
      'steps': <Object?>[],
    };

    expect(CookingSetupSnapshot.fromJson(json), isNull);

    json['targetServings'] = 1;
    expect(CookingSetupSnapshot.fromJson(json), isNull);
  });

  test('기존 스냅샷은 버전과 omitted 필드가 없어도 복원한다', () {
    final json = <String, Object?>{
      'recipeId': 'recipe-id',
      'title': '계란볶음밥',
      'description': '',
      'imageUrl': '',
      'baseServings': 1,
      'targetServings': 1,
      'source': CookingRecipeSource.base.name,
      'personalVersionId': null,
      'ingredients': <Object?>[
        <String, Object?>{
          'originalName': '밥',
          'name': '밥',
          'amount': 1,
          'unit': '공기',
          'isRequired': true,
        },
      ],
      'steps': <Object?>[
        <String, Object?>{
          'stepIndex': 0,
          'instruction': '볶으세요.',
          'timerSeconds': 60,
          'cautionNote': null,
          'imageUrl': '',
        },
      ],
    };

    final restored = CookingSetupSnapshot.fromJson(json);

    expect(restored, isNotNull);
    expect(restored!.ingredients.single.omitted, isFalse);
    expect(restored.ingredients.single.baselineAmount, 1);
  });

  test('지원하지 않는 미래 스냅샷 버전은 복원하지 않는다', () {
    final snapshot = CookingSetupSnapshot(
      recipeId: 'recipe-id',
      title: '계란볶음밥',
      description: '',
      imageUrl: '',
      baseServings: 1,
      targetServings: 1,
      source: CookingRecipeSource.base,
      personalVersionId: null,
      ingredients: const [],
      steps: const [
        CookingSetupStep(
          stepIndex: 0,
          instruction: '볶으세요.',
          timerSeconds: 60,
          cautionNote: null,
          imageUrl: '',
        ),
      ],
    );
    final json = snapshot.toJson()
      ..['schemaVersion'] = CookingSetupSnapshot.currentSchemaVersion + 1;

    expect(CookingSetupSnapshot.fromJson(json), isNull);
  });
}
