#!/usr/bin/env python3
"""Dwell refinements with measurable circular fillets and explicit geometry."""
from pathlib import Path
import hashlib,json,math,shutil
from xml.etree import ElementTree as ET

ROOT=Path(__file__).resolve().parent
OLD=ROOT.parent/'2026-10-homepad-v2/03-dwell'
(ROOT/'source').mkdir(exist_ok=True)
for original,copy in [('icon.svg','original-c.svg'),('icon-1024.png','original-c-1024.png')]:
 shutil.copyfile(OLD/original,ROOT/'source'/copy)

def rounded_polygon(points,radii):
 """Exact tangent construction; refuse overlapping fillets, never clamp silently."""
 items=[]
 for i,(p,r) in enumerate(zip(points,radii)):
  prev,nxt=points[i-1],points[(i+1)%len(points)]
  a=(prev[0]-p[0],prev[1]-p[1]);b=(nxt[0]-p[0],nxt[1]-p[1])
  la,lb=math.hypot(*a),math.hypot(*b);a=(a[0]/la,a[1]/la);b=(b[0]/lb,b[1]/lb)
  theta=math.acos(max(-1,min(1,a[0]*b[0]+a[1]*b[1])))
  d=r/math.tan(theta/2)
  items.append({'start':(p[0]+a[0]*d,p[1]+a[1]*d),'end':(p[0]+b[0]*d,p[1]+b[1]*d),'radius':r,'tangent_distance':d})
 for i in range(len(points)):
  nxt=(i+1)%len(points);edge=math.dist(points[i],points[nxt])
  assert items[i]['tangent_distance']+items[nxt]['tangent_distance']<edge,('Overlapping fillets',i)
 def pt(p):return f'{p[0]:.4f} {p[1]:.4f}'
 d='M'+pt(items[0]['start'])
 for i,item in enumerate(items):
  if i:d+=' L'+pt(item['start'])
  d+=f' A{item["radius"]} {item["radius"]} 0 0 1 '+pt(item['end'])
 return d+' Z'

def geometry(v):
 x0,x1=v['left'],v['right'];left_inner=512-v['gap']/2;right_inner=512+v['gap']/2
 slope=(v['eave']-v['apex'])/((x1-x0)/2)
 cut_y=v['apex']+v['gap']/2*slope
 r=v['radius'];tip=v['tip_radius']
 left=rounded_polygon([(left_inner,cut_y),(left_inner,v['bottom']),(x0,v['bottom']),(x0,v['eave'])],[tip,r,r,r])
 roof=rounded_polygon([(right_inner,cut_y),(x1,v['eave']),(x1,v['crossbar']),(right_inner,v['crossbar'])],[tip,r,r,r])
 gold_y=v['crossbar']+v['horizontal_gap']
 panes=f'<path data-part="living-pane" d="{left}" fill="FILL_BODY"/><path data-part="roof-pane" d="{roof}" fill="FILL_ROOF"/><rect data-part="lit-pane" x="{right_inner:g}" y="{gold_y:g}" width="{x1-right_inner:g}" height="{v["bottom"]-gold_y:g}" rx="{r}" fill="FILL_CORE"/>'
 return panes,{'width':x1-x0,'roof_pitch_degrees':math.degrees(math.atan(slope)),'virtual_apex':[512,v['apex']],'vertical_gap':v['gap'],'horizontal_gap':v['horizontal_gap'],'main_corner_radius':r,'roof_tip_radius':tip,'optical_translation':[8,-10],'pane_bottom':v['bottom']-10,'gold_height':v['bottom']-gold_y}

