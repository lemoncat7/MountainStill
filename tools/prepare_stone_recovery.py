#!/usr/bin/env python3
"""Reproduce the reviewed boss recovery import; never repaint existing artwork.

Only rectangular crop, uniform LANCZOS resample and transparent-canvas placement.
Generated alpha is retained within the rectangular crop. No alpha threshold,
background removal, body warping, tinting or old sprite replacement.
"""
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/cultivation/beasts'
SOURCE = ASSETS / 'sources/creek-bridge-boss-settle-original.png'
DESTINATION = ASSETS / 'creek_bridge_boss_settle.png'
def main():
    original = Image.open(SOURCE).convert('RGBA')
    crop = original.crop((208, 308, 1144, 1152))
    scale = 171.0 / crop.height
    size = (round(crop.width * scale), round(crop.height * scale))
    small = crop.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (256, 256))
    canvas.alpha_composite(small, (round(128-small.width/2), 232-small.height))
    canvas.save(DESTINATION)
    print(DESTINATION)
if __name__ == '__main__':
    main()
