import math, random, subprocess
import numpy as np
from PIL import Image, ImageFilter
_src=open('/tmp/art/gen.py').read()
exec(_src.split("def bg(")[0])  # DEFS
exec("def sparks(" + _src.split("def sparks(")[1].split("def flame(")[0])
BW,BH=2048,128
COL={'cooking':('#2a1206','#ff7a1a'),'fishing':('#04121f','#3aa0ff'),'skinning':('#1c150a','#c8a050'),'mining':('#141218','#8a7cff'),
'herbalism':('#08160b','#5fe07a'),'alchemy':('#04161a','#29e0d0'),'blacksmithing':('#1a0d06','#ff7b2a'),'engineering':('#131418','#ffb02a'),
'enchanting':('#0f0820','#a35cff'),'leatherworking':('#1a0f06','#d08a3a'),'tailoring':('#170a1c','#ff7ad1'),'firstaid':('#1c0709','#ff4a4a')}
def motif(key,r):
    s=''
    if key=='cooking':
        for i in range(16):
            x=700+i*85+r.uniform(-20,20); h=r.uniform(50,105); w=h*.55
            s+=f'<path d="M{x-w/2:.0f},128 C{x-w/2:.0f},{128-h*.5:.0f} {x-w*.1:.0f},{128-h*.6:.0f} {x:.0f},{128-h:.0f} C{x+w*.3:.0f},{128-h*.6:.0f} {x+w/2:.0f},{128-h*.45:.0f} {x+w/2:.0f},128 Z" fill="url(#fire)" opacity=".9"/>'
        s+=sparks(60,1400,90,320,'#ffb347',3,2.2)
    elif key=='fishing':
        for i in range(10):
            y=70+i*6; s+=f'<path d="M500,{y} Q900,{y-8} 1300,{y} T2048,{y}" stroke="#5fb4ff" stroke-width="2" fill="none" opacity="{.5-i*.04:.2f}"/>'
        for i in range(6):
            x=900+i*190+r.uniform(-30,30); y=r.uniform(40,80); a=r.uniform(-25,25)
            s+=f'<g transform="translate({x:.0f},{y:.0f}) rotate({a:.0f}) scale(.5)"><path d="M-70,0 C-40,-34 30,-34 60,0 C30,34 -40,34 -70,0 Z" fill="#3b8fd0"/><path d="M60,0 L100,-26 L92,0 L100,26 Z" fill="#2a6fa8"/></g>'
        s+='<circle cx="1850" cy="30" r="24" fill="#e8f2ff"/><circle cx="1850" cy="30" r="60" fill="#bfe0ff" opacity=".35" filter="url(#glow)"/>'
    elif key=='skinning':
        for i in range(260):
            x=r.uniform(600,2048); y=r.uniform(0,128); l=r.uniform(14,34); a=r.uniform(60,120)
            s+=f'<line x1="{x:.0f}" y1="{y:.0f}" x2="{x+math.cos(math.radians(a))*l:.0f}" y2="{y+math.sin(math.radians(a))*l:.0f}" stroke="{r.choice(["#8a6232","#a87a42","#5e3d1c","#c8a060"])}" stroke-width="{r.uniform(1.5,3.5):.1f}" opacity=".8"/>'
        s+='<path d="M600,64 L2048,64" stroke="#e0c9a0" stroke-width="2" stroke-dasharray="12 9" opacity=".7"/>'
    elif key=='mining':
        for i in range(14):
            x=650+i*105+r.uniform(-20,20); y=r.uniform(85,120); sz=r.uniform(26,48)
            pts=' '.join(f'{x+math.cos(a)*sz*r.uniform(.7,1.1):.0f},{y+math.sin(a)*sz*.7*r.uniform(.7,1.1):.0f}' for a in [k*math.pi/4 for k in range(8)])
            c=r.choice(['#c87b4a','#9aa3b0','#e0b85a'])
            s+=f'<polygon points="{pts}" fill="#3a3640" stroke="#16141a" stroke-width="2"/><circle cx="{x:.0f}" cy="{y-6:.0f}" r="7" fill="{c}"/><ellipse cx="{x:.0f}" cy="{y:.0f}" rx="{sz:.0f}" ry="{sz*.6:.0f}" fill="{c}" opacity=".25" filter="url(#glow2)"/>'
        s+=sparks(50,1400,70,350,'#cfc7ff',5,2)
    elif key=='herbalism':
        for i in range(160):
            x=r.uniform(600,2048); h=r.uniform(40,120)
            s+=f'<path d="M{x:.0f},128 Q{x+r.uniform(-15,15):.0f},{128-h/2:.0f} {x+r.uniform(-25,25):.0f},{128-h:.0f}" stroke="#2f7a3a" stroke-width="{r.uniform(2,4):.1f}" fill="none" opacity=".85"/>'
        for i in range(12):
            x=r.uniform(750,2000); y=r.uniform(30,80); c=r.choice(['#ffd84d','#c58cff','#ff8ab8','#7fe0ff'])
            s+=f'<circle cx="{x:.0f}" cy="{y:.0f}" r="22" fill="{c}" opacity=".35" filter="url(#glow2)"/>'
            for k in range(5): s+=f'<ellipse cx="{x:.0f}" cy="{y-7:.0f}" rx="5" ry="9" fill="{c}" transform="rotate({k*72} {x:.0f} {y:.0f})"/>'
            s+=f'<circle cx="{x:.0f}" cy="{y:.0f}" r="4" fill="#fff6b0"/>'
    elif key=='alchemy':
        s+='<rect x="600" y="112" width="1448" height="10" fill="url(#wood)"/>'
        for i in range(12):
            x=700+i*115+r.uniform(-15,15); c=r.choice(['#ff3fa0','#2ff0d8','#ffd12f','#8f6bff','#5fff7a']); h=r.uniform(55,95)
            if i%3==0: s+=f'<circle cx="{x:.0f}" cy="{112-22:.0f}" r="22" fill="{c}" opacity=".85"/><rect x="{x-6:.0f}" y="{112-h:.0f}" width="12" height="{h-40:.0f}" fill="#cfe" opacity=".3"/>'
            elif i%3==1: s+=f'<rect x="{x-14:.0f}" y="{112-h:.0f}" width="28" height="{h:.0f}" rx="9" fill="{c}" opacity=".85"/>'
            else: s+=f'<path d="M{x-6:.0f},{112-h:.0f} L{x+6:.0f},{112-h:.0f} L{x+6:.0f},{112-h+20:.0f} L{x+28:.0f},112 L{x-28:.0f},112 L{x-6:.0f},{112-h+20:.0f} Z" fill="{c}" opacity=".85"/>'
            s+=f'<ellipse cx="{x:.0f}" cy="85" rx="40" ry="35" fill="{c}" opacity=".3" filter="url(#glow2)"/>'
        s+=sparks(50,1400,60,320,'#bffff6',8,2)
    elif key=='blacksmithing':
        s+='<ellipse cx="1500" cy="128" rx="700" ry="60" fill="#ff7a1a" opacity=".45" filter="url(#glow)"/>'
        for i in range(5):
            x=800+i*270
            s+=f'<path d="M{x-70},70 L{x+70},70 Q{x+80},70 {x+86},78 L{x+50},82 L{x+42},96 L{x+42},118 L{x+56},128 L{x-56},128 L{x-42},118 L{x-42},96 L{x-60},84 Q{x-80},78 {x-70},70 Z" fill="url(#dmetal)" stroke="#0b0b0d" stroke-width="2"/>'
        s+=sparks(120,1450,70,330,'#ffb347',2,2.4)
    elif key=='engineering':
        def gear(cx,cy,rr,teeth,col,rot=0):
            pts=[]
            for i in range(teeth*2):
                a=math.radians(rot+i*180/teeth); r2=rr if i%2==0 else rr*0.82; a2=math.radians(rot+(i+1)*180/teeth)
                pts+=[f'{cx+math.cos(a)*r2:.1f},{cy+math.sin(a)*r2:.1f}',f'{cx+math.cos(a2)*r2:.1f},{cy+math.sin(a2)*r2:.1f}']
            return f'<polygon points="{" ".join(pts)}" fill="{col}" stroke="#111" stroke-width="2"/><circle cx="{cx}" cy="{cy}" r="{rr*.5:.0f}" fill="#2a2d33"/><circle cx="{cx}" cy="{cy}" r="{rr*.16:.0f}" fill="#c9ced6"/>'
        x=700
        while x<2100:
            rr=r.uniform(30,62); s+=gear(int(x),int(r.uniform(50,95)),rr,int(rr/5)+6,r.choice(['url(#gold)','url(#metal)']),r.uniform(0,30)); x+=rr*1.75
    elif key=='enchanting':
        s+='<path d="M600,64 L2048,64" stroke="#c9a2ff" stroke-width="2" opacity=".7"/><path d="M600,40 L2048,40 M600,88 L2048,88" stroke="#c9a2ff" stroke-width="1" opacity=".5"/>'
        runes="ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛞᛟ"
        for i in range(30):
            x=650+i*47; s+=f'<text x="{x}" y="72" font-size="22" fill="#e6d4ff" font-family="serif" opacity=".85">{runes[i%len(runes)]}</text>'
        s+='<ellipse cx="1500" cy="64" rx="600" ry="70" fill="#8a3cff" opacity=".35" filter="url(#glow)"/>'
        s+=sparks(90,1400,64,360,'#e2c8ff',12,2.2,False)
    elif key=='leatherworking':
        s+='<rect x="560" y="10" width="1500" height="108" rx="14" fill="url(#leather)"/>'
        s+='<rect x="580" y="24" width="1460" height="80" rx="10" fill="none" stroke="#f0d6a8" stroke-width="2.5" stroke-dasharray="12 9" opacity=".8"/>'
        for i in range(400):
            x=r.uniform(560,2048); y=r.uniform(10,118); s+=f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r.uniform(.8,2):.1f}" fill="#3e2410" opacity=".35"/>'
    elif key=='tailoring':
        cols=['#8a2be2','#d94a8c','#3a7bd5','#e0a020']
        for i,c in enumerate(cols):
            y=20+i*26; s+=f'<path d="M560,{y} Q1100,{y-14} 1500,{y+4} T2048,{y} L2048,{y+30} Q1500,{y+20} 1100,{y+30} T560,{y+30} Z" fill="{c}" opacity=".85" stroke="#1b0e1f" stroke-width="2"/>'
        s+='<path d="M600,60 Q1000,10 1400,70 T2048,40" stroke="#f0d070" stroke-width="2" fill="none" opacity=".8"/>'
    elif key=='firstaid':
        s+='<rect x="560" y="44" width="1500" height="40" fill="#efe8da" opacity=".9"/>'
        for i in range(60): s+=f'<line x1="{580+i*25}" y1="46" x2="{590+i*25}" y2="82" stroke="#cfc6b4" stroke-width="2"/>'
        for i in range(7):
            x=760+i*190; s+=f'<g transform="translate({x},64) scale(.18)"><path d="M0,140 C-170,30 -190,-80 -110,-125 C-60,-150 -15,-120 0,-85 C15,-120 60,-150 110,-125 C190,-80 170,30 0,140 Z" fill="#d42c3a"/></g><circle cx="{x}" cy="64" r="34" fill="#ff3a3a" opacity=".3" filter="url(#glow2)"/>'
    return s

