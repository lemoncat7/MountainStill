#!/usr/bin/env python3
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'assets/cultivation/equipment'
base=Image.open(OUT/'sources/base-source.png').convert('RGBA')
atlas=Image.open(OUT/'sources/equipment-atlas.png').convert('RGBA')
S=.4; FOOT=(637,1205)
def sourcepoint(p):return [round(256+(p[0]-FOOT[0])*S),round(496+(p[1]-FOOT[1])*S)]
def common(src,box,target,name):
 im=src.crop(box).resize((round(target[2]*S),round(target[3]*S)),Image.Resampling.LANCZOS)
 canvas=Image.new('RGBA',(512,512)); canvas.alpha_composite(im,tuple(sourcepoint(target[:2])))
 canvas.save(OUT/f'{name}.png'); return canvas
base_layer=common(base,(0,0,*base.size),(0,0,*base.size),'base')
# Source artwork contains only garments. The target rectangles are the original
# base coordinates and are transformed identically to the base's 512px canvas.
SPECS={
 'head_pin':((126,111,540,275),(537,179,210,81)),
 'head_crown':((680,28,1008,290),(530,123,220,176)),
 'chest_blue':((34,353,578,706),(461,756,350,191)),
 'chest_jade':((580,346,1105,691),(463,754,350,193)),
 'legs_blue':((82,712,532,1080),(475,911,325,270)),
 'legs_jade':((626,712,1059,1073),(475,911,325,233)),
 'feet_cloth':((86,1155,532,1339),(486,1115,309,95)),
 'feet_boots':((632,1106,1053,1342),(486,1070,309,140)),
}
parts={}
meta={'canvas':[512,512],'foot_anchor':[256,496],'right_hand_anchor':sourcepoint((793,1000)), 'draw_order':['base','legs','feet','chest','head','weapon'],'layers':{}}
for name,(crop,target) in SPECS.items():
 parts[name]=common(atlas,crop,target,name)
 meta['layers'][name]={'file':name+'.png','canvas':[512,512],'offset':[0,0],'scale':[1,1],'source_crop':crop,'source_base_rect':target,'alpha_bounds':parts[name].getbbox()}
(OUT/'equipment-anchors.json').write_text(json.dumps(meta,indent=2)+'\n')
# Produce a real modular combination, plus eight garment-only views.
combinations=[('Base',[]),('Blue tunic + green pants',['legs_jade','feet_cloth','chest_blue','head_crown']),('Jade cape + blue pants',['legs_blue','feet_boots','chest_jade','head_pin']),('Blue outfit',['legs_blue','feet_cloth','chest_blue','head_pin']),('Jade outfit',['legs_jade','feet_boots','chest_jade','head_crown'])]
review=Image.new('RGB',(1500,990),'#e9e4d6');d=ImageDraw.Draw(review)
try:font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16)
except:font=ImageFont.load_default()
for i,(title,names) in enumerate(combinations):
 im=base_layer.copy()
 for name in names:im.alpha_composite(parts[name])
 if i==1:im.save(OUT/'mixed-preview.png')
 im=im.resize((300,300),Image.Resampling.LANCZOS)
 review.paste(im,(i*300,35),im);d.text((i*300+12,10),title,fill='#33443e',font=font)
for i,(name,im) in enumerate(parts.items()):
 x=(i%4)*375;y=375+(i//4)*300
 review.paste(im.resize((280,280),Image.Resampling.LANCZOS),(x+45,y),im.resize((280,280),Image.Resampling.LANCZOS))
 d.text((x+20,y+270),name,fill='#33443e',font=font)
review.save(OUT/'equipment-contact-sheet.jpg',quality=94)
print(json.dumps(meta,indent=2))
