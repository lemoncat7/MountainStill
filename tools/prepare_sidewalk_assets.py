#!/usr/bin/env python3
"""Deterministic sprite-atlas extraction; no redrawing or costume substitution."""
from pathlib import Path
from PIL import Image
import json
ROOT=Path(__file__).resolve().parents[1]
DIR=ROOT/'assets/cultivation/sidewalk'
source=Image.open(DIR/'sources/base-cutout-atlas.png').convert('RGBA')
parts={'head':(119,29,697,679),'torso':(826,293,1060,679),'arm':(352,735,507,1131),'leg':(846,714,1056,1215)}
meta={'source':'sources/base-cutout-atlas.png','method':'Original built-in image generation; rectangular alpha-preserving sprite extraction only','parts':{}}
for name,rect in parts.items():
 part=source.crop(rect);part.save(DIR/(name+'.png'));meta['parts'][name]={'rect':rect,'size':part.size}
(DIR/'base-atlas.json').write_text(json.dumps(meta,indent=2)+'\n')
print(meta)
gear_path=DIR/'sources/equipment-side-atlas.png'
if gear_path.exists():
 gear=Image.open(gear_path).convert('RGBA')
 # Torso/head pieces remain independent cutouts; sleeves/legs/shoes are placed
 # on the matching limb canvas so the skeletal mesh shares exact joint UVs.
 specs={
 'head_pin':((112,76,514,272),None,None),
 'head_crown':((653,23,880,271),None,None),
 'chest_blue':((206,251,479,621),None,None),
 'chest_jade':((654,263,912,599),None,None),
 'sleeve_blue':((185,597,406,868),(155,396),(0,0,155,179)),
 'sleeve_jade':((656,602,897,869),(155,396),(0,0,155,179)),
 'legs_blue':((148,874,472,1283),(210,501),(0,0,208,355)),
 'legs_jade':((632,881,905,1276),(210,501),(0,0,208,355)),
 'feet_cloth':((180,1317,475,1503),(210,501),(12,407,210,501)),
 'feet_boots':((648,1285,923,1505),(210,501),(12,358,210,501)),
 }
 details={}
 for name,(crop,canvas,target) in specs.items():
  part=gear.crop(crop)
  if canvas:
   out=Image.new('RGBA',canvas)
   x,y,w,h=target
   part=part.resize((w-x,h-y),Image.Resampling.LANCZOS)
   out.alpha_composite(part,(x,y))
  else:out=part
  out.save(DIR/(name+'.png'))
  details[name]={'source_rect':crop,'canvas':out.size,'target_rect':target}
 (DIR/'equipment-atlas.json').write_text(json.dumps({'source':'sources/equipment-side-atlas.png','parts':details},indent=2)+'\n')
 print('Equipment:',list(details))