def render(key):
    c1,c2=COL[key]; r=random.Random(7)
    svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="{BW}" height="{BH}" viewBox="0 0 {BW} {BH}">{DEFS}
<defs><linearGradient id="bgb" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="{c1}"/><stop offset=".55" stop-color="{c1}"/><stop offset="1" stop-color="{c2}" stop-opacity=".55"/></linearGradient></defs>
<rect width="{BW}" height="{BH}" fill="url(#bgb)"/>
<ellipse cx="1600" cy="64" rx="700" ry="90" fill="{c2}" opacity=".25" filter="url(#haze)"/>
{motif(key,r)}</svg>'''
    open(f'/tmp/art/out/b_{key}.svg','w').write(svg)
    subprocess.run(['rsvg-convert','-w',str(BW),'-h',str(BH),f'/tmp/art/out/b_{key}.svg','-o',f'/tmp/art/out/b_{key}_raw.png'],check=True)
    im=Image.open(f'/tmp/art/out/b_{key}_raw.png').convert('RGBA')
    a=np.array(im).astype(np.float32)
    a[...,:3]=np.clip(a[...,:3]+np.random.default_rng(2).normal(0,6,(BH,BW,1)),0,255)
    a[...,3]=255
    im=Image.fromarray(a.astype(np.uint8),'RGBA').resize((1024,64),Image.LANCZOS)
    im.save(f'/tmp/art/out/b_{key}.png'); im.save(f'/home/claude/FarmAtlas/Media/Themes/banner_{key}.tga')

KEYS=list(COL)
for k in KEYS: render(k)
from PIL import ImageDraw
sh=Image.new('RGB',(1024,len(KEYS)*80),(14,16,20)); d=ImageDraw.Draw(sh)
for i,k in enumerate(KEYS):
    sh.paste(Image.open(f'/tmp/art/out/b_{k}.png').convert('RGB'),(0,i*80+14)); d.text((6,i*80),k,fill=(255,210,0))
sh.save('/tmp/art/out/banners.png'); print('ok')
