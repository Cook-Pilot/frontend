# L007 · Folded Menu / 접힌 메뉴 — Taste v4

Taste-driven exploratory concept for CookPilot Home and active Cooking. The pair keeps the agreed product functions and priority while deliberately moving away from the Emil Signal Rail visual system.

## Final assets

- Home: home.png
- Cooking: cooking.png
- Canvas: 853 × 1844 PNG for both screens
- Generation: built-in image generation, one successful call per asset; no regeneration

## Design bible

### Concept

“Folded Menu / 접힌 메뉴” treats each screen like a contemporary menu folio assembled from broad folded color fields and overlapping plates. The hierarchy is editorial and asymmetric, but controls remain direct and app-native.

### Color

- Pure white: #FFFFFF
- Ultramarine / cobalt: #3139C9
- Coral: #F45F55
- Apricot: #FFC3A1
- Deep oxblood: #4A1426
- Carbon: #17151A
- Explicit exclusions: beige, cream, lime, dark graphite, gradients, glass

### Type

- Expressive high-contrast Korean serif: dish headlines, active-step headline, timer
- Crisp Korean sans: brand, search, metadata, descriptions, section labels, navigation, status, and every control
- Serif is never used for control labels.

### Shape and image language

- Broad cobalt/apricot color planes, folded-corner notches, circles, semicircles, and arches
- Bright recipe-accurate food photography in circular, overlapping plate, or arch crops
- One coral capsule/tab for the primary action
- Simple medium-stroke icons
- Open spacing instead of repeated cards, nested containers, or dashboards

### Screen relationship

Home establishes the visual grammar. Cooking carries forward the same cobalt/apricot planes, expressive-serif and functional-sans pairing, curved food crop, coral primary action, and solid cobalt dock. Cooking is a workflow-specific composition, not a rearranged Home skeleton.

## Reference roles

- Emil Signal Rail Home and Cooking v3 were inspected only as negative references. They were never supplied to image generation.
- Home was generated without an image reference and became the style authority.
- Cooking was generated as a fresh screen with the final Home PNG as its sole image reference.
- The anti-reference goal was explicit: avoid Signal Rail’s near-black graphite field, acid-lime accent, hairline signal rails, compact all-sans treatment, and rectangular cinematic/card skeleton.

## Functional coverage

### Home

- Search: “레시피 이름·재료 검색”
- Today’s menu: “두부조림”, “20분 · 쉬움 · 2인분”, “조리 시작”
- Recent cooking: equal entries for “제육볶음” and “된장찌개”
- Favorites: overlapping food plates for “토마토 파스타”, “김치볶음밥”, “계란말이”
- Bottom navigation: “홈”, “검색”, “메모리”
- Omitted required functions: none

### Cooking

- Recipe and progress: “두부 조림 · 20분”, “3 / 4 단계”
- Current instruction: “현재 단계”, “중불로 줄이기”, “양념이 스며들 때까지 졸여요.”
- Process image: tofu visibly simmering in sauce
- Timer and state: “01:27”, “진행 중”
- Listening state: “듣는 중”, “3단계로 이동했어요.”
- Four utilities: “이전”, “다시 듣기”, “1분 추가”, “다음”
- Session actions: “조리 중단”, “조리 완료”
- Omitted required functions: none

## Visual differentiation from Emil Signal Rail

| Dimension | Folded Menu v4 | Emil Signal Rail v3 |
| --- | --- | --- |
| Tonality | High-key white, cobalt, apricot, coral | Near-black graphite with acid lime |
| Structure | Broad folded planes and curved overlaps | Thin horizontal signal rails and rectangular modules |
| Typography | Expressive serif for culinary focus plus sans controls | Compact sans throughout |
| Food imagery | Circular, plate-shaped, and arch crops | Rectangular cinematic crops |
| Navigation/actions | Solid cobalt dock and coral capsule | Dark technical control/navigation treatment |
| Overall character | Editorial, tactile menu folio | Technical, instrument-like signal system |

## Exact final Home prompt

