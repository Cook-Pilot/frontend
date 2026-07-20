# Recipe preview image provenance

## Tool and model

- Generation tool: Codex built-in `image_gen.imagegen`
- Codex skill: `imagegen`
- Tool-result metadata identifier: `gpt-imagegen` v2.0
- Public API model name: not exposed by the built-in runtime
- Calls: one independent generation per asset, 11 calls total
- CLI/API fallback and API key: not used
- Post-processing: generated 1254×1254 PNG files were resized to optimized 640×640 PNG assets for the app

These are temporary MVP exploration assets. They contain no intentional text, logo, watermark, packaging, person, or hand.

## Shared prompt

```text
Use case: photorealistic-natural
Asset type: square recipe preview image for a polished mobile cooking app
Scene/backdrop: restrained warm neutral restaurant tabletop with minimal off-white ceramic tableware, uncluttered and premium
Style/medium: photorealistic editorial food photography, realistic ingredients and cooking texture, appetizing but not over-styled
Composition/framing: square crop, consistent overhead-to-three-quarter close shot, centered dish filling most of the frame with clean breathing room
Lighting/mood: warm natural restaurant window light, soft directional highlights, controlled gentle shadows, inviting and calm
Constraints: one coherent dish; no people, no hands, no faces, no packaging, no logos, no text, no watermark
Avoid: illustration, CGI look, excessive garnish, messy table, dramatic black background, neon saturation, duplicated ingredients, warped tableware
```

## Per-asset subject prompts

| App recipe | File | Primary request |
| --- | --- | --- |
| 두부 조림 | `tofu-braised.png` | Korean dubu jorim: braised tofu slices in soy-chili sauce with sesame and scallions |
| 김치볶음밥 | `kimchi-fried-rice.png` | Kimchi fried rice in a ceramic bowl with a fried egg and restrained scallion garnish |
| 된장찌개 | `soybean-paste-stew.png` | Korean doenjang jjigae bubbling in an earthenware pot with tofu, zucchini, mushrooms, and scallions |
| 오일 파스타 | `oil-pasta.png` | Aglio e olio spaghetti with thin golden garlic slices, parsley, and small red chili flakes |
| 닭갈비 | `dakgalbi.png` | Korean dakgalbi with tender chicken, cabbage, sweet potato, and scallions in gochujang sauce |
| 크림 파스타 | `cream-pasta.png` | Creamy mushroom fettuccine with browned mushrooms, parmesan, and parsley |
| 매콤 제육 | `spicy-pork.png` | Korean spicy pork jeyuk-bokkeum with onions and scallions in a glossy red sauce |
| 치킨 샐러드 | `chicken-salad.png` | Grilled chicken breast over mixed greens with tomato, cucumber, and light vinaigrette |
| 마파두부 | `mapo-tofu.png` | Mapo tofu with clean tofu cubes and minced pork in a glossy deep red chili-bean sauce |
| 두부 덮밥 | `tofu-rice-bowl.png` | Korean-style glazed tofu cubes over short-grain rice with scallions and sesame |
| 두부 된장국 | `tofu-soybean-soup.png` | Mild Korean tofu soybean-paste soup with tofu, zucchini, and mushrooms in a ceramic bowl |
