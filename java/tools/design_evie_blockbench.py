"""Make an editable Evie silhouette study for Blockbench; does not alter the shipped mod."""
from pathlib import Path
import copy, json, uuid, math
root=Path(__file__).resolve().parents[1]
source=json.loads((root/'models/evie_v2.bbmodel').read_text())
source['name']='evie_silhouette_study'
source['elements']=[]
source['groups']=[]
source['outliner']=[]
source['textures'][0]['relative_path']='../src/main/resources/assets/ltw_mobs/textures/entity/evie.png'

def uid():return str(uuid.uuid4())
def group(name,origin, parent=None):
    g={'name':name,'uuid':uid(),'export':True,'locked':False,'scope':0,'selected':False,
       '_static':{'properties':{},'temp_data':{}},'origin':origin,'rotation':[0,0,0],
       'color':0,'children':[],'reset':False,'shade':True,'mirror_uv':False,
       'visibility':True,'autouv':0,'isOpen':False}
    source['groups'].append(g)
    node={'uuid':g['uuid'],'isOpen':False,'children':g['children']}
    (parent['children'] if parent else source['outliner']).append(node)
    return node

def cube(name,lo,hi,band,parent,rot=None,pivot=None):
    x,y,z=lo;X,Y,Z=hi
    if min(X-x,Y-y,Z-z)<=0:return
    # A deliberately separate UV neighborhood for each material band in the original atlas.
    width=min(120,max(2,math.ceil(max(X-x,Z-z))))
    height=min(100,max(2,math.ceil(Y-y)))
    uu=10+((len(source['elements'])*37)%370)
    vv=band+8+((len(source['elements'])*7)%max(8,110-height))
    faces={n:{'uv':[uu,vv,uu+width,vv+height],'texture':0} for n in ['north','south','east','west','up','down']}
    e={'name':name,'box_uv':False,'render_order':'default','locked':False,'export':True,
       'scope':0,'allow_mirror_modeling':True,'from':list(lo),'to':list(hi),'autouv':0,
       'color':len(source['elements'])%8,'origin':list(pivot or [(x+X)/2,(y+Y)/2,(z+Z)/2]),
       'faces':faces,'type':'cube','uuid':uid()}
    if rot:e['rotation']=list(rot)
    source['elements'].append(e);parent['children'].append(e['uuid'])

body=group('torso',[0,36,0])
cube('ribcage',[ -14,27,-29],[14,45,8],0,body)
cube('hips',[-12,26,2],[12,42,31],0,body)
cube('raised shoulders',[-16,30,-28],[16,48,-8],0,body)
cube('belly/chest',[-11,24,-29],[11,32,26],128,body)
cube('breast plate',[-10,29,-36],[10,44,-22],128,body,[-12,0,0])
for side in [-1,1]:
    cube(f'shoulder armor {side}',[side*9-5,39,-25],[side*9+5,48,-10],0,body,[0,0,side*14])

neck=group('neck',[0,41,-28],body)
cube('lower arched neck',[-8,36,-50],[8,53,-27],0,neck,[-22,0,0],[0,38,-30])
cube('slender upper neck',[-6,46,-64],[6,60,-44],0,neck,[-17,0,0],[0,47,-46])
cube('throat underside',[-5,42,-63],[5,50,-35],128,neck,[-18,0,0],[0,42,-42])
head=group('head',[0,53,-60],neck)
cube('cranium',[-10,50,-75],[10,65,-55],0,head)
cube('tapered nose bridge',[-7,52,-89],[7,61,-70],128,head,[8,0,0],[0,55,-70])
cube('upper snout',[-6,49,-96],[6,56,-80],128,head)
cube('nose tip',[-5,50,-99],[5,56,-93],0,head)
cube('lower jaw',[-6,46,-95],[6,50,-75],128,head,[4,0,0],[0,48,-74])
for side in [-1,1]:
    cube(f'eyebrow ridge {side}',[side*7-2,59,-80],[side*7+2,63,-64],0,head,[0,0,-side*10])
    cube(f'violet eye {side}',[side*9-1,56,-77],[side*9+1,61,-71],256,head)
    cube(f'lower cheek {side}',[side*7-3,49,-71],[side*7+3,55,-57],128,head,[0,side*10,0])
    cube(f'nostril {side}',[side*4-1,55,-97],[side*4+1,57,-94],256,head)
    for j in range(4):
        xx=side*(9+j*1.2)
        cube(f'cheek crystal {side} {j}',[xx-1.2,55+j*1.4,-65+j*3],[xx+1.2,61+j*1.7,-61+j*3],256,head,[0,0,side*18])
    horn=group(f'horn {side}',[side*7,64,-61],head)
    cube('base horn',[side*7-3,62,-64],[side*7+3,78,-58],256,horn,[0,0,side*20],[side*7,65,-61])
    cube('swept crystal tip',[side*9-2,73,-60],[side*9+2,88,-56],256,horn,[-14,0,side*25],[side*9,75,-58])
    for t in range(5):
        cube(f'tooth {side} {t}',[side*5-0.8,45,-94+t*4],[side*5+0.8,49,-93+t*4],128,head,[0,0,side*10])
