# Ink-paper UI materials

Original project assets generated with the built-in OpenAI image generation tool on 2026-10-19. Both PNGs preserve their genuine alpha channels and contain no baked-in interface text. The source files remain under the workspace's generated_images folder. Runtime source cropping is handled by `scripts/ink_paper.gd`; the PNGs themselves are unmodified.

- `rice-paper.png`: 1536 × 1024, generated source `exec-97e1f269-bd53-4e17-a80b-fac11f6082d9.png`.
- `soot-brush.png`: 2172 × 724, generated source `exec-50043f52-ae6b-40cf-b23b-2f9bf9f346bf.png`.

## Paper prompt

Use case: stylized-concept. Asset type: production game UI material texture, single paper sheet, no text. Create a beautiful restrained warm ivory Chinese rice paper sheet isolated on a genuinely transparent background. Landscape 3:2 aspect, entirely front-facing flat orthographic. Full sheet fills 96% of image, 2% transparent margin on all sides. Imperfect softly fibrous edges, pale cream rice fibers visible very subtly, almost clean ivory center 88% of area for dark readable typography. Extremely subtle diluted warm-grey ink bleed and light tea-colored aging confined to outer corners. Crisp elegant handmade paper, contemporary scholarly Chinese ink-wash aesthetic, not grunge parchment. No words, no characters, no calligraphy, no symbols, no stamps, no borders, no lines, no landscape, no objects, no frame, no curl, no fold, no perspective, no shadow, no rounded rectangle. Purpose is quiet reading surface for a cozy chibi cultivation game's journal. The underlying material must retain visual softness without dirt. Output one seamless-looking whole sheet, not an atlas.

## Brush prompt

Use case: stylized-concept. Asset type: production game UI brush material, single horizontal stroke, no text. Paint one restrained beautiful Chinese sumi ink brush swipe on a genuinely transparent background. Horizontal landscape 3:1 composition, ink swipe fills 94% width and 62% height centered. Single broad drybrush stroke, soot charcoal black #34332c, medium density center, very softly feathered watery edges with subtle irregular pigment pooling. Broad center must be continuous enough to hold ivory button lettering but organically nuanced. Ends softly tapered with visible fine bristles. Flat orthographic scanned artwork. Sophisticated ink-wash game UI material; not a grunge smear, not a cartoon swoosh. No words, no calligraphy, no characters, no symbols, no decorative objects, no border, no paper background, no white backdrop, no extra marks. Entire outside area transparent.

## Integration

`InkPaper.paint(canvas, rect, alpha, kind, reveal)` can be called before text in a parent's `_draw()`; `kind` is `book`, `scroll`, or `leaf`. Its node form exposes `kind` and `reveal`. It does not intercept pointer events.

`InkPaper.paper_style(margin_x=12, margin_y=8)` returns a painted `StyleBoxTexture` for native tooltips/dialog surfaces. `InkPaper.brush_style(alpha=0.92)` provides a stock dialog-button surface. Font colors remain the caller's responsibility.

`QuietButton` retains `selected`, `accent`, and `hint`. Setting `variant="ink_hit"` or metadata `ink_region=true` suppresses its custom text and all opaque fills while preserving `Button.text` for access and tests. Blank labels automatically use this hit-region mode. Host-drawn artwork should supply its own selected marker in that mode.
