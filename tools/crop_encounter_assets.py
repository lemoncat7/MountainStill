#!/usr/bin/env python3
"""Rebuild the six active encounter sprites from retained source art and metadata.

Requires Pillow. Uses the recorded alpha bounds, scale and shared ground anchor.
The source images were generated for this project; this script only crops,
resamples and positions them, without drawing or editing their content.
"""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/cultivation/encounters"
metadata = json.loads((OUT / "metadata.json").read_text())
for name, item in metadata["sprites"].items():
    source = Image.open(OUT / "sources" / f"{name}_source.png").convert("RGBA")
    crop = source.crop(item["source_alpha_bbox"])
    scale = item["source_to_sprite_scale"]
    resized = crop.resize((round(crop.width * scale), round(crop.height * scale)), Image.Resampling.LANCZOS)
    anchor_x, anchor_y = item["ground_anchor"]
    canvas = Image.new("RGBA", tuple(metadata["canvas_size"]), (0, 0, 0, 0))
    canvas.alpha_composite(resized, (round(anchor_x - resized.width / 2), anchor_y - resized.height))
    canvas.save(OUT / f"{name}.png")
print("Rebuilt six encounter sprites with their shared ground anchor.")
