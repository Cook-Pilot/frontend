# S004 · Signal Rail / 시그널 레일 — Emil v3

## Design bible

- Platform: cross-platform premium neutral; raw 390×844-like portrait screens with safe areas and no device frame.
- Palette: matte graphite `#101412`, lifted graphite `#171C19`, soft warm-white `#F2F0E8`, secondary gray `#A6ACA7`, and one acid mint/lime accent around `#B7F34A`. Natural food colors are confined to photography.
- Typography: compact high-legibility Korean sans with controlled weight hierarchy. Mono/tabular numerals are reserved for time.
- Geometry: crisp hairlines, 8–12px radii, 10px fixed photo frames, almost no shadow, flat matte surfaces.
- Components: tactile rectangular pressables, consistent outline/filled icon weight, 48dp secondary and 56dp primary hit zones.
- Photography: realistic Korean home-cooking editorial crops, dark tabletop or pan context, natural side light, controlled warmth, no garnish fantasy or text overlays.
- Signature: a persistent 1px horizontal Signal Rail with a short acid-mint active segment and quiet endpoints. It repeats across Home section headers, hero CTA, active tab, Cooking step progress, action boundary, timer, voice state, and control grouping.
- Motion logic: origin-aware and interruptible. Active segments retarget through transform/clip-path; pressables imply `scale(0.97)` feedback; voice changes remain clipped inside a compact surface. The static frames stay quiet.

## Reference roles

- `S003-home.png`: Home information architecture only—brand/menu, search, Today’s Menu hero, recent pair, favorites shelf, bottom navigation.
- `S003-cooking.png`: Cooking information architecture only—top progress, current action, food image, timer/status, compact voice state, utility controls, stop/complete actions.
- `L002-home.png`: food-image confidence only; poster composition, neon treatment, and oversized typography were excluded.
- `L002-cooking.png`: active-simmer food intensity only; giant voice orb, waveform spectacle, sci-fi panels, and glow were excluded.
- `index-shift-home-v2.png`: matte graphite, warm-white legibility, crisp separators, and rectangular tactility only; its recipe-index composition was excluded.
- The generated Signal Rail Home v3 became the primary style reference for Cooking. Palette, type, radii, icon weight, buttons, rail, and image framing were explicitly locked from it.

## Final assets

- `home.png`
- `cooking.png`
- Both were generated with built-in `image_gen`, inspected at original resolution, and accepted without a regeneration pass.

## Exact final prompts

### Home

