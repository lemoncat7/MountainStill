#!/usr/bin/env python3
"""Deterministic art preparation: mirrored scroll strips and boss frame crops.

Uses only original image_gen art; does not paint, blend, clean alpha or invent
scenery. Mirroring creates exactly matching adjacent and wrap RGBA columns.
"""
from pathlib import Path
import json, hashlib
from PIL import Image, ImageDraw, ImageFont, ImageChops
ROOT=Path(__file__).resolve().parents[1]; ROUTES=ROOT/'assets/cultivation/routes'; BEASTS=ROOT/'assets/cultivation/beasts'
STAGES=['bamboo_pass','creek_bridge','cloud_slope']
scroll_meta={'method':'Forward tile + exact horizontal reflection; repeat full 2080px strip','tile_size':[1040,280],'strip_size':[2080,280],'ground_baseline':246,'renderer_note':'Draw strip at natural logical size 2080x280, offset -fmod(scroll_distance,2080), repeat next strip at +2080. Or alternate normal/mirror 1040px tiles. All scenery should render behind actor and enemies.','routes':{}}
for stage in STAGES:
 source=Image.open(ROUTES/f'{stage}.png').convert('RGBA'); mirrored=source.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
 mirrored.save(ROUTES/f'{stage}_mirror.png'); strip=Image.new('RGBA',(2080,280)); strip.paste(source,(0,0)); strip.paste(mirrored,(1040,0));strip.save(ROUTES/f'{stage}_scroll.png')
 join_a=strip.crop((1039,0,1040,280)); join_b=strip.crop((1040,0,1041,280)); first=strip.crop((0,0,1,280));last=strip.crop((2079,0,2080,280))
 assert ImageChops.difference(join_a,join_b).getbbox() is None
 assert ImageChops.difference(first,last).getbbox() is None
 assert strip.getchannel('A').crop((0,246,2080,247)).getextrema()[0]>240
 scroll_meta['routes'][stage]={'strip':f'{stage}_scroll.png','mirrored_tile':f'{stage}_mirror.png','interior_join_rgba_max_difference':0,'wrap_join_rgba_max_difference':0,'entire_foot_row_opaque':True}
(ROUTES/'scroll-metadata.json').write_text(json.dumps(scroll_meta,ensure_ascii=False,indent=2)+'\n')
source_path=BEASTS/'sources/bamboo-boss-source.png'; source=Image.open(source_path).convert('RGBA')
bounds=[(19,96,665,676),(711,260,1311,671),(1312,235,2160,653)]
scale=min(236/max(b[2]-b[0] for b in bounds),208/max(b[3]-b[1] for b in bounds));metadata=json.loads((BEASTS/'metadata.json').read_text())
for state,b in zip(('idle','windup','attack'),bounds):
 crop=source.crop(b); small=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS); canvas=Image.new('RGBA',(256,256));canvas.alpha_composite(small,(round(128-small.width/2),232-small.height)); name=f'bamboo_pass_boss_{state}';canvas.save(BEASTS/f'{name}.png')
 metadata['sprites'][name]={'species':'ancient_bamboo_guardian','name':'Ancient Bamboo Guardian','source':'sources/bamboo-boss-source.png','source_size':list(source.size),'source_crop':list(b),'source_to_sprite_scale':scale,'ground_anchor':[128,232],'alpha_bbox':list(canvas.getchannel('A').getbbox()),'suggested_render_size':[174,174],'source_sha256':hashlib.sha256(source_path.read_bytes()).hexdigest()}
metadata['boss_notes']='Distinct ancient guardian has branching stone antlers, massive boulder limbs and a jade shoulder core. Three poses share exact source scale: upright idle, deep crouching windup and fully stretched pouncing strike. Apply renderer jump offset during attack if airborne motion is desired.'
(BEASTS/'metadata.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',22); smallfont=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16)
page=Image.new('RGBA',(1240,430),(248,242,226,255));d=ImageDraw.Draw(page);d.text((24,18),'Bamboo Pass | Guardian boss and three real combat poses',font=font,fill='#5d4c37')
for j,state in enumerate(('idle','windup','attack')):
 sprite=Image.open(BEASTS/f'bamboo_pass_boss_{state}.png').convert('RGBA').resize((340,340),Image.Resampling.LANCZOS);page.alpha_composite(sprite,(32+j*406,52));d.text((160+j*406,399),state,font=smallfont,fill='#5d4c37')
page.convert('RGB').save(BEASTS/'bamboo-boss-preview.png')
# Display both exact seam boundaries: native strip midpoint and repeated wrap.
page=Image.new('RGBA',(1240,980),(248,242,226,255));d=ImageDraw.Draw(page)
d.text((24,14),'Scroll seam review | Alternating original and reflected tiles',font=font,fill='#5d4c37')
for j,stage in enumerate(STAGES):
 y=55+j*305;d.text((24,y),stage.replace('_',' ').title(),font=smallfont,fill='#5d4c37')
 strip=Image.open(ROUTES/f'{stage}_scroll.png').convert('RGBA'); repeated=Image.new('RGBA',(4160,280)); repeated.paste(strip,(0,0));repeated.paste(strip,(2080,0));
 # Exact boundaries are at center of each crop; no pixels or alpha are modified.
 for k,(label,x) in enumerate([('original / reflected',1040),('wrap / repeat',2080)]):
  frame=repeated.crop((x-300,0,x+300,280));page.alpha_composite(frame,(16+k*612,y+26));d.text((24+k*612,y+270),label,font=smallfont,fill='#5d4c37')
page.convert('RGB').save(ROUTES/'scroll-seam-preview.png')
print('Saved exact-seam scrolling strips for all 3 routes, 3 distinct boss poses and technical previews.')
