# Impeccable standalone input provenance

## Purpose

Generate an independent CookPilot S-03 direction using the product-design tool path, so it can be compared fairly with the Shotgun path.

## Inputs used

- `C:\Users\sosoj\Desktop\SM\PRODUCT.md`
- `confirmed_mvp_2026-07-10/confirmed_mvp_2026-07-10/03_mvp_design.md`
- `confirmed_mvp_2026-07-10/confirmed_mvp_2026-07-10/04_screen_structure.md`
- Impeccable product-register rules
- Impeccable palette seed `seed-118`: `oklch(0.750 0.090 110.0)`

## Inputs deliberately excluded

- Shotgun variants A, B, C, and D
- Shotgun screenshots and comparison boards
- Shotgun ratings, comments, and remix feedback

## Fixed comparison conditions

- Surface: S-03 active cooking screen
- Viewport: 390×844
- Recipe: 라면
- Step: 1 / 3
- Current action: 물 500ml를 넣고 끓이세요.
- Completion cue: 기포가 올라오면 다음 단계로 넘어가세요.
- Timer: 02:14
- Voice state: 듣는 중
- Voice helper: “다음”, “다시 말해줘”, “1분 더”라고 말해보세요.
- Fallbacks: 이전, 다시 듣기, 1분 추가, 다음
- Session actions: 조리 중단, 조리 완료

## Design decision

Physical scene: a calm instrument panel read from one step away in a brightly lit kitchen while the user's hands are wet or occupied.

Color strategy: restrained. Pure white architecture, a near-black timing surface for distance legibility, an olive brand primary derived from the generated seed, and a coral semantic accent used only for live/error attention.
