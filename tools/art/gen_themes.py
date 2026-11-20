import math, random, subprocess, os
import numpy as np
from PIL import Image, ImageFilter
W,H=1024,512
OUT='/tmp/art/out'; os.makedirs(OUT,exist_ok=True)

DEFS='''
<defs>
 <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14"/></filter>
 <filter id="glow2" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="5"/></filter>
 <filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="2"/></filter>
 <filter id="haze" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="40"/></filter>
 <linearGradient id="metal" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#d9dde3"/><stop offset=".45" stop-color="#7d848e"/><stop offset="1" stop-color="#2b2f36"/></linearGradient>
 <linearGradient id="dmetal" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8a8f98"/><stop offset="1" stop-color="#1c1f24"/></linearGradient>
 <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe9a8"/><stop offset=".5" stop-color="#d7a43a"/><stop offset="1" stop-color="#6b4a12"/></linearGradient>
 <linearGradient id="wood" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#3b2312"/><stop offset=".5" stop-color="#7a4a26"/><stop offset="1" stop-color="#3b2312"/></linearGradient>
 <linearGradient id="leather" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#b07a45"/><stop offset=".6" stop-color="#7a4b25"/><stop offset="1" stop-color="#3e2410"/></linearGradient>
 <radialGradient id="fire" cx=".5" cy=".85" r=".8"><stop offset="0" stop-color="#fff6c8"/><stop offset=".3" stop-color="#ffc23a"/><stop offset=".65" stop-color="#ff5a14"/><stop offset="1" stop-color="#7a1004" stop-opacity="0"/></radialGradient>
 <radialGradient id="glass" cx=".35" cy=".3" r=".8"><stop offset="0" stop-color="#ffffff" stop-opacity=".55"/><stop offset=".35" stop-color="#ffffff" stop-opacity=".08"/><stop offset="1" stop-color="#ffffff" stop-opacity=".02"/></radialGradient>
</defs>'''

def bg(c1,c2,glow):
    return f'''<rect width="{W}" height="{H}" fill="url(#bgg)"/>
<defs><radialGradient id="bgg" cx=".62" cy=".55" r=".75"><stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></radialGradient></defs>
<ellipse cx="640" cy="300" rx="330" ry="190" fill="{glow}" opacity=".45" filter="url(#haze)"/>'''