~~~text
Use case: ui-mockup
Asset type: one fresh standalone high-fidelity mobile app HOME screen
Primary request: Create CookPilot Home in a completely new visual worldview named “Folded Menu / 접힌 메뉴.” Preserve only the required information presence and priority; invent a fresh visual layout. It must be a believable, shippable mobile product UI, not a poster or dashboard.
Platform: cross-platform premium neutral.
Scene/backdrop: the entire image is the RAW app viewport, approximately 390×844 portrait proportions. No phone hardware, no device frame, no outside canvas, no hand, no desk mockup, no collage.
Physical scene: a beginner cook browses at a sunlit white kitchen counter in midday light; the high-key palette remains clear and appetizing.
Design bible:
- Bright light mode only.
- Palette: pure white #FFFFFF, strong ultramarine/cobalt #3139C9, coral #F45F55, soft apricot #FFC3A1, deep oxblood #4A1426 for selected editorial text, and carbon #17151A for functional text. No beige or cream.
- Broad solid color planes fold across the screen like a contemporary menu folio: large asymmetrical split fields, offset semicircles, and one or two folded-corner notches. These are substantial color areas, never thin rails or hairline motifs.
- Typography pairing: an expressive high-contrast Korean serif only for dish names and food headlines; one crisp compact Korean sans for brand, search, metadata, sections, navigation, labels, and controls. Never use serif for controls.
- Food imagery: bright, recipe-accurate editorial photography inside circular, overlapping plate-shaped, semicircular, or tall arch crops. No standard rectangular hero photo.
- UI geometry: open white space, large circular/arch media, broad folded color blocks, and one primary capsule/tab CTA. Avoid repeated rounded cards.
- Iconography: simple confident filled/outline icons with a consistent medium stroke, clearly different from technical hairline icons.
- Shadows: none or one very short crisp separation shadow under the floating CTA only. No glass or gradients.
Required product priority, top to bottom:
1. A compact top brand row with exact “CookPilot” in sans and a simple menu icon.
2. A practical, clearly tappable search control with icon and exact placeholder “레시피 이름·재료 검색”.
3. “오늘의 메뉴” is the first and dominant content. Create a bold asymmetric split hero: ultramarine and apricot planes with one large circular or arch-cropped food photograph of glossy Korean tofu braise. Show exact dish headline “두부조림” in expressive serif, exact metadata “20분 · 쉬움 · 2인분” in sans, and one obvious coral capsule/tab CTA “조리 시작”. Keep text off the busy food crop.
4. “최근 조리” comes second. Do NOT use two rectangular cards. Create a compact numbered typographic list with two equal entries: large serif numbers “01” and “02”, small circular food images, sans dish names “제육볶음” and “된장찌개”, and short metadata. Use open rules or alignment, not card boxes.
5. “즐겨찾기” comes third. Create a playful overlapping plate carousel/mosaic with three partially overlapping circular food photos, clear readable labels “토마토 파스타”, “김치볶음밥”, “계란말이”, and a horizontal-scroll cue. It must not become an equal rectangular grid.
6. A solid ultramarine bottom dock fixed at the bottom with exactly “홈”, “검색”, “메모리”. Use white icons/text, with Home selected by a coral filled tab or small apricot shape. Respect the bottom safe area.
Text to render verbatim and clearly:
“CookPilot”
“레시피 이름·재료 검색”
“오늘의 메뉴”
“두부조림”
“20분 · 쉬움 · 2인분”
“조리 시작”
“최근 조리”
“01”
“제육볶음”
“02”
“된장찌개”
“즐겨찾기”
“토마토 파스타”
“김치볶음밥”
“계란말이”
“홈”
“검색”
“메모리”
Composition/framing: Make the layout asymmetrical yet unmistakably app-native. Search, hero, recent list, favorite mosaic, and bottom dock must all be visible in this one scroll-position. Today’s menu remains the largest surface; recent items are equal and smaller; favorite plates are smallest and overlapping. Ensure readable touch targets and protect all text with solid-color negative space.
Constraints: exact functional sections and priority; high contrast; readable Korean at normal phone size; clear search affordance; visible hero metadata and CTA; exactly two recent items; visible favorite carousel; three-item bottom dock; one raw screen only; no watermark; no extra marketing copy.
Strong anti-reference constraints: absolutely no dark mode, graphite, black canvas, acid lime, neon green, hairline rail, signal line, technical timeline, rectangular cinematic hero, same rectangular card/photo skeleton, compact all-sans-only typography, dashboard widgets, glass, gradients, nested cards, repeated panels, generic recipe grid, oversized poster headline, cream, beige, parchment, chef hat, bot avatar, sparkles, tiny text, phone/device frame, comparison collage, text gibberish.
~~~

## Exact final Cooking prompt

~~~text
Use case: ui-mockup
Asset type: one fresh standalone high-fidelity mobile app COOKING screen
Reference role: Image 1 is the sole visual style authority for palette, typography pairing, broad folded color planes, circular/arch food imagery, control geometry, icon weight, and finish. Do not edit or reproduce its Home layout. Create a new cooking workflow screen in the exact same “Folded Menu / 접힌 메뉴” design system.

