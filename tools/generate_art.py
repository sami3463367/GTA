"""Generate original bundled high-density 2D artwork. No downloaded game assets.
Requires Pillow and NumPy; only needed to regenerate PNGs, not to build/play.
Run: python tools/generate_art.py
"""
from pathlib import Path
import math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
ROOT = Path(__file__).resolve().parents[1] / 'game/assets/art'
ROOT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(1987)
random.seed(1987)
N = 256

def surface(name, base, noise=5):
    a = rng.normal(0, noise, (N, N, 1)) + np.array(base)[None,None,:]
    return Image.fromarray(np.uint8(np.clip(a,0,255)), 'RGB')

for name,base,noise in [('asphalt',(58,69,84),4),('grass',(75,139,57),9),('paving',(214,202,181),3),('roof',(222,213,190),3),('wood',(154,105,67),4),('tiles',(197,106,75),3)]:
    im=surface(name,base,noise); d=ImageDraw.Draw(im)
    if name=='asphalt':
        for _ in range(1400):
            x,y=random.randrange(N),random.randrange(N); g=random.randint(64,102)
            d.point((x,y),fill=(g-8,g,g+6))
        d.line([(0,186),(40,182),(66,196),(96,193)], fill=(43,53,65),width=1)
    elif name=='grass':
        for _ in range(4800):
            x,y=random.randrange(N),random.randrange(N); shade=random.randrange(35)
            d.line((x,y,x+random.randint(-3,3),y-random.randint(2,7)),fill=(63+shade,119+shade,40+shade//2))
    elif name in ('paving','roof'):
        for y in range(0,N,32 if name=='paving' else 64):
            step=64 if name=='paving' else 64
            for x in range(-step,N,step):
                xx=x+(32 if y%64 else 0) if name=='paving' else x
                d.rectangle((xx,y,xx+step-1,y+(31 if name=='paving' else 63)),outline=(163,156,140),width=1)
                d.line((xx+1,y+1,xx+step-2,y+1),fill=(235,225,203))
    elif name=='wood':
        for y in range(0,N,32):
            d.line((0,y,N,y),fill=(78,63,49),width=2)
            d.line((0,y+2,N,y+2),fill=(201,155,97))
            for _ in range(12):
                x=random.randrange(N); yy=y+random.randrange(4,29)
                d.line((x,yy,x+random.randrange(10,80),yy+random.randrange(-1,2)),fill=(127,88,57))
    else:
        for y in range(0,N,32):
            for x in range(-16,N,32):
                xx=x+(16 if y%64 else 0)
                d.rectangle((xx,y,xx+30,y+30),outline=(133,66,48))
                d.line((xx+2,y+2,xx+28,y+2),fill=(230,144,97),width=2)
    im.save(ROOT/(name+'.png'))

# Layered palm crown, individually shaded leaflets, with transparent edges.
im=Image.new('RGBA',(320,320));d=ImageDraw.Draw(im)
for branch in range(11):
    a=branch*math.tau/11+.17; length=random.uniform(113,148)
    points=[]
    for j in range(23):
        t=j/22; bend=.27*math.sin(t*2)
        x=160+math.cos(a+bend)*length*t; y=160+math.sin(a+bend)*length*t
        points.append((x,y))
        if j>1:
            for side in [-1,1]:
                spread=math.sin(t*math.pi)**.65*random.uniform(20,29)
                aa=a+side*1.1
                tip=(x+math.cos(aa)*spread+math.cos(a)*12,y+math.sin(aa)*spread+math.sin(a)*12)
                start=(x-math.cos(a)*7,y-math.sin(a)*7)
                end=(x+math.cos(a)*7,y+math.sin(a)*7)
                shade=int(24*math.cos(a-3.8))+random.randrange(15)
                d.polygon([start,tip,end], fill=(43+shade,126+shade,57+shade//2,255))
                d.line([(x,y),tip],fill=(94+shade,157+shade,65+shade//2,220),width=1)
    d.line(points,fill=(167,180,86,240),width=2)
d.ellipse((152,152,169,169),fill=(155,159,60,255))
im=im.filter(ImageFilter.GaussianBlur(.3)); im.save(ROOT/'palm.png')

# White metallic coupe. The native renderer tints paint per vehicle.
w,h=240,120
mask=Image.new('L',(w,h));d=ImageDraw.Draw(mask)
d.rounded_rectangle((16,21,224,99),radius=25,fill=255)
a=np.zeros((h,w,4),dtype=np.uint8)
for y in range(h):
    shine=190+58*math.exp(-((y-38)/15)**2)-54*math.exp(-((y-91)/9)**2)
    a[y,:,:3]=int(shine);a[y,:,3]=np.array(mask)[y]
im=Image.fromarray(a);d=ImageDraw.Draw(im)
for x in [46,164]:
    for y in [14,94]:
        d.rounded_rectangle((x,y,x+30,y+12),radius=4,fill=(20,29,37,255))
        d.line((x+5,y+3,x+25,y+3),fill=(91,105,116,255),width=2)
d.rounded_rectangle((17,22,223,98),radius=24,outline=(71,85,97,255),width=2)
d.polygon([(63,27),(151,27),(173,42),(173,78),(151,93),(63,93),(53,79),(53,40)],fill=(30,52,70,255))
d.polygon([(147,30),(165,42),(165,78),(147,90)],fill=(68,137,160,255))
d.line([(149,34),(160,44),(160,64)],fill=(173,224,226,255),width=3)
d.polygon([(64,31),(78,30),(78,90),(64,89),(59,76),(59,44)],fill=(66,122,145,255))
d.rounded_rectangle((80,31,142,89),radius=9,fill=(215,226,230,255),outline=(142,166,183,255),width=2)
d.line((85,34,136,34),fill=(248,253,255,255),width=3)
for y in [26,91]:
    d.line((176,y,207,y),fill=(244,250,242,230),width=3)
    d.line((30,y,48,y),fill=(179,196,205,255),width=2)
for y in [29,78]:
    d.rounded_rectangle((211,y,222,y+12),radius=3,fill=(249,246,200,255))
    d.rounded_rectangle((17,y,24,y+12),radius=2,fill=(204,49,53,255))
d.rectangle((221,47,225,73),fill=(36,53,61,255))
for y in range(48,73,5):d.line((221,y,224,y),fill=(154,178,189,255))
for y in [17,95]:d.rounded_rectangle((130,y,147,y+9),radius=3,fill=(179,197,208,255))
d.line((176,39,198,39),fill=(255,255,255,210),width=2)
d.line((177,81,198,81),fill=(101,121,138,180),width=2)
im.save(ROOT/'coupe.png')

# Upright 2.5D people: eight view directions, four articulated gait frames.
# Each cell is 128x160, rendered at 32x40 world units. Foot anchor at (64,146).
for who,shirt in [('player',(246,181,51)),('npc0',(70,174,168)),('npc1',(228,99,102)),('npc2',(125,130,211))]:
    sheet=Image.new('RGBA',(512,1280))
    for direction in range(8):
        angle=direction*math.tau/8; back=math.sin(angle)<-.35
        side=abs(math.cos(angle)); horizontal=math.cos(angle)
        for frame in range(4):
            im=Image.new('RGBA',(128,160));d=ImageDraw.Draw(im)
            stride=[0,9,0,-9][frame];cx=64
            # Shoe and trouser shapes include knees, cuffs and directional light.
            for sign in [-1,1]:
                hip=(cx+sign*10,100);knee=(cx+sign*10+stride*sign*.4,119)
                foot=(cx+sign*11+stride*sign,142-abs(stride)*.25)
                d.line([hip,knee,foot],fill=(24,56,76,255),width=15)
                d.line([(hip[0]-3,hip[1]),(knee[0]-3,knee[1]),(foot[0]-3,foot[1]-4)],fill=(48,94,117,255),width=5)
                d.rounded_rectangle((foot[0]-8,foot[1]-2,foot[0]+10,foot[1]+5),radius=4,fill=(26,31,40,255))
                d.line((foot[0]-7,foot[1]+5,foot[0]+9,foot[1]+5),fill=(181,190,183,255),width=2)
            torso=Image.new('RGBA',im.size);td=ImageDraw.Draw(torso)
            tw=21-int(side*4)
            td.rounded_rectangle((cx-tw,55,cx+tw,105),radius=9,fill=shirt+(255,))
            td.line((cx+tw-4,65,cx+tw-4,101),fill=tuple(int(v*.65) for v in shirt)+(255,),width=7)
            td.line((cx-tw+5,63,cx-tw+5,98),fill=tuple(min(255,int(v*1.1+15)) for v in shirt)+(255,),width=4)
            im.alpha_composite(torso);d=ImageDraw.Draw(im)
            d.rectangle((cx-tw,99,cx+tw,105),fill=(30,47,56,255))
            for sign in [-1,1]:
                swing=-stride*sign
                sx=cx+sign*(tw+1);sy=65
                elbow=(sx+sign*4,83+swing*.3);hand=(sx+sign*2,103+swing*.5)
                d.line([(sx,sy),elbow],fill=shirt+(255,),width=12)
                d.line([elbow,hand],fill=(192,133,91,255),width=9)
                d.ellipse((hand[0]-5,hand[1]-4,hand[0]+5,hand[1]+5),fill=(222,166,111,255))
            # Neck, shaded face and hairstyle; directional features don't spin the body.
            d.rectangle((58,46,70,60),fill=(181,120,82,255))
            d.ellipse((49,23,79,56),fill=(220,165,113,255))
            d.arc((49,23,79,56),-70,85,fill=(162,99,70,255),width=4)
            if back:
                d.rounded_rectangle((49,22,79,49),radius=10,fill=(37,37,41,255))
                d.line((53,26,70,25),fill=(75,68,56,255),width=3)
            else:
                d.pieslice((48,19,80,47),170,360,fill=(36,38,44,255))
                face=cx+int(horizontal*7)
                d.line((face-6,40,face-3,40),fill=(30,38,43,255),width=2)
                d.line((face+3,40,face+6,40),fill=(30,38,43,255),width=2)
                d.line((face+1,42,face+3,46),fill=(166,105,76,255),width=2)
                d.line((face-3,50,face+3,50),fill=(118,73,57,255),width=2)
            if who=='player':
                d.rounded_rectangle((48,20,80,31),radius=6,fill=(188,55,45,255))
                d.line((50,24,73,24),fill=(243,107,69,255),width=3)
                if not back:d.rectangle((60+int(horizontal*5),29,81+int(horizontal*5),33),fill=(146,44,43,255))
                if back:
                    d.text((59,74),'8',fill=(94,63,30,255),stroke_width=1)
            sheet.alpha_composite(im,(frame*128,direction*160))
    sheet.save(ROOT/(who+'.png'))


# Speedboat: layered gunwales, timber deck, upholstered seats and curved glazing.
im=Image.new('RGBA',(256,128));d=ImageDraw.Draw(im)
hull=[(244,64),(215,31),(168,13),(32,15),(17,26),(17,101),(32,113),(168,115),(215,97)]
d.polygon(hull,fill=(220,235,231,255));d.line(hull+[hull[0]],fill=(84,133,147,255),width=3)
d.polygon([(227,64),(202,41),(158,23),(34,26),(30,101),(159,103),(204,88)],fill=(158,103,63,255))
for y in range(30,104,9):d.line((38,y,161,y),fill=(202,151,93,255),width=2)
d.polygon([(174,29),(213,47),(230,64),(212,83),(174,100)],fill=(246,248,229,255))
d.polygon([(154,25),(176,34),(184,49),(184,80),(175,94),(154,103)],fill=(37,83,113,255))
d.line([(158,29),(173,40),(177,61),(174,87)],fill=(132,211,221,255),width=3)
for x in [53,107]:
    for y in [37,75]:
        d.rounded_rectangle((x,y,x+27,y+19),radius=5,fill=(242,231,200,255),outline=(131,127,108,255),width=2)
        d.line((x+4,y+4,x+22,y+4),fill=(255,252,226,255),width=2)
d.rounded_rectangle((5,42,23,86),radius=4,fill=(32,58,75,255));d.line((9,46,9,79),fill=(108,145,157,255),width=2)
d.line([(28,18),(169,17),(213,34)],fill=(255,255,240,255),width=3)
im.save(ROOT/'speedboat.png')

im=Image.new('RGBA',(320,180));d=ImageDraw.Draw(im)
d.polygon([(30,84),(176,70),(187,110),(30,99)],fill=(119,150,161,255))
d.polygon([(32,84),(171,74),(171,86),(32,91)],fill=(216,223,211,255))
d.polygon([(35,53),(53,55),(60,120),(35,126)],fill=(232,221,172,255))
d.line((40,58,44,116),fill=(116,151,161,255),width=3)
for y in [36,139]:
    d.rounded_rectangle((153,y,291,y+6),radius=3,fill=(36,57,69,255))
    for x in [180,255]:d.line((x,y,x,86),fill=(89,118,129,255),width=4)
mask=Image.new('L',im.size);md=ImageDraw.Draw(mask);md.ellipse((134,44,300,134),fill=255)
a=np.zeros((180,320,4),dtype=np.uint8)
for y in range(180):
    g=int(175+70*math.exp(-((y-68)/20)**2)-50*math.exp(-((y-126)/10)**2))
    a[y,:,:3]=[g,min(255,g+8),min(255,g+4)];a[y,:,3]=np.array(mask)[y]
im.alpha_composite(Image.fromarray(a));d=ImageDraw.Draw(im)
d.ellipse((134,44,300,134),outline=(78,113,129,255),width=2)
d.pieslice((216,49,295,128),270,90,fill=(24,58,83,255))
d.line([(260,56),(278,71),(283,87)],fill=(133,214,220,255),width=4)
d.line((219,48,219,129),fill=(124,151,159,255),width=2)
d.rounded_rectangle((159,62,204,112),radius=7,outline=(89,119,129,255),width=2)
d.rectangle((169,69,198,90),fill=(43,88,115,255));d.line((171,71,192,71),fill=(138,201,204,255),width=2)
d.rectangle((189,96,198,99),fill=(51,80,94,255))
for x in range(143,160,4):d.line((x,74,x,106),fill=(68,101,111,255),width=2)
d.ellipse((207,71,237,101),fill=(70,95,105,255));d.ellipse((214,78,229,93),fill=(183,197,183,255))
d.ellipse((159,50,170,61),fill=(220,72,58,255));d.line((179,49,225,49),fill=(255,249,221,255),width=3)
im.save(ROOT/'helicopter.png')

print('Generated',len(list(ROOT.glob('*.png'))),'original texture/sprite assets.')
