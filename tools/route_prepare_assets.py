#!/usr/bin/env python3
"""Prepare original image_gen art by rectangular cropping, resampling and placement.

Preserves generated RGBA pixels and alpha. No drawing, repainting, alpha cleanup,
background replacement or concept fabrication is performed on runtime assets.
Contact sheets only add labels and place the prepared art on a plain review page.
"""
from pathlib import Path
import json, hashlib
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
ROUTES=ROOT/'assets/cultivation/routes'; BEASTS=ROOT/'assets/cultivation/beasts'
STAGES=[('bamboo_pass','青竹关','mossback','Mossback guardian'),('creek_bridge','听泉桥','riverstone','River-stone spirit'),('cloud_slope','眠云坡','cloudcrane','Cloud crane')]
# Rectangular framing places the painted lane at the shared gameplay foot line.
# It preserves the full source width; only excess foreground below the lane is cropped.
CROPS={'bamboo_pass':(0,0,2180,721),'creek_bridge':(0,0,2188,635),'cloud_slope':(0,0,2059,706)}
# Bounds cover the isolated intended sprites, not the faint stray pixels elsewhere in each cell.
# The original source alpha inside every crop is retained unchanged.
BOUNDS={'mossback':[(74,132,810,793),(909,157,1729,785)],'riverstone':[(153,130,817,802),(917,214,1743,799)],'cloudcrane':[(210,113,952,752),(1075,39,1923,752)]}
route_meta={'canvas_size':[1040,280],'ground_baseline':246,'combat_lane_x':[420,880],'generation_mode':'Built-in image_gen, original generated game art','transparent_background':True,'postprocessing':'Rectangular crop and LANCZOS resize only. Generated alpha retained.','routes':{}}
beast_meta={'canvas_size':[256,256],'common_ground_anchor':[128,232],'facing':'left','suggested_render_size':[112,112],'art_style':'Warm Chinese storybook chibi, fine brown ink contours, cel-watercolor shading','generation_mode':'Built-in image_gen, original generated two-pose sheets','postprocessing':'Rectangular crop, shared-scale LANCZOS resize, and transparent-canvas placement only. Generated alpha retained.','sprites':{}}
for stage,label,species,desc in STAGES:
 p=ROUTES/'sources'/f'{stage}-source.png'; source=Image.open(p).convert('RGBA')
 route=source.crop(CROPS[stage]).resize((1040,280),Image.Resampling.LANCZOS); route.save(ROUTES/f'{stage}.png')
 a=route.getchannel('A'); upper=a.crop((420,0,880,180))
 hist=upper.histogram()
 route_meta['routes'][stage]={'name':label,'source':f'sources/{stage}-source.png','source_size':list(source.size),'source_crop':list(CROPS[stage]),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'alpha_extrema':list(a.getextrema()),'upper_combat_region_clear_fraction':round(hist[0]/(460*180),5),'enemy_species':species}
 p=BEASTS/'sources'/f'{species}-source.png'; source=Image.open(p).convert('RGBA'); bounds=BOUNDS[species]
 scale=min(236/max(b[2]-b[0] for b in bounds),208/max(b[3]-b[1] for b in bounds))
 for state,b in zip(('idle','attack'),bounds):
  crop=source.crop(b); size=(round(crop.width*scale),round(crop.height*scale)); small=crop.resize(size,Image.Resampling.LANCZOS)
  canvas=Image.new('RGBA',(256,256)); offset=(round(128-small.width/2),232-small.height); canvas.alpha_composite(small,offset); canvas.save(BEASTS/f'{stage}_{state}.png')
  beast_meta['sprites'][f'{stage}_{state}']={'species':species,'name':desc,'source':f'sources/{species}-source.png','source_size':list(source.size),'source_crop':list(b),'source_to_sprite_scale':scale,'ground_anchor':[128,232],'alpha_bbox':list(canvas.getchannel('A').getbbox()),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
(ROUTES/'metadata.json').write_text(json.dumps(route_meta,ensure_ascii=False,indent=2)+'\n')
(BEASTS/'metadata.json').write_text(json.dumps(beast_meta,ensure_ascii=False,indent=2)+'\n')
# Technical contact sheet for review, with actual runtime scenes and enemies.
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',19)
smallfont=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',14)
page=Image.new('RGBA',(1410,1022),(248,242,226,255)); d=ImageDraw.Draw(page)
d.text((24,16),'MountainStill | Three distinct routes and original creatures',font=font,fill='#5d4c37')
for n,(stage,label,species,desc) in enumerate(STAGES):
 y=52+n*318
 d.text((24,y),stage.replace('_',' ').title()+'  /  '+desc,font=font,fill='#5d4c37')
 scene=Image.open(ROUTES/f'{stage}.png').convert('RGBA')
 # Positioned at the same foot baseline as gameplay, scale 112x112.
 foe=Image.open(BEASTS/f'{stage}_idle.png').convert('RGBA').resize((112,112),Image.Resampling.LANCZOS)
 scene.alpha_composite(foe,(720-56,246-round(232/256*112)))
 page.alpha_composite(scene,(24,y+28))
 for j,state in enumerate(('idle','attack')):
  spr=Image.open(BEASTS/f'{stage}_{state}.png').convert('RGBA').resize((146,146),Image.Resampling.LANCZOS)
  page.alpha_composite(spr,(1080+j*157,y+80))
  d.text((1119+j*157,y+237),state,font=smallfont,fill='#756650')
page.convert('RGB').save(ROUTES/'route-bestiary-preview.png')
print('Saved 3 route PNGs, 6 creature PNGs, metadata and route-bestiary-preview.png.')
