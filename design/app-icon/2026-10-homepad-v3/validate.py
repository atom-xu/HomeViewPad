#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,platform,sys
from xml.etree import ElementTree as ET
from PIL import Image,__version__ as pillow_version

ROOT=Path(__file__).resolve().parent
m=json.loads((ROOT/'manifest.json').read_text())
source=ROOT/'source/original-c.svg';old=ROOT.parent/'2026-10-homepad-v2/03-dwell'
assert source.read_bytes()==(old/'icon.svg').read_bytes()
assert (ROOT/'source/original-c-1024.png').read_bytes()==(old/'icon-1024.png').read_bytes()
assert hashlib.sha256(source.read_bytes()).hexdigest()==m['source_sha256']

def regions(image):
 im=image.convert('RGB');p=im.load();w,h=im.size
 pending={(x,y) for y in range(h) for x in range(w) if max(p[x,y])-min(p[x,y])>45}
 result=[]
 while pending:
  start=pending.pop();queue=[start];group=[start]
  while queue:
   x,y=queue.pop()
   for dx,dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
    q=(x+dx,y+dy)
    if q in pending:pending.remove(q);queue.append(q);group.append(q)
  xs,ys=zip(*group);result.append({'pixels':len(group),'bounds':[min(xs),min(ys),max(xs)+1,max(ys)+1]})
 return sorted(result,key=lambda v:v['bounds'][0])

def contours(path):
 tree=ET.parse(path);g=next(e for e in tree.getroot() if e.attrib.get('id')=='homepad-symbol')
 shapes=[]
 for e in g:
  shapes.append({k:v for k,v in e.attrib.items() if k not in ['fill']})
 return {'transform':g.attrib.get('transform'),'shapes':shapes}

assert contours(ROOT/'01-clear/icon.svg')==contours(ROOT/'02-soft/icon.svg'),'C1 and C2 intentionally compare finish with the same contour'
assert contours(ROOT/'01-clear/icon.svg')!=contours(ROOT/'03-balanced/icon.svg'),'C3 must change geometry'
for v in m['variants']:
 geometry=v['geometry'];assert geometry['vertical_gap']==geometry['horizontal_gap']
 svg=(ROOT/v['id']/'icon.svg').read_text()
 assert svg.count('data-part=')==3
 if v['finish']=='flat':assert 'filter=' not in svg and '<linearGradient' not in svg
 else:assert '<linearGradient' in svg and 'filter=' in svg

assets=[]
inputs=[(v['id'],ROOT/v['id']/'icon') for v in m['variants']]+[('original-c',ROOT/'source/original-c')]
for name,prefix in inputs:
 for size in [1024,120,60]:
  path=Path(str(prefix)+f'-{size}.png');im=Image.open(path)
  assert im.size==(size,size)
  assert im.convert('RGBA').getchannel('A').getextrema()==(255,255)
  row={'asset':str(path.relative_to(ROOT)),'size':[size,size],'mode':im.mode,'fully_opaque':True}
  if size in [120,60]:
   groups=regions(im);assert len(groups)==3,(name,size,groups)
   assert all(q['pixels']>=20 for q in groups)
   assert all(q['bounds'][0]>0 and q['bounds'][1]>0 and q['bounds'][2]<size and q['bounds'][3]<size for q in groups)
   # Right panes must remain separated in Y, and both must remain clear of the left pane.
   left=min(groups,key=lambda q:q['bounds'][0]);right=sorted([q for q in groups if q is not left],key=lambda q:q['bounds'][1])
   assert min(q['bounds'][0] for q in right)-left['bounds'][2]>=2,(name,size,groups)
   assert right[1]['bounds'][1]-right[0]['bounds'][3]>=2,(name,size,groups)
   row['pane_regions']=groups;row['minimum_clear_pixel_gap']=2
  assets.append(row)
report={'status':'passed','environment':{'macos':platform.mac_ver()[0],'machine':platform.machine(),'python':sys.version.split()[0],'pillow':pillow_version},'original_c_svg_and_png_unchanged':True,'c1_c2_same_refined_contours':True,'c3_distinct_geometry':True,'equal_horizontal_vertical_gaps':True,'assets':assets,'new_png_count':9,'comparison_png_count':3,'small_size_pane_checks':8,'visual_review':{'inspected':['previews/overview.png','previews/backgrounds-120-60.png','previews/geometry.png']+[v['id']+'/icon-1024.png' for v in m['variants']],'result':'Original C and three family refinements reviewed at master and actual thumbnail sizes. Rounded joins are smooth, no clipped edges or unexpected transparency, and all three panes remain separated. Soft finish has restrained depth, without a bevel/rim highlight.'},'palette_status':m['palette_status'],'limitations':['Illustrative desktop mask only','No system tinted/clear appearance integration','No simulator or physical installation','No application behavior/layout change; XCTest and XCUITest not run']}
(ROOT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(ROOT.rglob('*')) if p.is_file() and p.name!='sha256.json'}
(ROOT/'sha256.json').write_text(json.dumps(hashes,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'status':'passed','new_pngs':9,'original_comparison_pngs':3,'small_size_checks':8,'minimum_clear_pixel_gap':2},ensure_ascii=False))
