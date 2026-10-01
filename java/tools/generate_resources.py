"""Reproducible, original pixel textures and data assets. Python standard library only."""
from pathlib import Path
import json, math, struct, zlib, random
ROOT=Path(__file__).resolve().parents[1]/'src/main/resources'
def js(path,data):
 p=ROOT/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,indent=2)+'\n')
def png(path,w,h,pixels):
 def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
 raw=b''.join(b'\0'+bytes(pixels[y*w*4:(y+1)*w*4]) for y in range(h))
 p=ROOT/path;p.parent.mkdir(parents=True,exist_ok=True)
 p.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))
for name in ['evie','eli']:
 pix=[];glow=[];rng=random.Random(25)
 colors=([(227,143,191),(255,212,229),(151,49,205),(221,94,173),(107,62,92)] if name=='evie' else [(20,47,77),(171,197,210),(22,207,255),(20,92,141),(100,67,42)])
 for y in range(512):
  for x in range(512):
   band=0 if y<128 else 1 if y<256 else 2 if y<384 else 3 if y<448 else 4
   color=colors[band];sx=(x+(y//5%2)*3)%7;sy=y%5
   shade=(-24 if sy==4 or sx==6 else 13 if sy==0 else 0)+rng.randint(-6,6)
   if band==3:shade=int(20*math.sin(x*0.22+y*0.11))
   if band==4:shade=-25 if x%12==0 else rng.randint(-8,8)
   rgba=tuple(max(0,min(255,c+shade)) for c in color)+(255,)
   pix.extend(rgba)
   glowing=(band==2 and sy!=4) or (name=='eli' and band==0 and ((x+y//3)%31<2))
   glow.extend((colors[2]+(255,)) if glowing else (0,0,0,0))
 png(Path(f'assets/ltw_mobs/textures/entity/{name}.png'),512,512,pix)
 png(Path(f'assets/ltw_mobs/textures/entity/{name}_glow.png'),512,512,glow)
for sky in [True,False]:
 name='sky_island' if sky else 'tropical_lagoon'
 biomes=['minecraft:plains','minecraft:meadow','minecraft:cherry_grove','minecraft:forest','minecraft:flower_forest'] if sky else ['minecraft:warm_ocean','minecraft:lukewarm_ocean','minecraft:deep_lukewarm_ocean']
 js(Path(f'data/ltw_mobs/worldgen/structure/{name}.json'),dict(type='ltw_mobs:habitat',sky=sky,biomes=biomes,spawn_overrides={},step='surface_structures',terrain_adaptation='none'))
 js(Path(f'data/ltw_mobs/worldgen/structure_set/{name}.json'),dict(structures=[dict(structure=f'ltw_mobs:{name}',weight=1)],placement=dict(type='minecraft:random_spread',spacing=40 if sky else 32,separation=16 if sky else 12,salt=481227 if sky else 814693)))
 js(Path(f'data/ltw_mobs/tags/worldgen/structure/{"sky" if sky else "sea"}_habitats.json'),dict(replace=False,values=[f'ltw_mobs:{name}']))
 item='sky_locator' if sky else 'sea_locator'
 js(Path(f'data/ltw_mobs/recipe/{item}.json'),dict(type='minecraft:crafting_shapeless',category='misc',ingredients=[{'item':'minecraft:compass'},{'item':'minecraft:amethyst_shard' if sky else 'minecraft:prismarine_shard'}],result=dict(id=f'ltw_mobs:{item}',count=1)))
 js(Path(f'assets/ltw_mobs/models/item/{item}.json'),dict(parent='minecraft:item/generated',textures={'layer0':f'ltw_mobs:item/{item}'}))
 pixels=[]
 for y in range(32):
  for x in range(32):
   d=math.hypot(x-15.5,y-15.5);c=(0,0,0,0)
   if d<14:c=(68,38,85,255) if sky else (22,52,72,255)
   if 11<d<14:c=(225,180,236,255) if sky else (123,224,233,255)
   if d<10 and (abs(x-15)<1 or abs(y-15)<1):c=(125,102,143,255)
   if abs(x-15)<(15-y)*0.5+1 and 5<y<16:c=(243,109,218,255) if sky else (26,214,255,255)
   if abs(x-15)<(y-14)*0.35+1 and 15<=y<25:c=(247,228,251,255)
   pixels.extend(c)
 png(Path(f'assets/ltw_mobs/textures/item/{item}.png'),32,32,pixels)
for name in ['evie','eli']:js(Path(f'assets/ltw_mobs/models/item/{name}_spawn_egg.json'),dict(parent='minecraft:item/template_spawn_egg'))
lang={
 'entity.ltw_mobs.evie':'Evie the Dragon','entity.ltw_mobs.eli':'ELi, King of the Seas',
 'item.ltw_mobs.evie_spawn_egg':'Evie Spawn Egg','item.ltw_mobs.eli_spawn_egg':'ELi Spawn Egg',
 'item.ltw_mobs.sky_locator':"Evie’s Sky Island Locator",'item.ltw_mobs.sea_locator':"ELi’s Lagoon Locator",
 'key.ltw_mobs.descend':'Descend while riding','key.categories.ltw_mobs':'LTW Mobs',
 'habitat.ltw_mobs.sky':"Evie’s sky island",'habitat.ltw_mobs.sea':"ELi’s tropical lagoon",
 'message.ltw_mobs.trust':'Trust: %s / 5 treats','message.ltw_mobs.tamed':'%s trusts you! Equip a saddle to ride.',
 'message.ltw_mobs.recovering':'Your companion is resting and will recover shortly.',
 'message.ltw_mobs.not_owner':'This companion belongs to another player.',
 'message.ltw_mobs.treat_evie':'Offer Evie five glow berries to become friends.',
 'message.ltw_mobs.treat_eli':'Offer ELi five tropical fish to become friends.',
 'message.ltw_mobs.stay':'Staying here.','message.ltw_mobs.follow':'Following you.',
 'message.ltw_mobs.saddle':'Equip a saddle, then interact to ride. Sneak + interact to follow or stay.',
 'message.ltw_mobs.overworld':'Use this locator in the Overworld.',
 'message.ltw_mobs.not_found':'No matching habitat found within the search area. Travel farther and try again.',
 'message.ltw_mobs.located':'Found %s near X: %s, Z: %s. The destination is saved on your locator.',
 'tooltip.ltw_mobs.locator':'Use to find a habitat within about 6,400 blocks. Check the saved coordinates below.',
 'tooltip.ltw_mobs.destination':'Destination — X: %s, Z: %s',
}
js(Path('assets/ltw_mobs/lang/en_us.json'),lang)
js(Path('pack.mcmeta'),{'pack':{'pack_format':34,'description':'LTW Mobs resources'}})