Primary request: Create CookPilot’s active cooking screen for tofu braise. It must be a believable, shippable mobile product UI, not a poster or dashboard. Every required Korean string and every required control below must be visible, legible, and correctly spelled.

Platform: cross-platform premium neutral.
Scene/backdrop: the entire image is the RAW app viewport, approximately 390×844 portrait proportions. No phone hardware, no device frame, no outside canvas, no hand, no desk mockup, no collage.
Physical scene: a beginner cook follows the step beside a bright sunlit white kitchen counter; the food photograph is an appetizing close-up of tofu braising in red sauce in a pan, clearly a cooking-process image rather than a plated final dish.

Carry forward this exact design bible from Image 1:
- Bright light mode only.
- Palette: pure white #FFFFFF, strong ultramarine/cobalt #3139C9, coral #F45F55, soft apricot #FFC3A1, deep oxblood #4A1426, carbon #17151A. No beige or cream.
- Broad solid color planes fold across the screen: large asymmetrical split fields, offset circles/semicircles, and one or two folded-corner notches. Substantial color areas only, never thin rails or signal lines.
- Typography pairing: expressive high-contrast Korean serif only for the active step headline and the timer digits; crisp Korean sans for app chrome, metadata, descriptions, status, labels, and all controls.
- Food imagery: one bright recipe-accurate cooking-process photo inside a large tall arch or circular crop, never a standard rectangular hero.
- UI geometry: open white space, one broad folded image field, a compact listening tab, clearly tappable utility controls, and a solid-color bottom action dock. Avoid repeated rounded cards.
- Iconography: simple confident filled/outline icons with consistent medium stroke.
- Shadows: none or one very short crisp separation shadow under the primary action only. No glass or gradients.

Required hierarchy and composition, top to bottom:
1. Compact white app bar with a back arrow, exact title “두부 조림 · 20분” in sans, and exact progress “3 / 4 단계” aligned on the right.
2. Main current-step editorial block over open white and ultramarine/apricot folded planes. Show small sans label “현재 단계”, then large expressive Korean serif headline exactly “중불로 줄이기”, then sans instruction exactly “양념이 스며들 때까지 졸여요.” Protect every character on a calm solid-color area.
3. One large arch or circular food-process photograph of tofu actively simmering in glossy red sauce in a pan. Do not use a rectangular photo. It can overlap an apricot semicircle and ultramarine folded field.
4. A prominent timer area using large expressive serif numerals exactly “01:27” and nearby sans status exactly “진행 중”. Do not use a horizontal progress rail.
5. A broad apricot or white listening tab integrated into the folded composition. Include a simple medium-stroke listening/wave icon, exact sans status “듣는 중”, and exact confirmation “3단계로 이동했어요.”
6. Four distinct, clearly tappable utility controls, all visible at once, using open circular/semicircular or compact tab geometry rather than nested cards. They must read exactly: “이전”, “다시 듣기”, “1분 추가”, “다음”. Give each a simple relevant icon. Keep all four visually secondary; “다음” must not look like a second primary CTA.
7. A solid ultramarine bottom action dock fixed to the bottom, respecting the safe area. It contains both actions: secondary “조리 중단” in white text with a clear outline/low-emphasis treatment, and the only primary filled coral capsule “조리 완료”. Both actions must be fully visible and clearly tappable.

Text to render verbatim and clearly:
“두부 조림 · 20분”
“3 / 4 단계”
“현재 단계”
“중불로 줄이기”
“양념이 스며들 때까지 졸여요.”
“01:27”
“진행 중”
“듣는 중”
“3단계로 이동했어요.”
“이전”
“다시 듣기”
“1분 추가”
“다음”
“조리 중단”
“조리 완료”

Composition/framing: Fit all required content in a single viewport without scrolling. The active step headline and food-process image dominate; timer is the second-largest typographic moment; listening confirmation and four utility controls remain readable; the bottom dock is always visible. Use asymmetric folds and circular/arch forms, not rectangular stacks. Maintain functional touch targets and clear hierarchy.

Constraints: exact strings; exact 4 utility controls; exact 2 bottom actions; one raw screen only; high contrast; readable Korean at normal phone size; no watermark; no extra marketing copy; no missing or clipped content.

Strong anti-reference constraints: absolutely no dark mode, graphite, black canvas, acid lime, neon green, hairline rail, signal line, technical timeline, rectangular cinematic hero, same rectangular card/photo skeleton, compact all-sans-only typography, dashboard widgets, glass, gradients, nested cards, repeated panels, generic recipe grid, oversized poster treatment, cream, beige, parchment, chef hat, bot avatar, sparkles, tiny text, phone/device frame, comparison collage, text gibberish.
~~~
