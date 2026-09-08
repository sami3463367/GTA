"""Original production-style 2D asset kit, reproducible and bundled offline.
Runtime terrain/walls/UI must consume these assets, not raw color placeholders.
Requires tools/requirements-art.txt. All geometry here is rasterized asset authoring.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np, random, math
R=Path(__file__).resolve().parents[1]/'game/assets/art';R.mkdir(parents=True,exist_ok=True)
random.seed(404);rng=np.random.default_rng(404)
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def font(n):return ImageFont.truetype(FONT,n)
def save(im,n):im.save(R/(n+'.png'))
def noise(size,color,amount=3):
 a=np.clip(rng.normal(0,amount,(size[1],size[0],1))+np.array(color)[None,None,:],0,255).astype('uint8')
 return Image.fromarray(a).convert('RGBA')
def panel(size,base=(18,34,48),radius=16):
 w,h=size;im=Image.new('RGBA',size);mask=Image.new('L',size);d=ImageDraw.Draw(mask);d.rounded_rectangle((0,0,w-1,h-1),radius,fill=245)
 a=np.zeros((h,w,4),dtype='uint8')
 for y in range(h):
  shade=13*(1-y/h);a[y,:,:3]=[min(255,int(c+shade)) for c in base];a[y,:,3]=np.array(mask)[y]
 im=Image.fromarray(a);d=ImageDraw.Draw(im);d.rounded_rectangle((1,1,w-2,h-2),radius,outline=(103,153,161,160),width=2);d.rounded_rectangle((5,5,w-6,h-6),max(2,radius-3),outline=(8,18,30,230),width=2)
 d.line((radius,3,w-radius,3),fill=(190,224,226,95),width=1)
 return im
save(panel((256,160)),'ui_panel');save(panel((160,80),(25,47,61),14),'ui_button')
# HUD circles, textured gradient gauges and radial feedback.
for name,size,base in [('control',160,(19,43,58)),('stick_base',256,(13,34,47)),('stick_thumb',128,(41,92,111))]:
 im=Image.new('RGBA',(size,size));d=ImageDraw.Draw(im)
 for r in range(size//2-2,2,-1):
  k=r/(size/2);c=tuple(int(v+(1-k)*20) for v in base)
  d.ellipse((size/2-r,size/2-r,size/2+r,size/2+r),fill=c+(int(150+80*(1-k)),))
 d.ellipse((3,3,size-4,size-4),outline=(111,203,209,160),width=3)
 d.arc((9,9,size-10,size-10),200,325,fill=(201,242,230,190),width=3)
 save(im,name)
for n,c in [('health',(103,224,174)),('armor',(85,170,241)),('health_lag',(246,179,89))]:
 im=Image.new('RGBA',(256,20));d=ImageDraw.Draw(im)
 for y in range(20):
  k=0.65+0.35*math.sin(y/20*math.pi);d.line((0,y,255,y),fill=tuple(int(v*k) for v in c)+(255,))
 for x in range(32,256,32):d.rectangle((x-2,0,x+1,20),fill=(15,33,48,225))
 save(im,n)
# Vector-authored action icons rasterized at high density.
for name in ['shoot','talk','vehicle','sprint','land','reload','pause','waypoint']:
 im=Image.new('RGBA',(96,96));d=ImageDraw.Draw(im);c=(224,242,232,255)
 if name=='shoot':
  d.rounded_rectangle((16,29,79,47),4,fill=c);d.polygon([(32,42),(50,42),(43,73),(28,68)],fill=c);d.line((19,26,76,26),fill=c,width=4);d.arc((44,40,64,62),0,180,fill=c,width=4)
 elif name=='talk':
  d.rounded_rectangle((12,20,83,68),13,outline=c,width=6);d.line([(26,68),(23,81),(43,68)],fill=c,width=5)
  for x in [30,48,66]:d.ellipse((x-3,41,x+3,47),fill=c)
 elif name=='vehicle':
  d.rounded_rectangle((17,37,79,70),8,outline=c,width=5);d.line([(22,38),(30,23),(66,23),(75,38)],fill=c,width=5)
  for x in [26,65]:d.ellipse((x-4,48,x+4,55),fill=c);d.rectangle((x-5,69,x+5,77),fill=c)
 elif name=='sprint':
  d.ellipse((53,12,68,27),fill=c);d.line([(49,35),(39,53),(61,65),(49,84)],fill=c,width=7);d.line([(46,39),(64,44),(76,37)],fill=c,width=6);d.line([(44,38),(29,33),(20,48)],fill=c,width=6);d.line([(40,52),(30,68),(13,66)],fill=c,width=7)
 elif name=='land':
  d.line((20,76,77,76),fill=c,width=6);d.line((49,17,49,61),fill=c,width=7);d.line([(32,46),(49,63),(66,46)],fill=c,width=6)
 elif name=='reload':
  d.arc((18,18,78,78),30,305,fill=c,width=7);d.polygon([(73,16),(82,44),(56,36)],fill=c)
 elif name=='pause':
  d.rounded_rectangle((25,20,38,76),3,fill=c);d.rounded_rectangle((57,20,70,76),3,fill=c)
 else:
  d.polygon([(48,8),(82,82),(48,67),(14,82)],fill=c)
 save(im,'icon_'+name)
# Soft light textures, particle sprites and full-screen damage vignette.
for name in ['light','smoke','spark','ripple','oil','damage','beam']:
 n=256;yy,xx=np.mgrid[:n,:n];x=(xx-128)/128;y=(yy-128)/128;r=np.sqrt(x*x+y*y)
 if name=='ripple':alpha=np.exp(-((r-.72)/.028)**2)*160;rgb=(174,236,238)
 elif name=='oil':alpha=np.exp(-(r*2.3)**2)*(0.75+.25*np.sin(x*19+y*11))*135;rgb=(26,32,42)
 elif name=='damage':alpha=np.maximum(r-.42,0)**2*210;rgb=(204,34,53)
 elif name=='beam':
  t=xx/255;alpha=np.exp(-(y/(.08+.8*t))**2)*np.sin(t*math.pi)**.8*235;rgb=(247,235,183)
 else:
  alpha=np.exp(-(r*(3.5 if name=='spark' else 2.5))**2)*255
  rgb=(255,227,159) if name in ['light','spark'] else (168,176,180)
 a=np.zeros((n,n,4),dtype='uint8');a[:,:,:3]=rgb;a[:,:,3]=np.uint8(np.clip(alpha,0,255));save(Image.fromarray(a),name)
# New patterned indoor floors and structural trims.
im=noise((256,256),(207,204,195));d=ImageDraw.Draw(im)
for y in range(0,256,32):
 for x in range(0,256,32):
  if (x//32+y//32)%2:d.rectangle((x+1,y+1,x+30,y+30),fill=(73,102,106,255))
  d.rectangle((x,y,x+31,y+31),outline=(143,152,148,255))
save(im,'floor_pattern')
im=noise((256,256),(184,190,186));d=ImageDraw.Draw(im)
for y in range(0,256,64):
 for x in range(0,256,64):d.rectangle((x,y,x+63,y+63),outline=(141,153,153,255));d.line((x+3,y+3,x+59,y+3),fill=(224,229,221,255))
save(im,'concrete')
# Props: individually authored lighting, trim, upholstery, wear and contact shadows.
def prop(name,w,h,paint):
 im=Image.new('RGBA',(w,h));d=ImageDraw.Draw(im);paint(d,w,h);save(im,'prop_'+name)
def rr(d,b,c,outline=(48,63,67,255),r=5):d.rounded_rectangle(b,r,fill=c,outline=outline,width=2)
def desk(d,w,h):
 rr(d,(5,8,w-3,h-2),(20,31,42,65));rr(d,(2,2,w-9,h-9),(157,106,64,255))
 for y in range(6,h-10,7):d.line((6,y,w-14,y),fill=(185,131,80,255))
 rr(d,(w*.57,10,w*.86,h*.55),(34,54,69,255));rr(d,(w*.59,12,w*.84,h*.49),(78,143,163,255));d.rectangle((12,13,34,33),fill=(224,219,188,255));d.line((16,20,30,20),fill=(114,125,121,255),width=2)
prop('desk',112,66,desk)
def counter(d,w,h):
 rr(d,(6,7,w-1,h-1),(16,31,43,75));rr(d,(1,1,w-8,h-7),(108,71,55,255));rr(d,(4,3,w-11,h*.57),(206,195,164,255))
 for x in range(10,w-15,24):d.line((x,h*.66,x,h-10),fill=(191,131,85,255),width=3)
 rr(d,(w-48,8,w-17,24),(39,61,71,255));d.ellipse((14,11,30,27),fill=(240,234,196,255));d.ellipse((18,15,26,23),fill=(77,49,40,255))
prop('counter',196,66,counter)
def chair(d,w,h):
 rr(d,(7,9,w-1,h-1),(12,26,38,90));rr(d,(5,6,w-8,h-6),(33,88,92,255));rr(d,(8,8,w-11,h-11),(72,135,132,255));rr(d,(3,3,w-6,16),(132,181,157,255));d.line((9,20,9,h-13),fill=(122,170,150,255),width=2)
prop('chair',44,48,chair)
def table(d,w,h):
 d.ellipse((8,9,w-2,h-1),fill=(18,32,37,80));d.ellipse((3,2,w-8,h-8),fill=(104,71,47,255),outline=(55,62,55,255),width=3);d.ellipse((7,6,w-12,h-12),fill=(213,168,104,255));d.arc((11,10,w-16,h-16),175,295,fill=(244,213,154,255),width=3)
 d.ellipse((w/2-8,h/2-8,w/2+7,h/2+7),fill=(232,233,198,255));d.ellipse((w/2-4,h/2-4,w/2+3,h/2+3),fill=(92,72,46,255))
prop('table',72,68,table)
def sofa(d,w,h):
 rr(d,(7,8,w-1,h-1),(11,26,32,90));rr(d,(2,2,w-8,h-9),(41,79,86,255));rr(d,(4,3,w-10,17),(83,137,139,255))
 for x in range(12,w-20,34):rr(d,(x,19,x+30,h-15),(69,120,124,255));d.line((x+3,23,x+27,23),fill=(132,172,164,255),width=2)
 for x in [3,w-21]:rr(d,(x,13,x+13,h-10),(112,156,149,255))
prop('sofa',132,62,sofa)
def vending(d,w,h):
 rr(d,(6,9,w-1,h-1),(16,29,37,100));rr(d,(2,1,w-9,h-7),(183,70,67,255));rr(d,(7,14,w-21,h-29),(32,65,84,255))
 for y in [22,38,54]:
  for x in [12,24,36]:d.rounded_rectangle((x,y,x+7,y+12),2,fill=[(226,176,60,255),(106,193,175,255),(212,116,103,255)][x%3])
 d.line((10,18,10,62),fill=(162,220,230,255),width=2);rr(d,(13,h-25,w-20,h-12),(34,38,44,255));d.rectangle((w-18,24,w-13,40),fill=(112,219,169,255));d.text((8,3),'FIZZ',font=font(9),fill=(242,220,172,255))
prop('vending',68,108,vending)
def plant(d,w,h):
 rr(d,(10,h-29,w-9,h-2),(182,118,79,255));d.ellipse((8,h-35,w-7,h-14),fill=(68,82,50,255))
 for i in range(12):
  a=i*math.tau/12;cx=w/2+math.cos(a)*13;cy=h/2+math.sin(a)*19
  d.ellipse((cx-10,cy-15,cx+9,cy+7),fill=(48+i*3,107+i*5,63+i,255));d.line((w/2,h-22,cx,cy-5),fill=(142,173,86,255),width=2)
prop('plant',64,86,plant)
def rug(d,w,h):
 rr(d,(1,1,w-2,h-2),(119,71,77,255),r=3)
 for inset,c in [(5,(210,164,121,255)),(10,(74,103,111,255)),(15,(193,148,108,255))]:d.rectangle((inset,inset,w-inset-1,h-inset-1),outline=c,width=3)
 for x in range(24,w-20,20):d.polygon([(x,h/2-12),(x+10,h/2),(x,h/2+12),(x-10,h/2)],outline=(210,177,127,255))
prop('rug',170,112,rug)
def lamp(d,w,h):
 d.ellipse((4,6,w-2,h-1),fill=(11,23,40,80));d.ellipse((2,2,w-6,h-6),fill=(63,74,78,255),outline=(190,183,146,255),width=3);d.ellipse((8,8,w-12,h-12),fill=(246,223,161,255));d.arc((11,11,w-15,h-15),180,300,fill=(255,247,213,255),width=3)
prop('lamp',48,48,lamp)
def bin(d,w,h):
 rr(d,(7,9,w-2,h-2),(16,28,40,90));rr(d,(3,3,w-9,h-9),(55,85,88,255))
 for x in range(8,w-10,7):d.line((x,14,x,h-15),fill=(104,133,128,255),width=2)
 rr(d,(1,2,w-7,14),(128,153,147,255));rr(d,(8,4,w-15,10),(23,43,54,255))
prop('bin',44,52,bin)
def barrier(d,w,h):
 rr(d,(4,5,w-1,h-1),(17,32,44,80));rr(d,(1,1,w-6,h-6),(206,153,66,255))
 for x in range(8,w-10,24):d.polygon([(x,3),(x+12,3),(x+3,h-10),(x-8,h-10)],fill=(44,58,65,255))
prop('barrier',108,30,barrier)
def busstop(d,w,h):
 rr(d,(8,10,w-1,h-1),(16,31,43,80));rr(d,(2,2,w-9,h-10),(54,91,105,255));rr(d,(5,5,w-12,h-24),(81,139,154,210))
 for x in range(10,w-12,28):d.line((x,6,x,h-28),fill=(154,200,199,255),width=2)
 rr(d,(10,h-24,w-17,h-12),(189,163,113,255));d.line((8,8,w-16,8),fill=(220,237,216,255),width=3)
prop('busstop',130,68,busstop)
# Asphalt overlays are authored textures, including alpha-weathered painted markings.
im=Image.new('RGBA',(128,32));d=ImageDraw.Draw(im)
for x in range(0,128,64):d.rectangle((x+8,13,x+42,17),fill=(231,221,158,225))
for _ in range(90):d.point((random.randrange(128),random.randrange(12,18)),fill=(65,77,86,45))
save(im,'lane')
im=Image.new('RGBA',(80,32));d=ImageDraw.Draw(im)
for x in range(0,80,13):d.rectangle((x+2,2,x+9,29),fill=(234,231,202,235))
save(im,'crosswalk')
im=noise((32,32),(201,191,165));d=ImageDraw.Draw(im)
d.rectangle((1,1,30,30),outline=(145,150,142,255));d.line((2,2,29,2),fill=(249,239,202,255),width=2);save(im,'curb')
im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im)
for x in [16,43]:
 for y in range(0,64,5):d.rectangle((x,y,x+5,y+3),fill=(23,31,41,100))
save(im,'skid')
im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im)
for i in range(16):
 x=random.randint(8,56);y=random.randint(8,56);r=random.randint(1,4);d.ellipse((x-r,y-r,x+r,y+r),fill=(133,41,52,150))
save(im,'hit')
# Opaque, closed roofs: interiors are separate resources, never baked into these.
for variant in range(4):
 im=Image.new('RGBA',(270,280));floor=Image.open(R/('tiles.png' if variant==3 else 'roof.png')).convert('RGBA').resize((270,260));im.alpha_composite(floor,(0,0));d=ImageDraw.Draw(im)
 colors=[(218,190,151,255),(132,171,161,255),(207,145,121,255),(145,169,185,255)]
 for k in range(12):d.rectangle((k,k,269-k,259-k),outline=colors[variant] if k<6 else (70+k*3,84+k*3,86+k*3,255))
 d.line((2,2,267,2),fill=(255,239,200,255),width=3)
 # Raised HVAC bank and blue reflective solar glazing.
 rr(d,(27,27,103,82),(53,71,78,90));rr(d,(23,23,98,76),(155,174,165,255))
 for x in [42,77]:
  d.ellipse((x-12,35,x+12,60),fill=(65,93,98,255));d.ellipse((x-7,40,x+7,55),fill=(117,147,144,255))
  for a in range(0,360,60):d.line((x,47,x+math.cos(math.radians(a))*10,47+math.sin(math.radians(a))*10),fill=(44,68,79,255),width=2)
 rr(d,(141,29,236,91),(38,64,87,255))
 for x in range(147,237,22):d.line((x,31,x,88),fill=(117,172,182,255),width=1)
 for y in [48,69]:d.line((145,y,233,y),fill=(117,172,182,255))
 d.polygon([(146,31),(162,31),(228,87),(212,87)],fill=(159,217,221,70))
 if variant==2:
  rr(d,(54,114,217,216),(217,210,178,255));rr(d,(61,121,210,209),(36,146,168,255))
  for y in range(125,204,12):d.arc((67,y-6,206,y+13),0,180,fill=(137,219,214,175),width=2)
 else:
  im.alpha_composite(Image.open(R/'prop_plant.png').resize((32,43)),(32,183));im.alpha_composite(Image.open(R/'prop_plant.png').resize((32,43)),(209,183))
  im.alpha_composite(Image.open(R/'prop_sofa.png').resize((66,31)),(103,184))
 d=ImageDraw.Draw(im);d.rectangle((0,260,269,279),fill=colors[variant])
 for x in range(11,260,25):rr(d,(x,262,x+15,275),(41,77,95,255),r=1);d.line((x+2,264,x+12,264),fill=(143,211,216,255),width=2)
 # Verify completely opaque roof over the entire collision footprint.
 im.putalpha(255)
 assert np.asarray(im)[:260,:,3].min()==255
 save(im,'building_'+str(variant))
# Helipad overlay, interior wall frame, dividers, portrait frames and faces.
im=Image.new('RGBA',(200,200));d=ImageDraw.Draw(im)
for r in range(98,1,-1):d.ellipse((100-r,100-r,100+r,100+r),fill=(45+int(r*.14),83+int(r*.13),87+int(r*.1),255))
d.ellipse((15,15,185,185),outline=(236,229,177,255),width=4);d.text((62,43),'H',font=font(94),fill=(236,229,177,255));save(im,'helipad')
im=Image.new('RGBA',(270,260));d=ImageDraw.Draw(im)
for k in range(12):
 c=(198-k*3,191-k*3,171-k*3,255);d.rectangle((k,k,269-k,259-k),outline=c)
d.line((14,14,256,14),fill=(41,58,64,180),width=4);d.line((14,14,14,247),fill=(41,58,64,180),width=4)
for x in [40,110,190]:rr(d,(x,2,x+39,10),(86,143,160,255),r=1)
d.rectangle((113,248,156,259),fill=(0,0,0,0));save(im,'wall_frame')
im=noise((128,24),(172,170,151));d=ImageDraw.Draw(im);d.rectangle((1,1,126,22),outline=(55,75,78,255),width=2);d.line((3,3,124,3),fill=(242,234,203,255),width=2);save(im,'divider')
for name,shirt,hair in [('hero',(216,151,66),(52,42,43)),('mara',(65,130,137),(47,38,39)),('inez',(151,87,122),(62,44,39)),('rafe',(88,114,153),(75,73,66))]:
 im=Image.new('RGBA',(160,160));d=ImageDraw.Draw(im)
 d.ellipse((3,3,157,157),fill=(15,38,54,250),outline=(117,204,193,255),width=4);d.ellipse((11,11,149,149),fill=(34,67,77,255))
 d.polygon([(29,142),(36,112),(64,98),(99,98),(127,113),(137,143)],fill=shirt+(255,));d.rectangle((65,85,96,112),fill=(168,112,84,255));d.ellipse((47,29,113,104),fill=(212,164,123,255));d.pieslice((44,23,116,78),175,358,fill=hair+(255,));d.arc((48,30,112,105),290,85,fill=(162,109,87,255),width=5)
 for x in [63,92]:d.line((x-4,66,x+4,66),fill=(32,47,52,255),width=3)
 d.line((80,67,84,82),fill=(160,106,84,255),width=3);d.arc((70,78,95,96),5,165,fill=(121,78,69,255),width=2)
 if name=='mara':d.arc((42,24,118,122),190,355,fill=hair+(255,),width=12)
 if name=='hero':d.rounded_rectangle((45,27,115,44),6,fill=(175,60,53,255));d.rectangle((71,41,123,46),fill=(126,51,50,255))
 # Clip portrait strictly to circular frame.
 mask=Image.new('L',(160,160));md=ImageDraw.Draw(mask);md.ellipse((2,2,158,158),fill=255);im.putalpha(mask);save(im,'portrait_'+name)
print('Polish kit generated:',len(list(R.glob('*.png'))),'bundled images')
im=Image.new('RGBA',(256,256));d=ImageDraw.Draw(im)
for i in range(4):
 a=i*math.pi/2;coords=[]
 for x,y in [(0,-4),(110,-3),(119,2),(0,5)]:coords.append((128+x*math.cos(a)-y*math.sin(a),128+x*math.sin(a)+y*math.cos(a)))
 d.polygon(coords,fill=(39,60,71,210));d.line([coords[0],coords[1]],fill=(155,183,179,170),width=1)
d.ellipse((120,120,136,136),fill=(225,221,181,255));save(im,'rotor')
# Radar artwork uses the same terrain textures and true city coordinates.
mini=Image.new('RGBA',(384,332));grass=Image.open(R/'grass.png').resize((288,332));mini.paste(grass,(0,0));d=ImageDraw.Draw(mini)
water=Image.open(R/'asphalt.png').resize((98,332));water=Image.blend(water.convert('RGB'),Image.new('RGB',water.size,(20,83,108)),.8);mini.paste(water,(286,0))
road=Image.open(R/'asphalt.png')
for x in range(80,2240,420):
 px=int(x/3000*384);mini.paste(road.resize((10,332)),(px-5,0))
for y in range(80,2600,420):
 py=int(y/2600*332);mini.paste(road.resize((286,10)),(0,py-5))
for row in range(6):
 for col in range(5):
  if row*5+col in [18,23]:continue
  roof=Image.open(R/('building_'+str((row*5+col)%4)+'.png')).resize((34,33))
  mini.alpha_composite(roof,(int((140+420*col)/3000*384),int((140+420*row)/2600*332)))
save(mini,'radar_map')
keys=sorted(p.stem for p in R.glob('*.png'))
registry=R.parents[1]/'scripts/art_registry.gd'
registry.write_text('extends RefCounted\n## Generated by tools/generate_polish.py; explicit paths survive PCK/Web exports.\nconst KEYS = '+repr(keys).replace("'",'"')+'\n')
