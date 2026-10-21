#!/usr/bin/env python3
"""Prepare original campaign sprites using crop/resample/placement only.
No alpha thresholding, background removal, tinting or drawn substitutions.
"""
from pathlib import Path
import hashlib,json,shutil
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/cultivation/beasts'; SRC=OUT/'sources'; SRC.mkdir(exist_ok=True)
# Optional generation workspace; exported/runtime assets are already included.
GENERATED=ROOT/'generated_images'
sheets={'ember_ruins':'exec-4b9a5475-7b4d-4ad5-8888-d1f0702369c0.png','moon_marsh':'exec-5458815b-808a-450c-bd59-0d4d1621abad.png','summit_gate':'exec-9de6bec6-6c31-4ca5-b286-4556f5e10b6c.png'}
singles={'creek_bridge_windup':'exec-9ce05213-23b2-4265-bdbb-c0528e9dddb4.png','cloud_slope_windup':'exec-7a9c3ac9-f1e0-4624-a033-285e8e5db268.png','ember_ruins_boss_idle':'exec-d81d3d0e-d307-4563-9ab7-8dabad240575.png','ember_ruins_boss_windup':'exec-a212834b-7bac-402b-8ab3-a3f89f47e708.png','ember_ruins_boss_attack':'exec-3674531e-368b-4d1f-b46e-6f0864ac4084.png','moon_marsh_boss_windup':'exec-d75884df-0e81-45b5-85e5-9b9e651f0863.png','moon_marsh_boss_attack':'exec-20f1e670-c79d-40be-aead-aa9af286a273.png'}
for k,v in sheets.items():shutil.copyfile(GENERATED/v,SRC/f'{k}-campaign-atlas.png')
for k,v in singles.items():shutil.copyfile(GENERATED/v,SRC/f'{k}-isolated.png')
meta=json.loads((OUT/'metadata.json').read_text()); added={}
def extract(name,source,rect,width,height_limit=204):
 im=Image.open(SRC/source).convert('RGBA'); cut=im.crop(rect) if rect else im
 # Detect only a rectangular crop; generated alpha pixels are never rewritten.
 b=cut.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox()
 cut=cut.crop(b); scale=min(width/cut.width,height_limit/cut.height)
 small=cut.resize((round(cut.width*scale),round(cut.height*scale)),Image.Resampling.LANCZOS)
 canvas=Image.new('RGBA',(256,256)); canvas.alpha_composite(small,(round(128-small.width/2),232-small.height)); canvas.save(OUT/f'{name}.png')
 rec={'name':name,'source':'sources/'+source,'source_size':list(im.size),'cell_crop':rect,'visible_bbox_crop':list(b),'source_to_sprite_scale':scale,'canvas_size':[256,256],'ground_anchor':[128,232],'alpha_bbox':list(canvas.getchannel('A').getbbox()),'source_sha256':hashlib.sha256((SRC/source).read_bytes()).hexdigest(),'notes':'Original image_gen art; rectangular crop, LANCZOS resize, transparent canvas placement; all generated alpha retained within crop.'}
 meta['sprites'][name]=rec; added[name]=rec
# Explicit rectangular gutters. Crowded boss cells were isolated by image_gen.
for route in sheets:
 for j,state in enumerate(['idle','windup','attack']):
  rect=([(0,0,510,445),(515,0,960,445),(965,0,1536,445)] if route=='moon_marsh' else [(0,0,520,455),(520,0,1000,455),(1000,0,1536,455)])[j]
  extract(route+'_'+state,route+'-campaign-atlas.png',rect,[190,196,236][j])
for name in singles:
 state=name.rsplit('_',1)[1]; extract(name,name+'-isolated.png',None,{'idle':200,'windup':208,'attack':236}[state])
extract('moon_marsh_boss_idle','moon_marsh-campaign-atlas.png',(0,450,515,1024),200)
for j,state in enumerate(['idle','windup','attack']):extract('summit_gate_boss_'+state,'summit_gate-campaign-atlas.png',[(0,470,518,1024),(518,470,998,1024),(998,470,1536,1024)][j],[200,208,236][j])
(OUT/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
(OUT/'campaign-sprites-metadata.json').write_text(json.dumps(added,ensure_ascii=False,indent=2)+'\n')
# Alpha-respecting QA contact sheet. This is a preview, never runtime art.
page=Image.new('RGBA',(1200,1030),'#eee8dc');d=ImageDraw.Draw(page);font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',20)
for row,route in enumerate(sheets):
 d.text((15,row*340+8),route+' | normal + boss anticipation / contact',font=font,fill='#4f5240')
 for col,state in enumerate(['idle','windup','attack','boss_idle','boss_windup','boss_attack']):
  im=Image.open(OUT/f'{route}_{state}.png').resize((192,192),Image.Resampling.LANCZOS);x=col*200;y=row*340+65;page.alpha_composite(im,(x,y));d.text((x+20,y+205),state,font=font,fill='#4f5240')
page.convert('RGB').save(OUT/'campaign-beasts-preview.png')
pro={'generator':'OpenAI built-in image_gen','original_art':True,'style_references':['creek_bridge_boss_idle.png','cloud_slope_idle.png'],'pipeline':'tools/prepare_campaign_beasts.py','operations':['rectangular crop','LANCZOS resize','transparent canvas placement'],'preserves_generated_alpha':True,'no_programmatic_background_removal':True,'runtime_sprites':list(added),'prompts':'sources/campaign-generation-prompts.json','sources':[]}
for f in SRC.glob('*campaign-atlas.png'):
 im=Image.open(f);pro['sources'].append({'path':str(f.relative_to(OUT)),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'size':im.size,'alpha':im.getchannel('A').getextrema()})
for f in SRC.glob('*isolated.png'):
 im=Image.open(f);pro['sources'].append({'path':str(f.relative_to(OUT)),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'size':im.size,'alpha':im.getchannel('A').getextrema()})
(OUT/'campaign-provenance.json').write_text(json.dumps(pro,indent=2)+'\n')
print('Prepared',len(added),'campaign sprites')
