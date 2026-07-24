import 'package:flutter/foundation.dart';

enum StepMediaType { image, none }

@immutable
final class CookingStep {
  const CookingStep({
    required this.id,
    required this.instruction,
    required this.completionCue,
    required this.timerDuration,
    required this.mediaType,
    required this.mediaAsset,
    required this.mediaLabel,
    required this.mediaCaption,
  });

  final String id;
  final String instruction;
  final String completionCue;
  final Duration timerDuration;
  final StepMediaType mediaType;
  final String? mediaAsset;
  final String mediaLabel;
  final String mediaCaption;
}

const ramenDemoSteps = <CookingStep>[
  CookingStep(
    id: 'ramen-water-boil',
    instruction: '물 500ml를 넣고 끓이세요.',
    completionCue: '기포가 올라오면 다음 단계로 넘어가세요.',
    timerDuration: Duration(minutes: 2, seconds: 14),
    mediaType: StepMediaType.image,
    mediaAsset: 'assets/recipes/ramen/steps/boiling-pot.jpg',
    mediaLabel: '가스레인지 위 냄비에서 물이 기포를 내며 끓고 있는 조리 예시',
    mediaCaption: '이 정도로 끓으면 준비됐어요',
  ),
  CookingStep(
    id: 'ramen-noodles',
    instruction: '면과 스프를 넣고 가볍게 풀어주세요.',
    completionCue: '면이 서로 붙지 않도록 한 번만 저어주세요.',
    timerDuration: Duration(minutes: 3),
    mediaType: StepMediaType.none,
    mediaAsset: null,
    mediaLabel: '이 단계에는 조리 예시 이미지가 없습니다',
    mediaCaption: '완료 기준을 확인해주세요',
  ),
  CookingStep(
    id: 'ramen-finish',
    instruction: '불을 끄고 그릇에 옮겨 담으세요.',
    completionCue: '뜨거운 김과 냄비 손잡이를 조심하세요.',
    timerDuration: Duration.zero,
    mediaType: StepMediaType.none,
    mediaAsset: null,
    mediaLabel: '이 단계에는 조리 예시 이미지가 없습니다',
    mediaCaption: '완료 기준을 확인해주세요',
  ),
];