base=dict(left=232,right=792,apex=224,eave=434,gap=56,horizontal_gap=56,crossbar=528,bottom=768,radius=44,tip_radius=12)
VARIANTS=[
 dict(base,id='01-clear',label='C1',name='清',en='Clear',tag='干净平面',recommended=False,finish='flat',description='收拢圆角与缝隙，让形状本身说话。',detail='主圆角统一为 44 px；两道缝均为 56 px。无阴影、无渐变。'),
 dict(base,id='02-soft',label='C2',name='润',en='Soft',tag='细腻层次',recommended=True,finish='soft',description='同一精修轮廓，添一点安静的光。',detail='与 C1 保持同轮廓；以轻色阶和极弱承托增加层次，不加高光边框。'),
 dict(id='03-balanced',label='C3',name='衡',en='Balanced',tag='更稳几何',recommended=False,finish='flat',description='屋顶更舒展，缝隙更紧凑，重心更稳。',detail='主体增至 584 px；坡度降至约 33.3°，缝宽 48 px、主圆角 48 px。',left=220,right=804,apex=248,eave=440,gap=48,horizontal_gap=48,crossbar=516,bottom=756,radius=48,tip_radius=14),
]
original_symbol=next(e for e in ET.parse(OLD/'icon.svg').getroot() if e.attrib.get('id')=='homepad-symbol')
original_mono=ET.tostring(original_symbol,encoding='unicode')
import re
original_mono=re.sub(r'url\(#[^)]+\)','#395148',original_mono)
original_mono=re.sub(r' filter="[^"]*"','',original_mono)
(ROOT/'source/original-c-monochrome.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">{original_mono}</svg>')

metrics=[]
for v in VARIANTS:
 directory=ROOT/v['id'];directory.mkdir(exist_ok=True)
 panes,g=geometry(v);metrics.append(dict(id=v['id'],label=v['label'],name=v['name'],tag=v['tag'],description=v['description'],detail=v['detail'],recommended=v['recommended'],finish=v['finish'],geometry=g))
 soft=v['finish']=='soft'
 defs='''<linearGradient id="canvas" x1="0" y1="0" x2=".8" y2="1"><stop stop-color="#FDFEFC"/><stop offset="1" stop-color="#F2F5F1"/></linearGradient><linearGradient id="body" x1=".15" y1="0" x2=".5" y2="1"><stop stop-color="#65C9AF"/><stop offset=".55" stop-color="#43B99F"/><stop offset="1" stop-color="#2DA88E"/></linearGradient><linearGradient id="roof" x1=".1" y1="0" x2=".8" y2="1"><stop stop-color="#9BDABA"/><stop offset="1" stop-color="#74CBA8"/></linearGradient><linearGradient id="core" x1="0" y1="0" x2=".6" y2="1"><stop stop-color="#F2D195"/><stop offset="1" stop-color="#E9BE79"/></linearGradient><filter id="settle" x="-20%" y="-20%" width="140%" height="145%" color-interpolation-filters="sRGB"><feDropShadow dx="0" dy="5" stdDeviation="7" flood-color="#426F59" flood-opacity=".09"/></filter>''' if soft else ''
 fills=['url(#body)','url(#roof)','url(#core)'] if soft else ['#40B69C','#85D0AE','#EBC582']
 colored=panes
 for key,value in zip(['BODY','ROOF','CORE'],fills):colored=colored.replace('FILL_'+key,value)
 flat=panes
 for key in ['BODY','ROOF','CORE']:flat=flat.replace('FILL_'+key,'#395148')
 for mono in [False,True]:
  title=f'HomePad Dwell refinement / {v["en"]}'
  background='' if mono else f'<rect width="1024" height="1024" fill="{"url(#canvas)" if soft else "#F8FAF6"}"/>'
  filter_attr=' filter="url(#settle)"' if soft and not mono else ''
  svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024" role="img" aria-labelledby="title desc"><title id="title">{title}</title><desc id="desc">Three soft panes form a HomePad house. Refined original app symbol, not a formal corporate logo. Palette remains exploratory. Opaque square master; preview masking only.</desc><defs>{defs if not mono else ''}</defs>{background}<g id="homepad-symbol" transform="translate(8 -10)"{filter_attr}>{flat if mono else colored}</g></svg>'''
  (directory/('symbol-monochrome.svg' if mono else 'icon.svg')).write_text(svg)

