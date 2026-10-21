#!/usr/bin/env python3
"""Crop/place additional image_gen poses and shrine; no art or alpha edits."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json,hashlib
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'assets/cultivation/beasts'
meta=json.loads((OUT/'metadata.json').read_text())
configs=[('creek_bridge-boss','creek_bridge_boss',['idle','windup','attack'],[(10,69,712,676),(723,131,1314,678),(1321,147,2161,676)],'Ancient Riverstone Guardian'),('bamboo_normal','bamboo_pass',['windup','attack'],[(63,214,827,766),(851,197,1757,753)],'Mossback guardian')]
for source_name,prefix,states,bounds,label in configs:
 path=OUT/'sources'/f'{source_name}-source.png';source=Image.open(path).convert('RGBA');scale=min(236/max(b[2]-b[0] for b in bounds),208/max(b[3]-b[1] for b in bounds))
 for state,b in zip(states,bounds):
  crop=source.crop(b);small=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS);canvas=Image.new('RGBA',(256,256));canvas.alpha_composite(small,(round(128-small.width/2),232-small.height));name=f'{prefix}_{state}';canvas.save(OUT/f'{name}.png')
  meta['sprites'][name]={'name':label,'source':f'sources/{source_name}-source.png','source_size':list(source.size),'source_crop':list(b),'source_to_sprite_scale':scale,'ground_anchor':[128,232],'alpha_bbox':list(canvas.getchannel('A').getbbox()),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
p=OUT/'sources/opportunity_cairn-source.png';source=Image.open(p).convert('RGBA');b=(201,176,1074,1086);crop=source.crop(b);scale=min(116/crop.width,108/crop.height);small=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS);canvas=Image.new('RGBA',(128,128));canvas.alpha_composite(small,(round(64-small.width/2),116-small.height));canvas.save(OUT/'opportunity_cairn.png')
meta['props']={'opportunity_cairn':{'name':'Wayside votive shrine','source':'sources/opportunity_cairn-source.png','source_crop':list(b),'source_to_sprite_scale':scale,'canvas_size':[128,128],'ground_anchor':[64,116],'alpha_bbox':list(canvas.getchannel('A').getbbox()),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest()}}
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',20);smallfont=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16)
page=Image.new('RGBA',(1240,700),(248,242,226,255));d=ImageDraw.Draw(page);d.text((24,18),'Riverstone boss | Idle, sweep windup, water-crescent strike',font=font,fill='#5d4c37')
for j,state in enumerate(['idle','windup','attack']):
 sprite=Image.open(OUT/f'creek_bridge_boss_{state}.png').resize((320,320),Image.Resampling.LANCZOS);page.alpha_composite(sprite,(35+j*405,45));d.text((155+j*405,365),state,font=smallfont,fill='#5d4c37')
d.text((24,415),'Normal mossback: crouch and pounce',font=font,fill='#5d4c37')
for j,state in enumerate(['windup','attack']):
 sprite=Image.open(OUT/f'bamboo_pass_{state}.png');page.alpha_composite(sprite,(40+j*290,430));
d.text((800,415),'Wayside shrine',font=font,fill='#5d4c37');page.alpha_composite(Image.open(OUT/'opportunity_cairn.png').resize((210,210),Image.Resampling.LANCZOS),(800,463))
page.convert('RGB').save(OUT/'additional-route-art-preview.png')
print('Saved riverstone boss trio, normal mossback windup/pounce, and 128px shrine.')
