#!/usr/bin/env python3
from pathlib import Path
import json,shutil

ROOT=Path(__file__).resolve().parent;OLD=ROOT.parent/'2026-10-dwell-revisited'
for name in ['source','concepts','review']:(ROOT/name).mkdir(exist_ok=True)
shutil.copyfile(OLD/'concepts/01-warm-window.svg',ROOT/'source/original-01.svg')
shutil.copyfile(OLD/'review/01-warm-window.png',ROOT/'source/original-01-1024.png')
HOUSE='M256 488 C256 466 268 446 288 430 L480 286 Q512 260 544 286 L736 430 C756 446 768 466 768 488 V700 Q768 752 716 752 H308 Q256 752 256 700 Z'
BASE=f'''<linearGradient id="canvas" x1=".1" y1="0" x2=".8" y2="1"><stop stop-color="#FFFFFF"/><stop offset=".65" stop-color="#FAFBFA"/><stop offset="1" stop-color="#EFF2F1"/></linearGradient><path id="house" d="{HOUSE}"/><clipPath id="clip-house"><path d="{HOUSE}"/></clipPath><mask id="window"><rect width="1024" height="1024" fill="white"/><rect x="428" y="478" width="244" height="218" rx="54" fill="black"/></mask>'''

IDEAS=[
 dict(id='01-glass',label='01',name='通透玻璃',tag='光在里面',concept='透光的家形，暖窗藏在一层玻璃后面。',defs='''
<linearGradient id="glass" x1=".1" y1="0" x2=".85" y2="1"><stop stop-color="#C5EBDE" stop-opacity=".68"/><stop offset=".42" stop-color="#7FD1B8" stop-opacity=".48"/><stop offset="1" stop-color="#52AD94" stop-opacity=".72"/></linearGradient>
<linearGradient id="rim" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#FFFFFF" stop-opacity=".94"/><stop offset=".4" stop-color="#FFFFFF" stop-opacity=".25"/><stop offset="1" stop-color="#389A7C" stop-opacity=".3"/></linearGradient>
<linearGradient id="sheen" x1="0" y1="0" x2=".9" y2="1"><stop stop-color="#FFFFFF" stop-opacity=".16"/><stop offset=".38" stop-color="#FFFFFF" stop-opacity=".02"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>
<linearGradient id="amber" x1=".1" y1="0" x2=".8" y2="1"><stop stop-color="#F5D99F"/><stop offset=".65" stop-color="#E8BD77"/><stop offset="1" stop-color="#DDB06C"/></linearGradient>
<linearGradient id="lens" x1="0" y1="0" x2=".8" y2="1"><stop stop-color="#FFFFFF" stop-opacity=".32"/><stop offset=".56" stop-color="#E5F5EE" stop-opacity=".08"/><stop offset="1" stop-color="#A3D9C6" stop-opacity=".14"/></linearGradient>
<filter id="glass-shadow" x="-25%" y="-25%" width="150%" height="155%" color-interpolation-filters="sRGB"><feDropShadow dx="0" dy="9" stdDeviation="11" flood-color="#36755D" flood-opacity=".1"/></filter>
<filter id="amber-soft" x="-25%" y="-25%" width="150%" height="150%"><feDropShadow dx="0" dy="4" stdDeviation="7" flood-color="#AA803C" flood-opacity=".13"/></filter>
''',art=f'''
<g filter="url(#glass-shadow)"><path d="{HOUSE}" fill="url(#glass)" mask="url(#window)"/><path d="{HOUSE}" fill="url(#sheen)" mask="url(#window)"/><path d="{HOUSE}" fill="none" stroke="url(#rim)" stroke-width="3"/></g>
<rect x="452" y="504" width="196" height="170" rx="41" fill="url(#amber)" filter="url(#amber-soft)"/>
<rect x="428" y="478" width="244" height="218" rx="54" fill="url(#lens)" stroke="url(#rim)" stroke-width="3"/>
'''),
 dict(id='02-relief',label='02',name='柔和浮雕',tag='触感在表面',concept='哑光的家形轻轻浮起，暖窗嵌在浅凹口里。',defs='''
<linearGradient id="sage" x1=".15" y1="0" x2=".85" y2="1"><stop stop-color="#D3E3D5"/><stop offset=".6" stop-color="#BDD5C4"/><stop offset="1" stop-color="#ABC7B5"/></linearGradient>
<linearGradient id="pocket" x1="0" y1="0" x2=".65" y2="1"><stop stop-color="#9FBCA9"/><stop offset=".22" stop-color="#BED2C1"/><stop offset="1" stop-color="#D8E5D6"/></linearGradient>
<linearGradient id="ceramic" x1="0" y1="0" x2=".65" y2="1"><stop stop-color="#EFD29E"/><stop offset="1" stop-color="#E6C084"/></linearGradient>
<filter id="relief" x="-25%" y="-25%" width="150%" height="155%" color-interpolation-filters="sRGB"><feDropShadow dx="6" dy="9" stdDeviation="8" flood-color="#496B52" flood-opacity=".16"/><feDropShadow dx="-4" dy="-5" stdDeviation="6" flood-color="#FFFFFF" flood-opacity=".8"/></filter>
<filter id="recess" x="-15%" y="-15%" width="130%" height="130%" color-interpolation-filters="sRGB"><feGaussianBlur in="SourceAlpha" stdDeviation="3" result="b"/><feOffset in="b" dx="2" dy="4" result="o"/><feComposite in="o" in2="SourceAlpha" operator="arithmetic" k2="-1" k3="1" result="i"/><feFlood flood-color="#45634D" flood-opacity=".21"/><feComposite in2="i" operator="in"/><feComposite in2="SourceGraphic" operator="over"/></filter>
''',art=f'''
<path d="{HOUSE}" fill="url(#sage)" filter="url(#relief)"/>
<rect x="428" y="478" width="244" height="218" rx="54" fill="url(#pocket)" filter="url(#recess)"/>
<rect x="459" y="509" width="182" height="156" rx="36" fill="url(#ceramic)"/>
'''),
 dict(id='03-sheets',label='03',name='轻薄叠片',tag='空间在层间',concept='两层薄薄的家形，让一片暖窗向前一点。',defs='''
<linearGradient id="rear" x1=".1" y1="0" x2=".8" y2="1"><stop stop-color="#B9E6D3"/><stop offset="1" stop-color="#8ACFB3"/></linearGradient>
<linearGradient id="front" x1=".1" y1="0" x2=".6" y2="1"><stop stop-color="#6BCBAD"/><stop offset="1" stop-color="#3EAF91"/></linearGradient>
<linearGradient id="insert" x1="0" y1="0" x2=".8" y2="1"><stop stop-color="#F1D29A"/><stop offset="1" stop-color="#E6BC79"/></linearGradient>
<filter id="sheet-shadow" x="-20%" y="-20%" width="145%" height="150%" color-interpolation-filters="sRGB"><feDropShadow dx="0" dy="6" stdDeviation="6" flood-color="#2D6A50" flood-opacity=".13"/></filter>
<filter id="insert-shadow" x="-20%" y="-20%" width="145%" height="150%" color-interpolation-filters="sRGB"><feDropShadow dx="0" dy="4" stdDeviation="4" flood-color="#967344" flood-opacity=".13"/></filter>
''',art=f'''
<path d="{HOUSE}" transform="translate(22 -22)" fill="url(#rear)"/>
<g transform="translate(-10 10)" filter="url(#sheet-shadow)"><path d="{HOUSE}" fill="url(#front)" mask="url(#window)"/></g>
<rect x="464" y="528" width="202" height="174" rx="38" fill="url(#insert)" filter="url(#insert-shadow)"/>
'''),
]

