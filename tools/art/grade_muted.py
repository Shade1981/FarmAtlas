import numpy as np
from PIL import Image, ImageDraw
KEYS=['cooking','fishing','skinning','mining','herbalism','alchemy','blacksmithing','engineering','enchanting','leatherworking','tailoring','firstaid']
# muted map-art palette: dark umber -> warm parchment
dark=np.array([28,20,12],np.float32); mid=np.array([120,92,58],np.float32); light=np.array([226,200,150],np.float32)
def grade(a):
    rgb=a[...,:3]; L=(0.3*rgb[...,0]+0.59*rgb[...,1]+0.11*rgb[...,2])/255.0
    L=np.clip(L*1.05,0,1)[...,None]
    tone=np.where(L<0.5, dark+(mid-dark)*(L/0.5), mid+(light-mid)*((L-0.5)/0.5))
    out=tone*0.72+rgb*0.28            # keep a hint of the original colour
    out=out*0.92
    return np.clip(out,0,255)
sheet=Image.new('RGBA',(1536,4*296),(14,16,20,255)); d=ImageDraw.Draw(sheet)
for i,k in enumerate(KEYS):
    a=np.array(Image.open(f'out/{k}.png').convert('RGBA')).astype(np.float32)
    a[...,:3]=grade(a)
    im=Image.fromarray(a.astype(np.uint8),'RGBA')
    im.save(f'out/{k}_muted.png')
    im.resize((512,256),Image.LANCZOS).save(f'/home/claude/FarmAtlas/Media/Themes/{k}.tga')
    x=(i%3)*512; y=(i//3)*296
    sheet.alpha_composite(im.resize((512,256)),(x,y+30)); d.text((x+10,y+8),k,fill=(255,210,0,255))
sheet.convert('RGB').save('/mnt/user-data/outputs/szakma-kepek-tompitott.png')
print('ok')