def sparks(n,cx,cy,spread,col,seed=1,rmax=3.5,up=True):
    r=random.Random(seed); s=''
    for i in range(n):
        x=cx+r.gauss(0,spread); y=cy-abs(r.gauss(0,spread*0.9)) if up else cy+r.gauss(0,spread*0.6)
        rr=r.uniform(0.8,rmax); o=r.uniform(.35,1)
        s+=f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{rr*2.8:.1f}" fill="{col}" opacity="{o*0.35:.2f}" filter="url(#glow2)"/><circle cx="{x:.1f}" cy="{y:.1f}" r="{rr:.1f}" fill="#fff8e0" opacity="{o:.2f}"/>'
    return s

def flame(cx,base,w,h,seed):
    r=random.Random(seed); s=''
    for k,(sc,col,op) in enumerate([(1.0,'url(#fire)',.95),(0.72,'#ffb02e',.9),(0.45,'#fff1b0',.95)]):
        ww=w*sc; hh=h*sc
        p=f'M{cx-ww/2:.1f},{base} C{cx-ww/2:.1f},{base-hh*.45:.1f} {cx-ww*.15:.1f},{base-hh*.55:.1f} {cx-ww*.05+r.uniform(-8,8):.1f},{base-hh:.1f} C{cx+ww*.25:.1f},{base-hh*.6:.1f} {cx+ww/2:.1f},{base-hh*.4:.1f} {cx+ww/2:.1f},{base} Z'
        s+=f'<path d="{p}" fill="{col}" opacity="{op}"/>'
    return s

def scene(key):
    if key=='cooking':
        s=bg('#3a1d0c','#0b0605','#ff6a1a')
        s+='<ellipse cx="640" cy="420" rx="250" ry="38" fill="#000" opacity=".55" filter="url(#glow2)"/>'
        # logs
        s+='<g transform="translate(640,410)"><rect x="-170" y="-14" width="340" height="30" rx="14" fill="url(#wood)" transform="rotate(-12)"/><rect x="-170" y="-14" width="340" height="30" rx="14" fill="url(#wood)" transform="rotate(12)"/><circle cx="-160" cy="38" r="15" fill="#c98a4a"/><circle cx="160" cy="38" r="15" fill="#c98a4a"/><circle cx="-160" cy="38" r="8" fill="#7a4a26"/><circle cx="160" cy="38" r="8" fill="#7a4a26"/></g>'
        s+='<ellipse cx="640" cy="330" rx="200" ry="150" fill="#ff7a1a" opacity=".55" filter="url(#haze)"/>'
        s+=flame(640,405,210,250,3)+flame(575,405,110,150,4)+flame(705,405,120,170,5)
        # tripod + pot
        s+='<g stroke="#2a1a10" stroke-width="10" stroke-linecap="round"><line x1="470" y1="430" x2="640" y2="95"/><line x1="810" y1="430" x2="640" y2="95"/></g>'
        s+='<line x1="640" y1="100" x2="640" y2="168" stroke="#1d1a17" stroke-width="5"/>'
        s+='<path d="M560,170 Q640,150 720,170 L712,235 Q640,280 568,235 Z" fill="url(#dmetal)" stroke="#0d0d0f" stroke-width="4"/><ellipse cx="640" cy="170" rx="80" ry="15" fill="#2d2a26"/><ellipse cx="640" cy="168" rx="70" ry="10" fill="#c46a2a" opacity=".8"/>'
        s+='<path d="M560,172 Q640,160 720,172" stroke="#ffd27a" stroke-width="2" fill="none" opacity=".6"/>'
        for i,x in enumerate([610,640,672]):
            s+=f'<path d="M{x},150 C{x-25},120 {x+25},95 {x},60 C{x-20},35 {x+15},15 {x},-5" stroke="#f3e6d0" stroke-width="10" fill="none" opacity=".18" filter="url(#glow2)"/>'
        s+=sparks(40,640,250,90,'#ffb347',7)
        return s
    if key=='fishing':
        s=bg('#0e2a44','#03080f','#3aa0ff')
        s+='<circle cx="820" cy="120" r="46" fill="#e8f2ff"/><circle cx="820" cy="120" r="90" fill="#bfe0ff" opacity=".35" filter="url(#glow)"/>'
        s+='<rect x="0" y="320" width="1024" height="192" fill="#06223a" opacity=".9"/>'
        for i in range(9):
            y=330+i*20; s+=f'<path d="M{100+i*15},{y} Q{400},{y-6} {700},{y} T{1024},{y}" stroke="#5fb4ff" stroke-width="2" fill="none" opacity="{.35-i*.03:.2f}"/>'
        s+='<path d="M820,165 L800,500" stroke="#bfe0ff" stroke-width="40" opacity=".08" filter="url(#glow)"/>'
        # rod
        s+='<path d="M380,500 Q560,160 860,90" stroke="url(#wood)" stroke-width="12" fill="none" stroke-linecap="round"/><path d="M380,500 Q560,160 860,90" stroke="#d9b07a" stroke-width="2" fill="none" opacity=".6"/>'
        s+='<path d="M860,90 Q840,220 700,330" stroke="#e8f2ff" stroke-width="1.6" fill="none" opacity=".8"/>'
        s+='<circle cx="700" cy="332" r="9" fill="#d33"/><circle cx="700" cy="326" r="5" fill="#fff"/>'
        for r_ in (22,40,62): s+=f'<ellipse cx="700" cy="340" rx="{r_}" ry="{r_*.28:.1f}" stroke="#bfe0ff" stroke-width="2" fill="none" opacity="{.6-r_/140:.2f}"/>'
        # leaping fish
        s+='<g transform="translate(560,260) rotate(-25)"><path d="M-70,0 C-40,-34 30,-34 60,0 C30,34 -40,34 -70,0 Z" fill="#3b8fd0"/><path d="M-70,0 C-40,-34 30,-34 60,0" fill="#9fd6ff" opacity=".6"/><path d="M60,0 L100,-26 L92,0 L100,26 Z" fill="#2a6fa8"/><circle cx="-48" cy="-6" r="5" fill="#fff"/><circle cx="-48" cy="-6" r="2.5" fill="#000"/></g>'
        s+=sparks(25,560,300,60,'#9fd6ff',3)
        return s
    if key=='skinning':
        s=bg('#2b2414','#070604','#c8a050')
        s+='<g transform="translate(640,260)"><rect x="-200" y="-170" width="400" height="330" fill="none" stroke="url(#wood)" stroke-width="16"/>'
        s+='<path d="M-150,-120 C-110,-150 -40,-130 0,-140 C40,-130 110,-150 150,-120 C170,-60 140,0 160,60 C150,110 90,120 60,150 C20,130 -20,130 -60,150 C-90,120 -150,110 -160,60 C-140,0 -170,-60 -150,-120 Z" fill="url(#leather)" stroke="#2a170a" stroke-width="4"/>'
        for a in range(0,360,30):
            x=math.cos(math.radians(a))*175; y=math.sin(math.radians(a))*150
            s+=f'<line x1="{x*0.86:.1f}" y1="{y*0.86:.1f}" x2="{x*1.12:.1f}" y2="{y*1.08:.1f}" stroke="#d8c39a" stroke-width="2" opacity=".7"/>'
        s+='</g>'
        s+='<g transform="translate(860,330) rotate(-35)"><path d="M0,0 L150,-18 Q175,0 150,18 Z" fill="url(#metal)"/><rect x="-80" y="-12" width="80" height="24" rx="8" fill="url(#wood)"/><path d="M0,0 L150,-18" stroke="#fff" stroke-width="2" opacity=".7"/></g>'
        return s
    if key=='mining':
        s=bg('#232026','#060507','#7a6cff')
        s+='<ellipse cx="640" cy="440" rx="320" ry="40" fill="#000" opacity=".5" filter="url(#glow2)"/>'
        r=random.Random(5)
        for i,(x,y,sz,col) in enumerate([(560,380,90,'#c87b4a'),(700,390,110,'#9aa3b0'),(630,330,80,'#e0b85a'),(780,410,70,'#c87b4a')]):
            pts=' '.join(f'{x+math.cos(a)*sz*r.uniform(.7,1.1):.0f},{y+math.sin(a)*sz*.7*r.uniform(.7,1.1):.0f}' for a in [k*math.pi/4 for k in range(8)])
            s+=f'<polygon points="{pts}" fill="#3a3640" stroke="#16141a" stroke-width="3"/>'
            for j in range(5):
                a=r.uniform(0,6.28); d=r.uniform(0,sz*.5)
                s+=f'<polygon points="{x+math.cos(a)*d:.0f},{y+math.sin(a)*d*.6-12:.0f} {x+math.cos(a)*d+14:.0f},{y+math.sin(a)*d*.6:.0f} {x+math.cos(a)*d:.0f},{y+math.sin(a)*d*.6+10:.0f} {x+math.cos(a)*d-12:.0f},{y+math.sin(a)*d*.6:.0f}" fill="{col}"/>'
            s+=f'<ellipse cx="{x}" cy="{y}" rx="{sz*.6}" ry="{sz*.4}" fill="{col}" opacity=".25" filter="url(#glow)"/>'
        s+='<g transform="translate(650,230) rotate(-30)"><rect x="-14" y="-10" width="28" height="260" rx="8" fill="url(#wood)"/><path d="M-170,-20 Q0,-90 170,-20 L150,0 Q0,-50 -150,0 Z" fill="url(#metal)" stroke="#111" stroke-width="3"/></g>'
        s+=sparks(30,650,300,110,'#cfc7ff',11,3)
        return s
    if key=='herbalism':
        s=bg('#13301a','#030805','#6dff8a')
        r=random.Random(8)
        for i in range(40):
            x=r.uniform(430,900); h=r.uniform(120,300); b=470
            s+=f'<path d="M{x:.0f},{b} Q{x+r.uniform(-40,40):.0f},{b-h/2:.0f} {x+r.uniform(-60,60):.0f},{b-h:.0f}" stroke="#2f7a3a" stroke-width="{r.uniform(3,7):.1f}" fill="none" opacity=".85"/>'
        for i in range(18):
            x=r.uniform(470,880); y=r.uniform(170,380); a=r.uniform(-40,40)
            s+=f'<ellipse cx="{x:.0f}" cy="{y:.0f}" rx="34" ry="12" fill="#3f9d4a" transform="rotate({a:.0f} {x:.0f} {y:.0f})" opacity=".9"/>'
        for (x,y,c) in [(560,200,'#ffd84d'),(700,160,'#c58cff'),(820,230,'#ff8ab8'),(640,290,'#7fe0ff')]:
            s+=f'<circle cx="{x}" cy="{y}" r="60" fill="{c}" opacity=".35" filter="url(#glow)"/>'
            for k in range(6):
                a=k*60; s+=f'<ellipse cx="{x}" cy="{y-18}" rx="11" ry="22" fill="{c}" transform="rotate({a} {x} {y})"/>'
            s+=f'<circle cx="{x}" cy="{y}" r="9" fill="#fff6b0"/>'
        s+=sparks(35,680,260,140,'#d4ffb0',4,2.6)
        return s
    if key=='alchemy':
        s=bg('#0d2b2c','#030707','#29e0d0')
        s+='<rect x="400" y="400" width="560" height="22" rx="6" fill="url(#wood)"/>'
        def flask(x,base,shape,col,h):
            o=''
            if shape=='round':
                o+=f'<circle cx="{x}" cy="{base-70}" r="70" fill="{col}" opacity=".85"/><rect x="{x-16}" y="{base-h}" width="32" height="{h-120}" fill="#cfe" opacity=".25"/><circle cx="{x}" cy="{base-70}" r="70" fill="url(#glass)" stroke="#e8ffff" stroke-width="3" stroke-opacity=".6"/>'
                o+=f'<rect x="{x-20}" y="{base-h-14}" width="40" height="18" rx="4" fill="url(#wood)"/>'
            elif shape=='tall':
                o+=f'<rect x="{x-30}" y="{base-h}" width="60" height="{h}" rx="20" fill="{col}" opacity=".85"/><rect x="{x-30}" y="{base-h}" width="60" height="{h}" rx="20" fill="url(#glass)" stroke="#e8ffff" stroke-width="3" stroke-opacity=".6"/><rect x="{x-22}" y="{base-h-16}" width="44" height="18" rx="4" fill="url(#wood)"/>'
            else:
                o+=f'<path d="M{x-16},{base-h} L{x+16},{base-h} L{x+16},{base-h+50} L{x+75},{base} L{x-75},{base} L{x-16},{base-h+50} Z" fill="{col}" opacity=".85"/><path d="M{x-16},{base-h} L{x+16},{base-h} L{x+16},{base-h+50} L{x+75},{base} L{x-75},{base} L{x-16},{base-h+50} Z" fill="url(#glass)" stroke="#e8ffff" stroke-width="3" stroke-opacity=".6"/><rect x="{x-20}" y="{base-h-14}" width="40" height="16" rx="4" fill="url(#wood)"/>'
            o+=f'<ellipse cx="{x}" cy="{base-60}" rx="90" ry="80" fill="{col}" opacity=".35" filter="url(#glow)"/>'
            return o
        s+=flask(520,400,'cone','#ff3fa0',190)+flask(660,400,'round','#2ff0d8',230)+flask(800,400,'tall','#ffd12f',210)
        s+=sparks(40,660,250,110,'#bffff6',9,2.6)
        return s
    if key=='blacksmithing':
        s=bg('#2a1810','#060403','#ff7b2a')
        s+='<ellipse cx="640" cy="450" rx="300" ry="34" fill="#000" opacity=".55" filter="url(#glow2)"/>'
        s+='<path d="M470,250 L860,250 Q900,250 920,280 L800,290 L770,330 L770,400 L820,440 L500,440 L550,400 L550,330 L500,300 Q450,290 470,250 Z" fill="url(#dmetal)" stroke="#0b0b0d" stroke-width="5"/><path d="M470,250 L860,250" stroke="#e6ebf2" stroke-width="4" opacity=".7"/>'
        s+='<rect x="590" y="215" width="140" height="36" rx="6" fill="#ff8a2a"/><rect x="590" y="215" width="140" height="36" rx="6" fill="#ffd27a" opacity=".6" filter="url(#glow2)"/><ellipse cx="660" cy="232" rx="120" ry="60" fill="#ff7a1a" opacity=".5" filter="url(#glow)"/>'
        s+='<g transform="translate(760,140) rotate(30)"><rect x="-10" y="-20" width="20" height="210" rx="6" fill="url(#wood)"/><rect x="-60" y="-60" width="120" height="50" rx="6" fill="url(#metal)" stroke="#111" stroke-width="3"/></g>'
        s+=sparks(70,660,215,80,'#ffb347',2,3)
        return s
    if key=='engineering':
        s=bg('#1f2228','#050607','#ffb02a')
        def gear(cx,cy,r,teeth,col,rot=0):
            pts=[]
            for i in range(teeth*2):
                a=math.radians(rot+i*180/teeth); rr=r if i%2==0 else r*0.82
                a2=math.radians(rot+(i+1)*180/teeth)
                pts+= [f'{cx+math.cos(a)*rr:.1f},{cy+math.sin(a)*rr:.1f}', f'{cx+math.cos(a2)*rr:.1f},{cy+math.sin(a2)*rr:.1f}']
            return f'<polygon points="{" ".join(pts)}" fill="{col}" stroke="#111" stroke-width="3"/><circle cx="{cx}" cy="{cy}" r="{r*.55:.0f}" fill="#2a2d33" stroke="#111" stroke-width="3"/><circle cx="{cx}" cy="{cy}" r="{r*.18:.0f}" fill="#c9ced6"/>'
        s+=gear(600,270,130,14,'url(#gold)')+gear(790,190,90,10,'url(#metal)',9)+gear(800,370,70,9,'url(#gold)',4)
        s+='<g transform="translate(470,370)"><circle r="48" fill="#22252b" stroke="#000" stroke-width="3"/><circle cx="-14" cy="-16" r="12" fill="#fff" opacity=".25"/><rect x="-10" y="-62" width="20" height="18" fill="#555"/><path d="M0,-62 Q20,-90 40,-80" stroke="#c9a46a" stroke-width="4" fill="none"/></g>'
        s+=sparks(20,510,288,20,'#ffd27a',6,3)
        return s
    if key=='enchanting':
        s=bg('#1d0f33','#05030a','#a35cff')
        s+='<circle cx="660" cy="270" r="170" fill="none" stroke="#c9a2ff" stroke-width="3" opacity=".8"/><circle cx="660" cy="270" r="140" fill="none" stroke="#c9a2ff" stroke-width="1.5" opacity=".6"/>'
        for k in range(12):
            a=math.radians(k*30); x=660+math.cos(a)*155; y=270+math.sin(a)*155
            s+=f'<text x="{x:.0f}" y="{y+6:.0f}" font-size="22" fill="#e6d4ff" text-anchor="middle" font-family="serif" opacity=".85">{"ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃ"[k]}</text>'
        s+='<polygon points="660,120 790,345 530,345" fill="none" stroke="#c9a2ff" stroke-width="2" opacity=".6"/><polygon points="660,420 530,195 790,195" fill="none" stroke="#c9a2ff" stroke-width="2" opacity=".6"/>'
        s+='<circle cx="660" cy="270" r="190" fill="#8a3cff" opacity=".35" filter="url(#haze)"/>'
        s+='<g transform="translate(660,270) rotate(-35)"><rect x="-8" y="-150" width="16" height="300" rx="6" fill="url(#gold)"/><circle cy="-160" r="22" fill="#d9b8ff"/><circle cy="-160" r="45" fill="#b57bff" opacity=".7" filter="url(#glow)"/></g>'
        s+=sparks(60,660,270,140,'#e2c8ff',12,2.6,False)
        return s
    if key=='leatherworking':
        s=bg('#2d1c0f','#070403','#d08a3a')
        s+='<path d="M470,150 C560,120 760,130 880,160 C900,250 890,330 870,410 C760,440 560,440 480,410 C455,330 455,240 470,150 Z" fill="url(#leather)" stroke="#2a170a" stroke-width="5"/>'
        s+='<path d="M500,180 C580,158 750,165 850,188 C866,260 860,330 845,385 C750,410 580,410 505,385 C487,320 488,250 500,180 Z" fill="none" stroke="#f0d6a8" stroke-width="3" stroke-dasharray="14 10" opacity=".8"/>'
        s+='<g transform="translate(860,140) rotate(40)"><rect x="-4" y="0" width="8" height="190" rx="4" fill="url(#metal)"/><path d="M0,190 Q-60,260 -120,240 Q-200,215 -260,300" stroke="#e8d6b0" stroke-width="3" fill="none"/></g>'
        s+='<g transform="translate(560,420) rotate(-10)"><circle r="40" fill="#5a3a1c" stroke="#2a170a" stroke-width="4"/><circle r="26" fill="#7a4b25"/></g>'
        return s
    if key=='tailoring':
        s=bg('#2a1430','#07030a','#ff7ad1')
        cols=['#8a2be2','#d94a8c','#3a7bd5']
        for i,c in enumerate(cols):
            y=380-i*55
            s+=f'<path d="M470,{y} Q660,{y-30} 900,{y} L900,{y+60} Q660,{y+30} 470,{y+60} Z" fill="{c}" stroke="#1b0e1f" stroke-width="3"/><path d="M470,{y} Q660,{y-30} 900,{y}" stroke="#fff" stroke-width="2" opacity=".35" fill="none"/>'
        s+='<g transform="translate(560,170)"><rect x="-50" y="-60" width="100" height="18" rx="4" fill="url(#wood)"/><rect x="-50" y="42" width="100" height="18" rx="4" fill="url(#wood)"/><rect x="-38" y="-42" width="76" height="84" fill="#f0d070"/>'
        for k in range(8): s+=f'<line x1="-38" y1="{-38+k*10}" x2="38" y2="{-34+k*10}" stroke="#b8902a" stroke-width="2"/>'
        s+='</g><g transform="translate(820,120) rotate(35)"><rect x="-3" y="0" width="6" height="210" rx="3" fill="url(#metal)"/><ellipse cx="0" cy="12" rx="2" ry="7" fill="#000"/></g>'
        s+='<path d="M598,170 Q700,90 820,135" stroke="#f0d070" stroke-width="2.5" fill="none"/>'
        return s
    if key=='firstaid':
        s=bg('#301012','#080304','#ff4a4a')
        s+='<circle cx="640" cy="260" r="200" fill="#ff3a3a" opacity=".25" filter="url(#haze)"/>'
        # a glowing heart wrapped in a bandage (no red-cross emblem)
        s+='<g transform="translate(640,250)"><path d="M0,140 C-170,30 -190,-80 -110,-125 C-60,-150 -15,-120 0,-85 C15,-120 60,-150 110,-125 C190,-80 170,30 0,140 Z" fill="#d42c3a" stroke="#5a1010" stroke-width="6"/>'
        s+='<path d="M-80,-110 C-120,-90 -130,-40 -100,0" stroke="#ff9aa6" stroke-width="10" fill="none" opacity=".6"/>'
        s+='<path d="M-175,-20 Q0,40 175,-35 L170,20 Q0,95 -170,35 Z" fill="#efe8da" stroke="#9a9182" stroke-width="3"/>'
        for k in range(-150,170,30): s+=f'<line x1="{k}" y1="{8+abs(k)*0.05:.0f}" x2="{k+12}" y2="{40+abs(k)*0.05:.0f}" stroke="#cfc6b4" stroke-width="2"/>'
        s+='</g>'
        s+='<g transform="translate(870,390) rotate(-20)"><ellipse rx="60" ry="34" fill="#efe8da" stroke="#9a9182" stroke-width="3"/><ellipse rx="22" ry="13" fill="#d8cfbf"/></g>'
        s+='<g transform="translate(450,380)"><rect x="-18" y="-60" width="36" height="70" rx="10" fill="#ff5a6a" opacity=".85"/><rect x="-18" y="-60" width="36" height="70" rx="10" fill="url(#glass)" stroke="#ffe" stroke-width="2" stroke-opacity=".5"/><rect x="-12" y="-74" width="24" height="16" rx="3" fill="url(#wood)"/></g>'
        s+=sparks(25,640,260,150,'#ffd0d0',5,2.4,False)
        return s

def render(key):
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{DEFS}{scene(key)}</svg>'
    open(f'{OUT}/{key}.svg','w').write(svg)
    subprocess.run(['rsvg-convert','-w',str(W),'-h',str(H),f'{OUT}/{key}.svg','-o',f'{OUT}/{key}_raw.png'],check=True)
    im=Image.open(f'{OUT}/{key}_raw.png').convert('RGBA')
    a=np.array(im).astype(np.float32)
    rng=np.random.default_rng(1)
    noise=rng.normal(0,7,(H,W,1)); a[...,:3]=np.clip(a[...,:3]+noise,0,255)
    # painterly soften
    im=Image.fromarray(a.astype(np.uint8),'RGBA')
    soft=im.filter(ImageFilter.GaussianBlur(1.2)); im=Image.blend(im,soft,.5)
    a=np.array(im).astype(np.float32)
    # alpha: fade out to the left and to the edges so it melts into the window
    yy,xx=np.mgrid[0:H,0:W]
    fx=np.clip((xx-260)/360,0,1)**1.4
    fe=np.clip(np.minimum(np.minimum(xx,W-1-xx),np.minimum(yy,H-1-yy))/70,0,1)
    a[...,3]=255*fx*fe
    Image.fromarray(a.astype(np.uint8),'RGBA').save(f'{OUT}/{key}.png')
    small=Image.fromarray(a.astype(np.uint8),'RGBA').resize((512,256),Image.LANCZOS)
    small.save(f'{OUT}/{key}.tga')

KEYS=['cooking','fishing','skinning','mining','herbalism','alchemy','blacksmithing','engineering','enchanting','leatherworking','tailoring','firstaid']
for k in KEYS: render(k)
# contact sheet on a dark window-like background
sheet=Image.new('RGBA',(1024*3//2, 256*4+40*4),(14,16,20,255))
from PIL import ImageDraw
d=ImageDraw.Draw(sheet)
for i,k in enumerate(KEYS):
    im=Image.open(f'{OUT}/{k}.png').resize((512,256))
    x=(i%3)*512; y=(i//3)*(256+40)
    sheet.alpha_composite(im,(x,y+30)); d.text((x+10,y+8),k,fill=(255,210,0,255))
sheet.convert('RGB').save(f'{OUT}/sheet.png')
print('ok')