for idea in IDEAS:
 svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024" role="img" aria-labelledby="title desc"><title id="title">HomePad warm window / {idea['name']}</title><desc id="desc">Material study based provisionally on numbered 01 warm window. Full house and warm window relationship retained; not final artwork or AppIcon integration.</desc><defs>{BASE}{idea['defs']}</defs><rect width="1024" height="1024" fill="url(#canvas)"/>{idea['art']}</svg>'''
 (ROOT/'concepts'/f'{idea["id"]}.svg').write_text(svg)

items=[dict(id='original',label='原 01',name='暖窗',tag='编号原稿',concept='完整家形与亮窗，作为这次的对照。',original=True)]+IDEAS
def file(v):return 'source/original-01.svg' if v.get('original') else f'concepts/{v["id"]}.svg'
def icon(v,size):return f'<div class="app-icon" style="width:{size}px;height:{size}px"><img class="masked" src="{file(v)}" alt="{v["name"]}"></div>'
cards=''.join(f'''<article class="card {'original' if v.get('original') else ''}"><div class="label"><span>{v['label']} / {v['name']}</span><b>{v['tag']}</b></div><div class="hero">{icon(v,296)}</div><h2>{v['name']}</h2><p>{v['concept']}</p><div class="small"><span>60 px 实际大小</span>{icon(v,60)}</div></article>''' for v in items)
html=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>HomePad · 暖窗的形式</title><style>
*{{box-sizing:border-box}}:root{{color-scheme:light}}body{{margin:0;background:#f0f2ed;color:#334438;font:16px/1.5 -apple-system,BlinkMacSystemFont,"Helvetica Neue","PingFang SC",sans-serif;-webkit-font-smoothing:antialiased}}.board{{width:1680px;max-width:100%;margin:0 auto;padding:49px 62px 38px;background:#f5f6f1}}.eyebrow{{display:flex;justify-content:space-between;font-size:11px;font-weight:550;letter-spacing:2px;color:#94a28c}}h1{{font-size:54px;line-height:1.2;font-weight:550;letter-spacing:-1.7px;margin:24px 0 14px}}.intro{{font-size:18px;color:#8d9e81;margin:0}}.cards{{display:grid;grid-template-columns:repeat(4,1fr);gap:20px;margin:37px 0 28px}}.card{{background:#fff;border:1px solid #e3e8dc;border-radius:26px;padding:23px 23px 22px}}.original{{background:#fbfcf7;border-style:dashed}}.label{{display:flex;align-items:center;justify-content:space-between;gap:10px;color:#859a78;font-size:10px;letter-spacing:.7px;min-height:24px}}.label b{{font-size:9px;color:#b0bca5;font-weight:400;white-space:nowrap}}.hero{{height:343px;display:flex;align-items:center;justify-content:center}}.app-icon{{display:inline-block;flex-shrink:0;filter:drop-shadow(0 7px 13px #33482c0c)}}.app-icon>img{{display:block;width:100%;height:100%}}.masked{{clip-path:url(#mask)}}h2{{font-size:26px;font-weight:550;margin:0 0 10px;letter-spacing:.5px}}.card p{{font-size:13px;color:#8a9b7f;line-height:1.9;margin:0 0 22px;min-height:50px}}.small{{display:flex;align-items:center;justify-content:space-between;gap:24px;border-top:1px solid #eaf0e3;padding-top:18px}}.small>span{{font-size:10px;color:#a1b193;letter-spacing:.6px}}.footer{{display:flex;justify-content:space-between;gap:30px;font-size:12px;color:#9aab8d;line-height:1.9;border-top:1px solid #dfe6d7;padding-top:23px}}@media(max-width:1100px){{.board{{padding:30px 22px}}h1{{font-size:40px}}.cards{{grid-template-columns:repeat(2,1fr)}}.footer{{flex-direction:column}}}}@media(max-width:650px){{.cards{{grid-template-columns:1fr}}}}
</style><svg width="0" height="0" style="position:absolute"><defs><clipPath id="mask" clipPathUnits="objectBoundingBox"><path d="M.22 0H.78C.95 0 1 .05 1 .22V.78C1 .95 .95 1 .78 1H.22C.05 1 0 .95 0 .78V.22C0 .05 .05 0 .22 0Z"/></clipPath></defs></svg><main class="board"><div class="eyebrow"><span>HOMEPAD / WARM WINDOW MATERIAL STUDIES</span><span>06 · FORM & TOUCH</span></div><h1>同一扇暖窗，换一种触感。</h1><p class="intro">先按有编号的 01「暖窗」延展，比较玻璃、浮雕与薄片的不同构造。</p><div class="cards">{cards}</div><div class="footer"><span>原稿保留并列；家形和亮窗的识别关系贯穿三版。</span><span>材质与构造探索，配色和形式尚未最终确认。</span><span>大图与实际 60 px 对比 · AppIcon 保持原样</span></div></main></html>'''
(ROOT/'index.html').write_text(html)
(ROOT/'concepts.json').write_text(json.dumps([{k:v[k] for k in ['id','label','name','tag','concept']} for v in IDEAS],ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'output':str(ROOT),'forms':3,'reference':'numbered 01 Warm window'},ensure_ascii=False))
