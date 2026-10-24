#!/usr/bin/env python3
from pathlib import Path
import json,shutil

ROOT=Path(__file__).resolve().parent;OLD=ROOT.parent/'2026-10-homepad-v2/03-dwell'
for name in ['source','concepts','review']:(ROOT/name).mkdir(exist_ok=True)
shutil.copyfile(OLD/'icon.svg',ROOT/'source/original-dwell.svg')
shutil.copyfile(OLD/'icon-1024.png',ROOT/'source/original-dwell-1024.png')
DEFS='''<linearGradient id="canvas" x1=".1" y1="0" x2=".8" y2="1"><stop stop-color="#FFFFFF"/><stop offset=".65" stop-color="#FAFBFA"/><stop offset="1" stop-color="#EFF2F1"/></linearGradient><linearGradient id="body" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#7BD7BB"/><stop offset=".55" stop-color="#48BEA6"/><stop offset="1" stop-color="#2AA68F"/></linearGradient><linearGradient id="roof" x1="0" y1="0" x2=".8" y2="1"><stop stop-color="#A5E5C4"/><stop offset="1" stop-color="#67CFA8"/></linearGradient><linearGradient id="core" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#F7D79A"/><stop offset="1" stop-color="#ECC17A"/></linearGradient><filter id="soft" x="-20%" y="-20%" width="140%" height="145%" color-interpolation-filters="sRGB"><feDropShadow dx="0" dy="9" stdDeviation="10" flood-color="#32AA94" flood-opacity=".11"/></filter>'''
IDEAS=[
 dict(id='A-diagonal',label='A',name='斜接',concept='让三块在斜向留白里相接，窗向中心展开。',relation='三块拼合，由 T 形分隔变为斜向交汇。',art='''
<path data-part="living-pane" d="M256 480 C256 458 266 442 282 428 L456 286 Q480 267 480 298 V472 Q480 490 474 508 L412 720 Q402 752 368 752 H304 Q256 752 256 704 Z" fill="url(#body)"/>
<path data-part="roof-pane" d="M544 298 Q544 267 568 286 L742 428 Q768 448 768 480 V516 Q768 548 736 540 L568 504 Q544 498 544 472 Z" fill="url(#roof)"/>
<path data-part="lit-pane" d="M522 550 L736 574 Q768 578 768 610 V708 Q768 752 724 752 H468 Q438 752 448 718 L492 572 Q500 544 522 550 Z" fill="url(#core)"/>
'''),
 dict(id='B-canopy',label='B',name='垂檐',concept='屋顶顺着右侧落下，围出一扇竖向亮窗。',relation='薄荷屋顶成为右侧空间，暖窗转入三块之间。',art='''
<path data-part="living-pane" d="M256 480 C256 458 266 442 282 428 L456 286 Q480 267 480 298 V708 Q480 752 436 752 H304 Q256 752 256 704 Z" fill="url(#body)"/>
<path data-part="roof-pane" d="M544 298 Q544 267 568 286 L742 428 Q768 448 768 480 V708 Q768 752 724 752 H716 Q704 752 704 740 V552 Q704 512 664 512 H580 Q544 512 544 476 Z" fill="url(#roof)"/>
<rect data-part="lit-pane" x="520" y="552" width="152" height="200" rx="39" fill="url(#core)"/>
'''),
 dict(id='C-wide-window',label='C',name='横窗',concept='把暖窗横向展开，轻轻跨过中间的分隔。',relation='左高块面让出下层空间，暖窗跨越原来的两列。',art='''
<path data-part="living-pane" d="M256 480 C256 458 266 442 282 428 L456 286 Q480 267 480 298 V508 Q480 544 444 544 H412 Q368 544 368 588 V708 Q368 752 324 752 H304 Q256 752 256 704 Z" fill="url(#body)"/>
<path data-part="roof-pane" d="M544 298 Q544 267 568 286 L742 428 Q768 448 768 480 V500 Q768 528 740 528 H572 Q544 528 544 500 Z" fill="url(#roof)"/>
<rect data-part="lit-pane" x="408" y="568" width="360" height="184" rx="44" fill="url(#core)"/>
'''),
]
for v in IDEAS:
 svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024" role="img" aria-labelledby="title desc"><title id="title">HomePad · {v['label']} {v['name']}</title><desc id="desc">Original three-part Dwell family composition study. {v['relation']} Not based on warm-window shell artwork. Design exploration only.</desc><defs>{DEFS}</defs><rect width="1024" height="1024" fill="url(#canvas)"/><g id="homepad-symbol" filter="url(#soft)">{v['art']}</g></svg>'''
 (ROOT/'concepts'/f'{v["id"]}.svg').write_text(svg)

items=[dict(id='original',label='基准',name='原版家窗',concept='左高青绿、右上薄荷屋顶、右下暖黄窗块。',relation='原始三块家形，保持原样，不编数字。',original=True)]+IDEAS
def filename(v):return 'source/original-dwell.svg' if v.get('original') else f'concepts/{v["id"]}.svg'
def icon(v,size):return f'<div class="app-icon" style="width:{size}px;height:{size}px"><img class="masked" src="{filename(v)}" alt="{v["name"]}"></div>'
cards=''.join(f'''<article class="card {'reference' if v.get('original') else ''}"><div class="tag"><span>{v['label']}</span><b>{'原始基准' if v.get('original') else '构形探索'}</b></div><div class="hero">{icon(v,296)}</div><h2>{v['name']}</h2><p>{v['concept']}</p><small>{v['relation']}</small><div class="tiny"><span>60 px 实际大小</span>{icon(v,60)}</div></article>''' for v in items)
html=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>HomePad · 原版家窗的三种构形</title><style>
*{{box-sizing:border-box}}:root{{color-scheme:light}}body{{margin:0;background:#f0f3ed;color:#314538;font:16px/1.5 -apple-system,BlinkMacSystemFont,"Helvetica Neue","PingFang SC",sans-serif;-webkit-font-smoothing:antialiased}}.board{{width:1680px;max-width:100%;margin:0 auto;padding:49px 62px 38px;background:#f4f6f0}}.eyebrow{{display:flex;justify-content:space-between;color:#8ea185;letter-spacing:2px;font-size:11px;font-weight:550}}h1{{font-size:54px;font-weight:550;line-height:1.2;letter-spacing:-1.7px;margin:24px 0 14px}}.intro{{font-size:18px;color:#8a9d7f;margin:0}}.cards{{display:grid;grid-template-columns:repeat(4,1fr);gap:20px;margin:37px 0 28px}}.card{{padding:22px 23px;background:#fff;border:1px solid #e1e8d9;border-radius:25px}}.reference{{background:#fafcf6;border-style:dashed}}.tag{{display:flex;justify-content:space-between;align-items:center;min-height:24px;font-size:18px;font-weight:450;color:#7f9b72;letter-spacing:1px}}.tag b{{font-size:10px;font-weight:400;color:#adbda0;letter-spacing:.8px}}.hero{{height:342px;display:flex;align-items:center;justify-content:center}}.app-icon{{display:inline-block;flex-shrink:0;filter:drop-shadow(0 7px 13px #354c2c0c)}}.app-icon img{{display:block;width:100%;height:100%}}.masked{{clip-path:url(#mask)}}h2{{font-size:27px;font-weight:550;letter-spacing:.5px;margin:0 0 10px}}.card p{{font-size:13px;color:#809674;line-height:1.9;min-height:50px;margin:0 0 15px}}.card>small{{display:block;font-size:10px;color:#a6b89a;line-height:1.9;min-height:38px}}.tiny{{display:flex;justify-content:space-between;align-items:center;gap:24px;border-top:1px solid #e9f0e1;padding-top:18px;margin-top:18px}}.tiny>span{{font-size:10px;letter-spacing:.6px;color:#a1b492}}.footer{{display:flex;justify-content:space-between;gap:26px;font-size:12px;line-height:1.9;color:#98ad89;border-top:1px solid #dce6d3;padding-top:23px}}@media(max-width:1100px){{.board{{padding:30px 22px}}h1{{font-size:39px}}.cards{{grid-template-columns:repeat(2,1fr)}}.footer{{flex-direction:column}}}}@media(max-width:650px){{.cards{{grid-template-columns:1fr}}}}
</style><svg width="0" height="0" style="position:absolute"><defs><clipPath id="mask" clipPathUnits="objectBoundingBox"><path d="M.22 0H.78C.95 0 1 .05 1 .22V.78C1 .95 .95 1 .78 1H.22C.05 1 0 .95 0 .78V.22C0 .05 .05 0 .22 0Z"/></clipPath></defs></svg><main class="board"><div class="eyebrow"><span>HOMEPAD / ORIGINAL DWELL COMPOSITIONS</span><span>07 · THREE PARTS, NEW RELATIONSHIPS</span></div><h1>回到原版家窗，让三块重新相遇。</h1><p class="intro">原版保留在左侧；A／B／C 比较块面、空隙、窗与屋顶的新关系。</p><div class="cards">{cards}</div><div class="footer"><span>基准明确标为「原版家窗」，不编数字；仅新稿使用 A／B／C。</span><span>配色与光感保持接近原版，先看构形。</span><span>创意探索，尚未定稿 · AppIcon 保持原样</span></div></main></html>'''
(ROOT/'index.html').write_text(html)
(ROOT/'concepts.json').write_text(json.dumps([{k:v[k] for k in ['id','label','name','concept','relation']} for v in IDEAS],ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'output':str(ROOT),'baseline':'Original three-part Dwell, unnumbered','new_forms':['A','B','C']},ensure_ascii=False))
