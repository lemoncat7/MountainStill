#!/usr/bin/env python3
"""Refresh explicit runtime export entries from the authored adventure directories."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
scripts=['scripts/character_sidewalk.gd','scripts/duel_timeline.gd','scripts/character_projection.gd','scripts/portal_dissolve.gdshader']
assets=[]
for folder in ['sidewalk','routes','beasts']:
    for path in sorted((ROOT/'assets/cultivation'/folder).glob('*.png')):
        if 'preview' in path.name or 'sheet' in path.name: continue
        assets.append(path.relative_to(ROOT).as_posix())
additions=['res://'+x for x in scripts+assets]
p=ROOT/'export_presets.cfg';text=p.read_text()
def replace(match):
    current=re.findall(r'"([^"]+)"',match.group(1))
    for value in additions:
        if value not in current:current.append(value)
    return 'export_files=PackedStringArray('+', '.join('"'+x+'"' for x in current)+')'
text=re.sub(r'export_files=PackedStringArray\((.*?)\)',replace,text)
p.write_text(text)
print(f'Explicit runtime manifest includes {len(additions)} adventure scripts/assets; originals and proof sheets excluded.')