```text
Use case: ui-mockup
Asset type: one fresh standalone production-quality mobile app Home screen for CookPilot

Reference roles:
- Image 1 (S003 Home): STRUCTURE reference only. Preserve its believable CookPilot menu skeleton and reading order: top brand/menu, search, large Today’s Menu hero, recent cooking pair, favorites horizontal shelf, bottom navigation.
- Image 2 (L002 Home): FOOD-IMAGE PRESENCE reference only. Learn that food should feel appetizing and important, but do not copy its poster composition, oversized display headline, waveform decoration, clipped CTA shape, or neon styling.
- Image 3 (previous Emil Home): MATERIAL reference only. Carry forward matte graphite, warm-white legibility, crisp separators, and tactile rectangular controls, but do not copy its recipe-index composition, giant headline, large empty void, or expanded row.
Generate an entirely fresh Home screen. Do not crop, inset, collage, or reproduce any reference image.

Primary request:
Create the Home screen for an original CookPilot design system named “Signal Rail / 시그널 레일.” This is a premium cross-platform neutral cooking app. It must look like a real browse/menu Home—not a poster, landing page, active cooking screen, or dashboard. Preserve the specified menu skeleton exactly while introducing a thin persistent signal rail: a quiet 1px horizontal line with one short acid-mint active segment and tiny square endpoints. Repeat this signature subtly in section headers, the hero action boundary, favorite shelf, and active bottom tab so the future Cooking screen can share the same language.

Canvas:
- One raw portrait mobile UI, approximately 390×844 aspect ratio.
- Full-bleed app screen only; no external phone/device frame, no hands, no perspective mockup, no collage, no comparison board.
- Respect top and bottom safe areas.

Locked design bible:
- Matte graphite nearly-black canvas (#101412) and slightly lifted graphite surfaces (#171C19).
- Soft warm-white primary type (#F2F0E8), restrained gray secondary type (#A6ACA7).
- One and only UI accent: acid mint/lime (#B7F34A or a nearby single hue). Natural food colors may exist inside photos, but no other bright UI color.
- No beige canvas, no coral/red/orange/blue/purple UI accents, no gradients, no glow.
- Compact, high-legibility Korean-capable sans; strong but controlled hierarchy. Use mono/tabular numerals only for time metadata, never for titles.
- Hairline rails and crisp separators, 8–12px radii, almost no shadow, flat matte surfaces.
- Tactile rectangular pressables, 52–56dp minimum. Icons are restrained custom-feeling outline/filled hybrids with consistent weight.
- Food photography treatment: realistic Korean home-cooking editorial photography, close overhead or 35-degree crop, low-gloss natural side light, controlled warm color, consistent dark tabletop, no restaurant garnish, no text inside photos.
- Static screen remains quiet. Spatial structure may imply origin-aware, interruptible transitions, but never show motion diagrams.

Required Home structure and exact visible copy:
1) Top app bar:
   - brand “CookPilot” aligned left
   - a compact menu icon/action aligned right
   - no large marketing headline
2) Search:
   - one full-width rectangular search field directly below
   - placeholder exactly “레시피 이름·재료 검색”
   - simple search glyph; no filter chips
3) Today’s Menu hero:
   - section label exactly “오늘의 메뉴” with the thin Signal Rail extending horizontally from the label
   - one large landscape photo of appetizing Korean “두부조림”
   - below the photo, title exactly “두부조림”
   - metadata exactly “20분 · 쉬움 · 2인분”
   - one full-width tactile rectangular acid-mint CTA exactly “조리 시작”
   - integrate one thin mint signal segment into the CTA boundary, not a glow or progress bar
4) Recent cooking:
   - section label exactly “최근 조리” with the same hairline signal treatment
   - exactly two equal compact photo-led choices side by side:
     “제육볶음” with “25분 · 보통 · 2인분”
     “된장찌개” with “20분 · 쉬움 · 2인분”
   - keep titles readable; no floating card stack
5) Favorites:
   - section label exactly “즐겨찾기” with the signal rail
   - a single horizontal shelf with three compact photo tiles visible and a fourth edge subtly peeking to imply scroll
   - visible recipe names: “감자 그라탱”, “오일 파스타”, “가지볶음”
   - no oversized cards, no badges
6) Bottom navigation:
   - fixed dark bottom bar with exactly three destinations: “홈”, “검색”, “메모리”
   - “홈” is active using the single acid-mint accent plus a short horizontal signal segment; other tabs are warm-white/gray
   - no extra tab

Layout discipline:
- Fit all required regions believably within one screen without tiny text or cramped controls.
- Hero is the largest module but not a full-screen poster. Search, recent pair, favorites shelf, and bottom navigation must all remain clearly visible.
- Use direct grouping and hairlines rather than nesting every area inside a rounded card.
- Photos use a consistent 10px frame radius; controls 8–10px; section surfaces remain mostly flat.
- The Home should feel calm, expensive, and functional at first glance.

Motion implication:
- Menu would open from the top-right trigger origin; do not show the sheet.
- Search focus and CTA feedback feel immediate.
- Horizontal favorites shelf suggests a restrained interruptible glide.
- Signal rail active segments can retarget between sections/tabs with transform/clip-path, but appear as static thin lines here.
- Pressables visually support subtle scale(0.97), never bouncy.

Hard avoid:
active cook status, countdown timer, cooking step count, voice/mic state, coach, safety warning, resume card, dashboard widgets, charts, giant poster typography, giant voice orb, waveform spectacle, neon glow, glassmorphism, beige canvas, multiple bright accents, excessive pills, excessive rounded cards, chef hats, bot avatars, sparkles, generic AI UI, tiny text, fake Korean, duplicated labels, external device mockup, watermark.
```

### Cooking

