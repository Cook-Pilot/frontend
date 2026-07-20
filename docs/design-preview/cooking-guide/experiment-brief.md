# CookPilot S-03 design experiment

## Fixed scope

- Target: Flutter mobile app cooking screen
- Comparison viewport: 390 x 844 px
- User: cooking beginner in a noisy kitchen with wet or occupied hands
- Job: understand the current action and remaining time, control the recipe by voice or buttons, and recover when voice fails
- Artifact: one standalone HTML file, no external assets, no network dependencies
- The phone canvas must fit in one viewport without scrolling

## Identical content in every variant

- Recipe: 라면
- Progress: 1 / 3
- Current instruction: 물 500ml를 넣고 끓이세요.
- Completion cue: 기포가 올라오면 다음 단계로 넘어가세요.
- Timer: 02:14
- Voice state: 듣는 중
- Voice helper: “다음”, “다시 말해줘”, “1분 더”라고 말해보세요.
- Fallback controls: 이전, 다시 듣기, 1분 추가, 다음
- Session controls: 조리 중단, 조리 완료

## Product rules

1. Visual priority: current action, timer, voice state, fallback controls, secondary guidance.
2. Voice and button actions must communicate the same capability.
3. Listening state must be visible without relying on color alone.
4. Minimum touch target is 44 px.
5. Avoid search, recommendations, social features, statistics, photos, gradients used as decoration, glassmorphism, nested cards, and tiny helper text.
6. Use semantic HTML and visible focus states.
7. Treat this as a product UI, not a landing page.

## Comparison criteria

- Current action is understood within three seconds.
- Timer is legible from arm's length.
- Listening state is unmistakable.
- Primary and fallback actions have clear hierarchy.
- The layout can support listening, processing, speaking, retry, and voice-off states.
- The screen has a distinct CookPilot character without decoration overpowering cooking.
