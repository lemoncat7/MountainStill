#!/usr/bin/env python3
"""Reproduce the four active weapon/technique layers from their generated atlas.

Requires Pillow. Performs cropping, resizing and placement only. The old
whole-character outfit presets are intentionally not part of this pipeline.
"""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/cultivation/avatars"
props = Image.open(OUT / "sources/props-sheet.png").convert("RGBA")
SPECS = {
    "sword": ((245, 0, 535, 702), (220, 560), (330, 510)),
    "fan": ((640, 135, 1295, 710), (640, 560), (959, 505)),
    "mist_slash": ((5, 700, 670, 1215), (640, 512), None),
    "petal": ((765, 798, 1268, 1142), (512, 352), None),
}
metadata = {"assets": {}}
for name, (box, size, pivot) in SPECS.items():
    crop = props.crop(box)
    scale = min((size[0] - 8) / crop.width, (size[1] - 8) / crop.height)
    resized = crop.resize((round(crop.width * scale), round(crop.height * scale)), Image.Resampling.LANCZOS)
    xy = ((size[0] - resized.width) // 2, (size[1] - resized.height) // 2)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(resized, xy)
    canvas.save(OUT / f"{name}.png")
    metadata["assets"][name] = {"file": f"{name}.png", "canvas": size, "source_crop": box, "alpha_bounds": canvas.getbbox()}
    if pivot:
        metadata["assets"][name]["grip_anchor"] = [round(xy[0] + (pivot[0] - box[0]) * scale), round(xy[1] + (pivot[1] - box[1]) * scale)]
(OUT / "props-anchors.json").write_text(json.dumps(metadata, indent=2) + "\n")
print("Rebuilt sword, fan, mist slash and petal layers.")