```text
Use case: ui-mockup
Asset type: one fresh standalone production-quality active Cooking mobile screen for CookPilot

Reference roles:
- Image 1 (Signal Rail Home v3): PRIMARY STYLE REFERENCE. Carry over its exact product identity: matte graphite canvas and surfaces, soft warm-white type, single acid-mint/lime accent, type character and weight rhythm, 8–12px radius logic, hairline separators, custom-feeling icon weight, rectangular tactile buttons, realistic dark-table Korean food photography, and thin persistent Signal Rail signature.
- Image 2 (S003 Cooking): INFORMATION-ARCHITECTURE reference only. Preserve its believable one-column order: top bar/progress, current step/action, large food image, timer/status, compact voice state, four utility controls, stop/complete actions.
- Image 3 (L002 Cooking): FOOD INTENSITY reference only. Use an appetizing active simmer scene and clear action confidence, but explicitly do not copy its poster typography, LIVE marker, green waveform field, giant microphone orb, neon glow, sci-fi paneling, clipped polygons, or theatrical dashboard.
Generate a fresh Cooking screen rather than cropping, embedding, or repainting any reference.

Primary request:
Create the matching Cooking screen for “Signal Rail / 시그널 레일.” It must be unmistakably the same app as Image 1 even if every text label were hidden. The Home selection of tofu braise has led into an active cooking session. Keep the screen calm, compact, legible, and physically actionable. The signature thin horizontal Signal Rail/progress line should recur at the top step progress, current-stage boundary, timer/status, compact voice state, and button grouping.

Canvas:
- One raw portrait mobile UI, approximately 390×844 aspect ratio.
- Full-bleed app screen only; no external phone/device frame, no hands, no perspective mockup, no collage, no comparison board.
- Cross-platform premium neutral, respecting top and bottom safe areas.

Locked visual system from Home:
- Matte graphite nearly-black canvas (#101412), slightly lifted graphite surfaces (#171C19).
- Soft warm-white primary type (#F2F0E8), restrained gray secondary type (#A6ACA7).
- Exactly one bright UI accent: the same acid mint/lime used in Home (#B7F34A or matched precisely from Image 1).
- No other bright UI color. “조리 중단” uses warm-white/gray outline and text, not red.
- Compact high-legibility Korean-capable sans. Only the timer uses mono/tabular numerals.
- Hairline rails and crisp separators; 8–12px radii; nearly flat, almost no shadow.
- Tactile rectangular controls with consistent icon system and at least 48dp; primary action at least 56dp.
- Same realistic Korean home-cooking photo treatment as Home: dark tabletop/pan context, natural side light, controlled warm food color, crisp tofu texture, 10px frame radius, no text inside the photo.
- No gradient, no glow, no glass.

Required content, order, and exact visible copy:
1) Top app bar:
   - back arrow at left
   - centered title exactly “두부 조림 · 20분”
   - right progress exactly “3 / 4 단계”
   - directly below, a full-width thin Signal Rail with three quarters acid-mint and the final quarter gray; this is step position, not a decorative waveform
2) Current action block:
   - small label exactly “현재 단계”
   - dominant action exactly “중불로 줄이기”
   - explanation exactly “양념이 자작해질 때까지 졸여주세요.”
   - integrate one short mint segment into a hairline boundary; no oversized poster headline
3) Large food image:
   - a wide landscape close 35-degree photograph of tofu braise actively simmering in a dark pan, visually consistent with the Home hero but a fresh cooking-in-progress crop
   - this is the largest visual module, with stable 10px radius and no overlay text
4) Timer/status row:
   - large tabular timer exactly “01:27”
   - status exactly “진행 중”
   - align both on one calm row, separated or connected by the thin Signal Rail
   - no progress ring, no giant metric card
5) Compact voice/coach state:
   - one low-height rectangular matte surface with a restrained microphone/listening glyph
   - main label exactly “듣는 중”
   - supporting line exactly “3단계로 이동했어요.”
   - a short thin mint signal segment with two or three tiny square ticks is allowed, but NO waveform spectacle and no voice orb
6) Utility control deck:
   - exactly four equal tactile rectangular controls in a 2×2 grid, clearly labeled:
     “이전”
     “다시 듣기”
     “1분 추가”
     “다음”
   - restrained icons of consistent stroke weight; no pills
7) Final actions:
   - exactly two side-by-side rectangular actions:
     secondary outlined “조리 중단”
     primary acid-mint filled “조리 완료”
   - maintain safe separation and bottom safe area
   - do not imply automatic completion from the timer

Hierarchy and consistency gates:
- Current physical action first, then image, timer decision/status, voice state, navigation controls.
- The food image is large but must leave every required control readable in one screen.
- Mirror Home’s gutter, typography mood, radius, matte photo framing, separator weight, mint action fill, and icon weight exactly.
- The Signal Rail is quiet and persistent, never a loud visualization.
- Controls look immediately pressable with implied scale(0.97) response and could retarget via interruptible transitions.
- A menu/home CTA and a cooking CTA must clearly belong to one component family.

Motion implication:
- Step content enters from the exact progress-segment origin with a 180–220ms ease-out; static render shows only the spatial relationship.
- Voice state changes crossfade/clip within its compact surface and never grow into an orb.
- Button states morph in place; no jumping controls.
- No decorative motion labels or diagrams.

Hard avoid:
home search, recipe shelves, bottom navigation on Cooking, safety auto-completion, timer-as-done implication, giant voice orb, circular microphone centerpiece, waveform spectacle, neon glow, multiple bright colors, red destructive accent, poster homepage language, huge action typography, dashboard widgets, charts, sci-fi HUD, polygonal controls, gradient, glassmorphism, beige canvas, excess cards/pills, chef hats, bot avatars, sparkles, tiny text, fake Korean, duplicate buttons, external device frame, watermark.
```
