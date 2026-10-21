MountainStill campaign route art
================================

Five new original finite panoramas join the existing Bamboo Pass:
  creek_bridge_panorama.png  — jade water, willow banks and a flat stone bridge
  cloud_slope_panorama.png   — windswept pines and ivory cloud mountains
  ember_ruins_panorama.png   — ruined warm clay kiln, cedar and old pottery
  moon_marsh_panorama.png    — moonlit silver-blue reeds, lake and causeway
  summit_gate_panorama.png   — white mountain shrine gate and ancient pine

Each runtime panorama is RGBA 2080 x 280 with ground baseline y246. Use one
continuous finite landscape and clamp a 1040px camera to offsets 0..1040. These
are not infinite seamless tiles. No copied, mirrored or repeated clumps were
used. Existing historical *_scroll.png and *_mirror.png strips are not the new
campaign assets. Existing Bamboo Pass files were not changed.

All five were generated with the built-in OpenAI image_gen tool after visually
inspecting the existing bamboo panorama. Original generated RGBA sources and
prompts are retained under sources/. Creek Bridge had a targeted image_gen edit
to flatten its bridge; its initial source is retained for provenance.

The preparation script tools/prepare_campaign_routes.py performs only a
rectangular crop and LANCZOS resize. It does not paint, remove backgrounds,
change colors, invent alpha or reflect artwork. Ember Ruins and Moon Marsh
crop a little excess lower foreground to align their walking lanes. All sky
transparency is genuine generated alpha, retained through resampling.

campaign-panorama-metadata.json records source crops, hashes and runtime
integration bounds. campaign-provenance.json records the generation pipeline.
campaign-art-qa.json records alpha, baseline and anti-mirroring checks.
campaign-route-preview.png presents all six routes on a light review background
to show their silhouettes and transparency. That page is not runtime art.

Compatibility assets for Ember Ruins, Moon Marsh and Summit Gate:
  <id>.png         exact first 1040 x 280 viewport crop of <id>_panorama.png
  <id>_scroll.png  byte-identical copy of <id>_panorama.png
The campaign host should continue preferring the panorama filenames. The new
scroll aliases are finite, not wraparound strips. Existing Creek Bridge and
Cloud Slope static and scroll assets remain unchanged.
