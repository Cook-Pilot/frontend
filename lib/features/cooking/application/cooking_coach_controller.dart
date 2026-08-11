enum CookingCoachPhase { idle, connecting, live, stopping }

typedef CookingCoachStateHandler =
    void Function(CookingCoachPhase phase, String? message);

/// 조리 화면이 코치 구현을 갈아 끼우는 경계. 현재 구현은 ElevenLabs 하나다
/// (Gemini 직결 경로는 only-api 브랜치에 보존).
abstract interface class CookingCoachEngine {
  CookingCoachPhase get phase;
  bool get isActive;
  Future<void> start(String recipeId);

  /// 탭 가로채기. 음성 barge-in이 내장된 엔진에서는 no-op일 수 있다.
  void interrupt();

  /// 진행 상황 변화(단계 이동 등)를 대화 중인 코치에게 알린다.
  /// 세션이 없으면 무시된다.
  void updateContext(String text);
  Future<void> stop();
  void dispose();
}
