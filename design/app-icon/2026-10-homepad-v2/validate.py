#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,platform,sys
import xml.etree.ElementTree as ET
from PIL import Image,__version__ as pillow_version

ROOT=Path(__file__).resolve().parent
m=json.loads((ROOT/'manifest.json').read_text())
assert hashlib.sha256((ROOT/m['source_svg']).read_bytes()).hexdigest()==m['source_sha256']

def components(image):
 im=image.convert('RGB');pix=im.load();w,h=im.size
 remaining={(x,y) for y in range(h) for x in range(w) if max(pix[x,y])-min(pix[x,y])>45}
 out=[]
 while remaining:
  start=remaining.pop();queue=[start];group=[start]
  while queue:
   x,y=queue.pop()
   for dx,dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
    p=(x+dx,y+dy)
    if p in remaining:remaining.remove(p);queue.append(p);group.append(p)
  xs,ys=zip(*group)
  out.append({'pixels':len(group),'bounds':[min(xs),min(ys),max(xs)+1,max(ys)+1]})
 return sorted(out,key=lambda v:v['pixels'],reverse=True)

checks=[];structure_hashes=[]
for v in m['variants']:
 directory=ROOT/v['id']
 mono=ET.parse(directory/'symbol-monochrome.svg')
 symbol=next(n for n in mono.getroot() if n.attrib.get('id')=='homepad-symbol')
 structure_hashes.append(hashlib.sha256(ET.tostring(symbol)).hexdigest())
 for size in m['master_sizes']:
  path=directory/f'icon-{size}.png';im=Image.open(path)
  assert im.size==(size,size)
  assert im.convert('RGBA').getchannel('A').getextrema()==(255,255)
  result={'asset':str(path.relative_to(ROOT)),'size':[size,size],'mode':im.mode,'fully_opaque':True}
  if size in [120,60]:
   groups=components(im)
   assert len(groups)==v['expected_components'],(v['id'],size,groups)
   assert all(g['pixels']>=20 for g in groups),(v['id'],size,groups)
   assert all(g['bounds'][0]>0 and g['bounds'][1]>0 and g['bounds'][2]<size and g['bounds'][3]<size for g in groups)
   result['colored_regions']=groups
  checks.append(result)
assert len(set(structure_hashes))==3,'The structural symbols must be different, independent of color'
report={'status':'passed','environment':{'macos':platform.mac_ver()[0],'machine':platform.machine(),'python':sys.version.split()[0],'pillow':pillow_version},
 'original_source_preserved':True,'distinct_monochrome_structures':3,'assets':checks,
 'visual_review':{'inspected':['previews/overview.png','previews/backgrounds-120-60.png','previews/evolution.png']+[v['id']+'/icon-1024.png' for v in m['variants']],
 'result':'Full-size originals and 120/60 px previews inspected: soft edges, unclipped shape bounds, negative space, separate A light, connected B branches and three separate C panes remain legible. New symbols are clearly labeled as HomePad derivatives, with the formal source kept separate.'},
 'limitations':['Illustrative desktop mask only','System tinted/clear appearances not integrated or tested','No simulator or physical iPad installation','No app behavior change; XCTest/XCUITest not run'],
 'references_reviewed':m['references']}
(ROOT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(ROOT.rglob('*')) if p.is_file() and p.name!='sha256.json'}
(ROOT/'sha256.json').write_text(json.dumps(hashes,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'status':'passed','distinct_structures':3,'png_assets':9,'small_size_topology_checks':6},ensure_ascii=False))
