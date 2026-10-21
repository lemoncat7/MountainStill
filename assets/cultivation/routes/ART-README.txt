MOUNTAINSTILL ORIGINAL ROUTE ART

Created with OpenAI's built-in image_gen on 2026-10-19. No downloaded or third-party illustration assets. Existing project sanctuary and encounter art supplied only to match the art direction. Full original images and prompts retained in routes/sources/ and beasts/sources/.

Base scenes: bamboo_pass.png, creek_bridge.png, cloud_slope.png
Logical canvas: 1040 x 280. Shared gameplay foot baseline: y246.

Scrolling: {stage}_scroll.png is a 2080 x 280 pair of the original and its horizontal reflection. Repeat modulo 2080. Both boundary column pairs are bit-identical RGBA, with an opaque full-width foot row. Alternatively alternate {stage}.png and {stage}_mirror.png at 1040 pixel intervals. Render the route artwork behind actors and combat sprites. The symmetry at a mirrored join is intentional; no unverified AI-generated seamless edge is assumed.

Enemy assets are in ../beasts/: {stage}_{idle,attack}.png.
Bamboo boss: bamboo_pass_boss_{idle,windup,attack}.png. Its branching stone antlers and jade core distinguish it from normal creatures. The windup crouches low; the strike is a full-body horizontal pounce.
All sprites use a 256 x 256 transparent canvas and fixed ground anchor (128,232). Frame pairs/triples share scale. Suggested normal render size 112 x 112; boss 174 x 174. Apply a small vertical jump offset for airborne attack motion if desired.

Rebuild from project root, with Pillow installed:
python tools/route_prepare_assets.py
python tools/route_prepare_scroll_boss.py

The pipeline only crops, resamples, positions and mirrors generated art. It performs no background removal, alpha painting, masking, recoloring, or scenery fabrication.

Review:
route-bestiary-preview.png: all three environments and regular enemies
scroll-seam-preview.png: exact internal and wrap boundaries
../beasts/bamboo-boss-preview.png: three boss poses
art-qa.json, metadata.json, scroll-metadata.json, provenance.json: measurements and sources

2026-10-19 COMPLETE ROUTE BOSS EXTENSION

Remaining bosses now have three separate poses each:
../beasts/creek_bridge_boss_{idle,windup,attack}.png
../beasts/cloud_slope_boss_{idle,windup,attack}.png
Normal bamboo now includes bamboo_pass_windup.png and a new fully extended bamboo_pass_attack.png. First bamboo boss files are unchanged.

Wayside opportunity shrine: ../beasts/opportunity_cairn.png
Canvas 128 x 128; anchor (64,116). Original generated hand-drawn stone arch shrine with a warm recess, moss and herbs.

Optional finite bamboo travel panorama: bamboo_pass_panorama.png
Canvas 2080 x 280; baseline y246. Authored varied bamboo clumps, no duplicated reflection. For a 1040px viewport, use offset 0..940 for the current run and clamp to 1040 maximum. This is a finite original panorama, not a claim of an infinitely seamless loop. Existing mirrored loop strips remain as fallback.

Full rebuild order now:
python tools/route_prepare_assets.py
python tools/route_prepare_scroll_boss.py
python tools/route_prepare_additional_art.py
python tools/route_prepare_cloud_panorama.py

Additional previews:
../beasts/additional-route-art-preview.png
../beasts/remaining-bosses-preview.png
bamboo-panorama-preview.png