manifest={'date':'2026-10-16','round':3,'user_decision':'Refine round-2 C Dwell; no final palette or AppIcon replacement authorized','source_svg':'source/original-c.svg','source_sha256':hashlib.sha256((ROOT/'source/original-c.svg').read_bytes()).hexdigest(),'variants':metrics,'recommended':'02-soft','sizes':[1024,120,60],'palette_status':'Exploratory consistent teal/warm-yellow baseline; not approved final colors','original_metrics':{'width':512,'roof_pitch_degrees':math.degrees(math.atan(142/174)),'vertical_gap':64,'horizontal_gap':40,'corner_radii':'Left lower 44/48, roof base 28, gold 44; original quadratic construction'},'preview_mask':'superellipse 4.6, illustration only','integration':'No AppIcon, project, behavior, install, commit, push or publish changes'}
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')

all_items=[dict(id='source',label='原 C',name='家窗',tag='第二轮原稿',description='保留用户选中的方向，作为比较基准。',detail='原稿 512 px；竖缝 64、横缝 40。',recommended=False,original=True)]+metrics
def imgpath(v,size=1024):return f'source/original-c-{size}.png' if v.get('original') else f'{v["id"]}/icon-{size}.png'
def monopath(v):return 'source/original-c-monochrome.svg' if v.get('original') else f'{v["id"]}/symbol-monochrome.svg'
def icon(v,size):
 asset=size if size in [120,60] else 1024
 return f'<div class="icon" style="width:{size}px;height:{size}px"><img class="masked" src="{imgpath(v,asset)}" alt="{v["label"]} {v["name"]}"></div>'
cards=''.join(f'''<article class="card {'original-card' if v.get('original') else ''}"><div class="label"><span>{v['label']} / {v['tag']}</span>{'<em>推荐</em>' if v['recommended'] else ''}</div><div class="hero">{icon(v,242)}</div><h2>{v['name']}</h2><p>{v['description']}</p><div class="mono"><img src="{monopath(v)}" alt="同色结构"><span>同色结构</span>{icon(v,60)}</div><small class="card-note">{v['detail']}</small></article>''' for v in all_items)
backgrounds=''.join(f'''<div class="wallpaper {theme}"><div class="wall-label">{v['label']} · {v['name']} / {theme.upper()}</div><div class="pair"><div>{icon(v,120)}<b>HomePad</b><small>120 px</small></div><div>{icon(v,60)}<b>HomePad</b><small>60 px</small></div></div></div>''' for theme in ['light','dark'] for v in all_items)
geometry_cards=''.join(f'''<article class="geometry"><div class="label">{v['label']} · {v['name']}</div><div class="geometry-art"><img src="{monopath(v)}" alt="{v['label']} 形状比例"></div><p>{v['detail']}</p></article>''' for v in all_items)
links=''.join(f'''<article><b>{v['label']} · {v['name']}</b><div><a href="{v['id']}/icon-1024.png">1024 PNG</a><a href="{v['id']}/icon.svg">SVG</a><a href="{v['id']}/icon-120.png">120 PNG</a><a href="{v['id']}/icon-60.png">60 PNG</a></div></article>''' for v in metrics)
pts=[]
for i in range(256):
 a=math.tau*i/256;pts.append(f'{.5+.5*math.copysign(abs(math.cos(a))**(2/4.6),math.cos(a)):.6f},{.5+.5*math.copysign(abs(math.sin(a))**(2/4.6),math.sin(a)):.6f}')
