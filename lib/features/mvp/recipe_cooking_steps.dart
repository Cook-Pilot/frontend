import '../cooking/domain/cooking_step.dart';
import 'mock_data.dart';

/// mock [Recipe]의 단계를 조리 세션 엔진이 쓰는 [CookingStep]으로 변환한다.
/// mock에는 완료 기준·미디어가 없어 단계 제목 기반 기본값을 채운다.
List<CookingStep> cookingStepsFromRecipe(Recipe recipe) {
  return List<CookingStep>.unmodifiable(<CookingStep>[
    for (final (index, step) in recipe.steps.indexed)
      CookingStep(
        id: '${recipe.title}-step-${index + 1}',
        instruction: step.description,
        completionCue: '${step.title}이 끝나면 다음 단계로 넘어가세요.',
        timerDuration: Duration(minutes: step.minutes),
        mediaType: StepMediaType.none,
        mediaAsset: null,
        mediaLabel: '이 단계에는 조리 예시 이미지가 없습니다',
        mediaCaption: '완료 기준을 확인해주세요',
      ),
  ]);
}
