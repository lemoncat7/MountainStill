#!/usr/bin/env python3
"""Prepare isolated cloud boss poses and the original non-mirrored bamboo panorama.
Only rectangular cropping, resampling, and transparent-canvas placement.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json,hashlib
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'assets/cultivation/beasts'; ROUTES=ROOT/'assets/cultivation/routes'
meta=json.loads((OUT/'metadata.json').read_text())
# Approximate reference-sheet identity scale, with the full extended beak-fan contained.
poses=[('idle',(60,43,1249,1254),180),('windup',(59,174,1244,1138),196),('attack',(44,7,1737,868),236)]
for state,b,width in poses:
 path=OUT/'sources'/f'cloud_{state}-source.png';source=Image.open(path).convert('RGBA');crop=source.crop(b);scale=width/crop.width;small=crop.resize((width,round(crop.height*scale)),Image.Resampling.LANCZOS);canvas=Image.new('RGBA',(256,256));canvas.alpha_composite(small,(round(128-small.width/2),232-small.height));name=f'cloud_slope_boss_{state}';canvas.save(OUT/f'{name}.png')
 meta['sprites'][name]={'name':'Crowned Cloud Crane Sovereign','source':f'sources/cloud_{state}-source.png','design_source':'sources/cloud_slope-boss-source.png','source_size':list(source.size),'source_crop':list(b),'source_to_sprite_scale':scale,'ground_anchor':[128,232],'alpha_bbox':list(canvas.getchannel('A').getbbox()),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'notes':'Source pose cleanly isolated through built-in image_gen; no programmatic background removal. Relative pose scale matched to design sheet.'}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
path=ROUTES/'sources/bamboo_panorama-source.png';source=Image.open(path).convert('RGBA');panorama=source.resize((2080,280),Image.Resampling.LANCZOS);panorama.save(ROUTES/'bamboo_pass_panorama.png')
assert panorama.getchannel('A').crop((0,246,2080,247)).getextrema()[0]>240
pmeta={'source':'sources/bamboo_panorama-source.png','source_size':list(source.size),'runtime_size':[2080,280],'ground_baseline':246,'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'generation':'Original built-in image_gen panorama; no copied or mirrored clumps','postprocessing':'LANCZOS canvas resize only; source alpha retained','max_camera_offset_for_1040_viewport':1040,'recommended_run_offset':[0,940],'not_infinite_seamless_tile':True,'integration':'Use this as a single finite horizontal panorama; clamp scroll offset to [0,1040]. No wrap is needed for the current 940px run. Keep existing mirrored strips as fallback for unlimited loops.'}
(ROUTES/'bamboo-panorama-metadata.json').write_text(json.dumps(pmeta,ensure_ascii=False,indent=2)+'\n')
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',22);smallfont=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16)
page=Image.new('RGBA',(1240,970),(248,242,226,255));d=ImageDraw.Draw(page)
for row,(stage,title) in enumerate([('creek_bridge','Ancient Riverstone Guardian | Sweep windup and water strike'),('cloud_slope','Crowned Cloud Crane | Gathered-qi windup and beak-fan burst')]):
 y=15+row*365;d.text((24,y),title,font=font,fill='#5d4c37')
 for j,state in enumerate(['idle','windup','attack']):
  sprite=Image.open(OUT/f'{stage}_boss_{state}.png').resize((300,300),Image.Resampling.LANCZOS);page.alpha_composite(sprite,(40+j*405,y+30));d.text((165+j*405,y+330),state,font=smallfont,fill='#5d4c37')
d.text((24,756),'Original non-mirrored bamboo trail | Full 2080px travel panorama',font=font,fill='#5d4c37');page.alpha_composite(panorama.resize((1190,160),Image.Resampling.LANCZOS),(24,793))
page.convert('RGB').save(OUT/'remaining-bosses-preview.png')
# Actual-size 1040px route windows at the start and end of the specified run.
page=Image.new('RGBA',(1088,670),(248,242,226,255));d=ImageDraw.Draw(page)
for j,(x,label) in enumerate([(0,'Start of trail'),(940,'End of 940px journey')]):
 y=15+j*330;d.text((24,y),label,font=font,fill='#5d4c37');page.alpha_composite(panorama.crop((x,0,x+1040,280)),(24,y+36))
page.convert('RGB').save(ROUTES/'bamboo-panorama-preview.png')
print('Saved all 3 clean cloud boss poses and original finite 2080x280 bamboo panorama.')