html=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>HomePad · 家窗精修</title><style>
*{{box-sizing:border-box}}:root{{color-scheme:light}}body{{margin:0;background:#eef1ec;color:#2b3d32;font:16px/1.5 -apple-system,BlinkMacSystemFont,"Helvetica Neue","PingFang SC",sans-serif;-webkit-font-smoothing:antialiased}}.board{{width:1600px;max-width:100%;margin:0 auto;padding:50px 66px 43px;background:#f4f6f0}}.eyebrow{{display:flex;justify-content:space-between;color:#85947e;font-size:11px;letter-spacing:2px;font-weight:550}}h1{{font-size:58px;font-weight:550;line-height:1.2;letter-spacing:-2px;margin:22px 0 14px}}.lede{{font-size:18px;color:#889783;margin:0}}.cards{{display:grid;grid-template-columns:repeat(4,1fr);gap:17px;margin:36px 0 25px}}.card{{padding:22px 23px;background:#fff;border:1px solid #e1e7dc;border-radius:25px}}.original-card{{background:#f8faf5;border-style:dashed}}.label{{display:flex;justify-content:space-between;align-items:center;font-size:10px;letter-spacing:1.3px;font-weight:550;color:#8d9b85;min-height:23px}}em{{font-size:10px;letter-spacing:.6px;font-style:normal;padding:4px 11px;border-radius:20px;background:#e9f2e2;color:#69916a}}.hero{{height:283px;display:flex;justify-content:center;align-items:center}}.icon{{display:inline-block;flex-shrink:0;filter:drop-shadow(0 6px 12px #314b3010)}}.icon>img{{display:block;width:100%;height:100%}}.masked{{clip-path:url(#mask)}}h2{{font-size:27px;font-weight:550;margin:4px 0 8px}}.card p{{font-size:13px;color:#819178;line-height:1.8;margin:0 0 22px;min-height:46px}}.mono{{border-top:1px solid #edf1e7;padding-top:15px;display:flex;align-items:center;gap:7px}}.mono>img{{width:52px;height:52px}}.mono>span{{font-size:10px;color:#a1ad98}}.mono>.icon{{margin-left:auto}}.card-note{{display:block;color:#a1ad96;font-size:11px;line-height:1.9;margin-top:13px;min-height:43px}}.foot{{border-top:1px solid #dce4d5;padding-top:21px;display:flex;justify-content:space-between;gap:20px;font-size:12px;color:#92a088}}.section-title{{font-size:34px;font-weight:550;letter-spacing:-.7px;margin:17px 0 12px}}.backgrounds{{display:grid;grid-template-columns:repeat(4,1fr);gap:17px;margin:32px 0 25px}}.wallpaper{{height:275px;border-radius:21px;position:relative;overflow:hidden}}.light{{background:radial-gradient(ellipse at 0 0,#fff4df,transparent 70%),radial-gradient(ellipse at 100% 100%,#bfd0b9,transparent 85%),#e5eadf;color:#435c44}}.dark{{background:radial-gradient(ellipse at 100% 0,#405a56,transparent 65%),radial-gradient(ellipse at 0 100%,#4e5954,transparent 80%),#1f302b;color:#fff}}.wall-label{{position:absolute;left:17px;top:17px;opacity:.55;font-size:10px;letter-spacing:1.4px}}.pair{{display:flex;align-items:center;justify-content:center;gap:40px;height:100%;padding-top:22px}}.pair>div{{display:flex;align-items:center;flex-direction:column}}.pair b{{font-size:11px;font-weight:500;margin-top:10px}}.pair small{{font-size:9px;letter-spacing:1px;opacity:.5;margin-top:8px}}.geometries{{display:grid;grid-template-columns:repeat(4,1fr);gap:17px;margin:32px 0 26px}}.geometry{{background:#fff;border:1px solid #e0e6da;border-radius:23px;padding:22px}}.geometry-art{{height:250px;display:flex;align-items:center;justify-content:center;background:linear-gradient(#dce5d544 1px,transparent 1px),linear-gradient(90deg,#dce5d544 1px,transparent 1px);background-size:24px 24px;margin-top:17px;border-radius:10px}}.geometry-art img{{width:250px;height:250px}}.geometry p{{font-size:12px;color:#8a9a7f;line-height:1.9;min-height:66px;margin:20px 0 0}}.recommend{{border-radius:20px;background:#e9f0e2;padding:23px 27px;display:flex;gap:25px;align-items:center;color:#8b9e7c;margin:25px 0}}.recommend b{{font-size:17px;font-weight:550;white-space:nowrap;color:#5d7c59}}.recommend p{{font-size:13px;line-height:1.9;margin:0}}.downloads{{display:grid;grid-template-columns:repeat(3,1fr);gap:24px;margin-top:28px}}.downloads article{{border-top:1px solid #dce4d5;padding-top:17px}}.downloads b{{font-size:16px;font-weight:500}}.downloads article>div{{margin-top:17px}}a{{display:inline-block;color:#78936b;font-size:12px;text-decoration:none;border-bottom:1px solid #bac9ae;margin:0 18px 12px 0}}.notes{{font-size:12px;line-height:1.9;color:#98a48d;margin-top:20px}}@media(max-width:1000px){{.board{{padding:30px 22px}}h1{{font-size:43px}}.cards,.backgrounds,.geometries,.downloads{{grid-template-columns:1fr}}.cards,.backgrounds,.geometries{{max-width:540px;margin:28px auto}}.foot,.recommend{{flex-direction:column;align-items:flex-start}}}}
</style><svg width="0" height="0" style="position:absolute"><defs><clipPath id="mask" clipPathUnits="objectBoundingBox"><polygon points="{' '.join(pts)}"/></clipPath></defs></svg><main>
<section class="board overview-board"><div class="eyebrow"><span>HOMEPAD / DWELL REFINEMENT 03</span><span>16 OCT 2026 · SAME FAMILY, FINER FORM</span></div><h1>把喜欢的形状，磨得再好一点。</h1><p class="lede">保留三块窗格的家，精修比例、圆角、缝隙与缩小后的轮廓。</p><div class="cards">{cards}</div><div class="foot"><span>原 C 与三版精修并列；下方可看同色结构及 60 px 实图。</span><span>C1 / C2 同轮廓对比材质，C3 检验更宽、更稳的比例。</span><span>青绿与暖黄仍为探索配色 · 尚未替换 AppIcon</span></div></section>
<section class="board background-board"><div class="eyebrow"><span>ORIGINAL + REFINEMENTS AT ACTUAL SIZE</span><span>120 PX + 60 PX / 1×</span></div><h2 class="section-title">缩小以后，窗格依然清楚。</h2><p class="lede">直接使用各版导出的 120 / 60 px PNG，观察分隔、留白和主体占比。</p><div class="backgrounds">{backgrounds}</div><div class="foot"><span>深浅背景为合成桌面，圆角仅作示意。</span><span>缝隙在 60 px 下仍分得开，未以阴影补轮廓。</span><span>按 100% 缩放查看实际像素。</span></div></section>
<section class="board geometry-board"><div class="eyebrow"><span>OPTICAL GEOMETRY</span><span>COMPARE THE FORM BEFORE THE COLOR</span></div><h2 class="section-title">细节收拢，性格留下。</h2><p class="lede">同色、同尺度比较：屋顶更顺，内外圆角有统一的节奏。</p><div class="geometries">{geometry_cards}</div><div class="recommend"><b>推荐 C2 · 润</b><p>保留干净的窗格轮廓，统一缝隙与圆角，再用轻微色阶增加层次。它比原稿更完整，也不会因为材质而显得厚重。若偏好纯平面，可直接选同轮廓的 C1。</p></div><div class="foot"><span>C1 / C2：宽 560 px，坡度约 36.9°，缝宽 56 px。</span><span>C3：宽 584 px，坡度约 33.3°，缝宽 48 px。</span><span>三版均作 x +8、y −10 px 光学位移。</span></div><div class="downloads">{links}</div><p class="notes">所有新稿包含 1024 PNG 与可编辑 SVG。图形为 HomePad 原创变形，正式 VILHIL Logo 与旧稿保留；用户仅选择深化方向，本轮未替换 AppIcon、修改工程或安装。系统最终遮罩、特殊外观与真机色彩尚未验收。</p></section></main></html>'''
(ROOT/'index.html').write_text(html)
print(json.dumps({'output':str(ROOT),'metrics':metrics},ensure_ascii=False))