for i in range(5):
    cube(f'crown crystal {i}',[-7+i*3,64,-65+i*2],[-5+i*3,72+abs(2-i)*2,-61+i*2],256,head,[0,0,(i-2)*13])

for front,z in [(True,-20),(False,20)]:
    for side in [-1,1]:
        name=('front' if front else 'rear')+('_left' if side>0 else '_right')
        hip=group(name,[side*12,33,z],body)
        cube('upper muscle',[side*12-5,20,z-6],[side*12+5,39,z+7],0,hip,[0,0,-side*(16 if front else 10)],[side*12,31,z])
        cube('lower taper',[side*13-3,4,z-2],[side*13+3,23,z+6],0,hip,[front*8,0,-side*4],[side*13,19,z])
        cube('broad paw',[side*13-6,1,z-11],[side*13+6,7,z+9],256,hip)
        for claw in range(4):
            xx=side*13-5+claw*3
            cube(f'ivory claw {claw}',[xx,0,z-16],[xx+2,5,z-9],128,hip,[-16,0,0])

# Tapered segmented tail follows a gentle curve rather than a single rigid bar.
tail=group('tail_root',[0,35,27],body)
segments=[(27,44,11,10,32),(43,59,9,8,31),(58,73,7,7,30),(72,87,5,5,30),(86,100,3,3,31)]
for i,(z1,z2,hw,hh,y) in enumerate(segments):
    seg=group(f'tail_{i}',[0,y,z1],tail)
    cube('taper',[-hw,y-hh,z1],[hw,y+hh,z2],0,seg,[i*2,(-1)**i*3,0])
    cube('underside',[-hw+2,y-hh-1,z1],[hw-2,y-hh+3,z2],128,seg)
    for j in range(2):
        zz=z1+(j+0.35)*(z2-z1)/2
        cube(f'tail crystal {i}-{j}',[-2,y+hh-1,zz-2],[2,y+hh+7-i,zz+2],256,seg,[-12,0,0])
for side in [-1,1]:
    cube(f'tail fan {side}',[side*2-2,27,96],[side*2+2,41,114],256,tail,[0,side*24,side*12],[side*3,32,97])
for i in range(12):
    z=-23+i*4.4
    cube(f'dorsal crystal {i}',[-2,43,z-2],[2,51+((i*7)%8),z+3],256,body,[-15,0,0])

# Jointed spread wings: layered narrow membranes make a fan instead of a solid slab.
for side in [-1,1]:
    wing=group('left_wing' if side>0 else 'right_wing',[side*14,46,-12],body)
    cube('shoulder spar',[min(side*13,side*39),44,-17],[max(side*13,side*39),49,-10],256,wing,[0,0,side*8],[side*14,46,-13])
    outer=group('wrist',[side*39,49,-13],wing)
    cube('outer spar',[min(side*39,side*84),47,-13],[max(side*39,side*84),51,-8],256,outer,[0,0,side*8],[side*39,49,-11])
    for i in range(13):
        xa=side*(14+i*5.3)
        xb=side*(14+(i+1)*5.3)
        lo=min(xa,xb);hi=max(xa,xb)
        tip=37-0.4*i-0.36*i*i
        cube(f'rose membrane {i}',[lo,45,-10],[hi,46,max(-8,tip)],384,wing)
        if i in [2,5,8,11]:
            cube(f'finger spar {i}',[lo,45,-11],[lo+2,48,max(-7,tip+2)],256,wing,[0,side*3,0])
            cube(f'wingtip crystal {i}',[lo,44,max(-9,tip-1)],[lo+3,49,max(-4,tip+6)],256,wing,[0,side*20,0])
    cube('front wing edge',[min(side*14,side*83),46,-17],[max(side*14,side*83),49,-11],256,wing,[0,0,side*8],[side*14,47,-14])

saddle=group('saddle',[0,45,-5],body)
cube('leather seat',[-10,45,-15],[10,49,7],448,saddle)
cube('front pommel',[-10,46,-18],[10,54,-14],448,saddle)
cube('back rest',[-10,46,7],[10,53,11],448,saddle)
for side in [-1,1]:cube(f'strap {side}',[side*11-1,31,-7],[side*11+1,47,-3],448,saddle)

out=root/'models/evie_silhouette_study.bbmodel'
out.write_text(json.dumps(source,separators=(',',':')))
print(out, len(source['elements']),'pieces',len(source['groups']),'bones')
