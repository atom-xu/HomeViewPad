#!/usr/bin/env python3
"""Original HomePad symbol exploration; not an official VILHIL logo revision."""
from pathlib import Path
import hashlib
import json
import math
import shutil

ROOT=Path(__file__).resolve().parent
SOURCE=ROOT.parent/'2026-10-vilhil/source/vilhil-mark-original.svg'
(ROOT/'source').mkdir(exist_ok=True)
shutil.copyfile(SOURCE,ROOT/'source/vilhil-original.svg')
ORIGINAL='''<path d="M98.953 0h40.246L39.848 208.801H0L98.953 0Z"/><path d="M179.445 0 278.398 208.801h-39.843L139.199 0h40.246Z"/><path d="M119.352 139.199h39.695v69.602h-39.695z"/>'''

VARIANTS=[
 dict(id='01-nook',letter='A',name='小憩',en='Nook',tag='开放的家',recommended=False,
      description='把硬朗的屋脊打开，留一盏圆润的小灯。',
      evolution='斜面 → 连续弯折的空间边界；中心节点 → 移到入口的小灯。',
      change='原标的对称尖角变成有开口的柔和围合。节点离开中轴，让“家”更有生活感。',
      color='#E77B76',
      defs='''<linearGradient id="body" x1=".1" y1="0" x2=".8" y2="1"><stop stop-color="#FFB27E"/><stop offset=".55" stop-color="#F3917B"/><stop offset="1" stop-color="#E66D7B"/></linearGradient><linearGradient id="core" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#FFC182"/><stop offset="1" stop-color="#F49870"/></linearGradient>''',
      symbol='''<path data-part="open-shelter" d="M426 738 H342 C298 738 270 710 270 666 V496 C270 468 282 442 304 423 L480 279 Q512 253 544 279 L720 423 C742 442 754 468 754 496 V590" fill="none" stroke="url(#body)" stroke-width="94" stroke-linecap="round" stroke-linejoin="round"/><rect data-part="entry-light" x="614" y="662" width="124" height="124" rx="42" fill="url(#core)"/>''',
      expected_components=2),
 dict(id='02-gather',letter='B',name='相连',en='Gather',tag='柔和的聚合',recommended=False,
      description='两条弧线，把设备与日常轻轻连在一起。',
      evolution='两条斜面 → 两条弧形连接；独立节点 → 接住它们的共同核心。',
      change='从“屋顶”转成三个不等角色的圆润节点。没有五向放射，也不使用空心圆组。',
      color='#7588E4',
      defs='''<linearGradient id="link" x1="0" y1="0" x2=".6" y2="1"><stop stop-color="#BCC9F7"/><stop offset="1" stop-color="#8B9CEB"/></linearGradient><linearGradient id="body" x1="0" y1="0" x2=".6" y2="1"><stop stop-color="#A0B1F6"/><stop offset="1" stop-color="#6B80DE"/></linearGradient><linearGradient id="core" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#F9C58C"/><stop offset="1" stop-color="#EDA280"/></linearGradient>''',
      symbol='''<g data-part="curved-links" fill="none" stroke="url(#link)" stroke-width="76" stroke-linecap="round"><path d="M330 396 C350 480 430 496 512 634"/><path d="M694 396 C674 480 594 496 512 634"/></g><rect data-part="left-node" x="250" y="286" width="160" height="160" rx="62" fill="url(#body)"/><rect data-part="right-node" x="614" y="286" width="160" height="160" rx="62" fill="url(#body)"/><rect data-part="shared-core" x="424" y="584" width="176" height="176" rx="62" fill="url(#core)"/>''',
      expected_components=1),
 dict(id='03-dwell',letter='C',name='家窗',en='Dwell',tag='拼合的空间',recommended=True,
      description='三块柔软的小窗，拼出 HomePad 的家。',
      evolution='两条斜面 → 屋脊的斜切边；中心矩形 → 一块亮起的小面板。',
      change='把原标拆开、扩展成三个不等尺寸的窗格。留白成为连接缝，外缘才显出房屋。',
      color='#32AA94',
      defs='''<linearGradient id="body" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#7BD7BB"/><stop offset=".55" stop-color="#48BEA6"/><stop offset="1" stop-color="#2AA68F"/></linearGradient><linearGradient id="roof" x1="0" y1="0" x2=".8" y2="1"><stop stop-color="#A5E5C4"/><stop offset="1" stop-color="#67CFA8"/></linearGradient><linearGradient id="core" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#F7D79A"/><stop offset="1" stop-color="#ECC17A"/></linearGradient>''',
      symbol='''<path data-part="living-pane" d="M256 480 C256 458 266 442 282 428 L456 286 Q480 267 480 298 V708 Q480 752 436 752 H304 Q256 752 256 704 Z" fill="url(#body)"/><path data-part="roof-pane" d="M544 298 Q544 267 568 286 L742 428 Q768 448 768 480 V500 Q768 528 740 528 H572 Q544 528 544 500 Z" fill="url(#roof)"/><rect data-part="lit-pane" x="544" y="568" width="224" height="184" rx="44" fill="url(#core)"/>''',
      expected_components=3),
]

for v in VARIANTS:
 d=ROOT/v['id'];d.mkdir(exist_ok=True)
 common=f'''<linearGradient id="canvas" x1=".1" y1="0" x2=".8" y2="1"><stop stop-color="#FFFFFF"/><stop offset=".65" stop-color="#FAFBFA"/><stop offset="1" stop-color="#EFF2F1"/></linearGradient>{v['defs']}<filter id="soft" x="-20%" y="-20%" width="140%" height="145%" color-interpolation-filters="sRGB"><feDropShadow dx="0" dy="9" stdDeviation="10" flood-color="{v['color']}" flood-opacity=".11"/></filter>'''
 title=f'HomePad / {v["en"]} — original app symbol exploration'
 for mono in [False,True]:
  symbol=v['symbol']
  if mono:
   import re
   symbol=re.sub(r'url\(#[^)]+\)','#34444A',symbol)
  name='symbol-monochrome.svg' if mono else 'icon.svg'
  bg='' if mono else '<rect width="1024" height="1024" fill="url(#canvas)"/>'
  defs='' if mono else common
  fx='' if mono else ' filter="url(#soft)"'
  svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024" role="img" aria-labelledby="title desc"><title id="title">{title}</title><desc id="desc">New HomePad symbol derived from VILHIL geometric ideas with user authorization. Not the formal VILHIL logo or an Apple/Samsung icon. Square opaque app master; masking is preview only.</desc><defs>{defs}</defs>{bg}<g id="homepad-symbol"{fx}>{symbol}</g></svg>'''
  (d/name).write_text(svg)

manifest={
 'date':'2026-10-16','round':2,'identity':'HomePad original app symbol studies; derived work, not formal VILHIL marks',
 'source_svg':'source/vilhil-original.svg','source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
 'references':[{'name':'Apple Home official app listing','url':'https://apps.apple.com/us/app/home/id1110145103','observed':'Layered orange house with chimney. Borrow home/space semantics only.'},{'name':'Samsung SmartThings official app listing','url':'https://apps.apple.com/us/app/smartthings/id1222822904','observed':'Five outer hollow circles and a center ring. Borrow connectivity semantics only.'},{'name':'Apple HomeKit visual guidelines','url':'https://developer.apple.com/design/human-interface-guidelines/homekit'}],
 'variants':[{k:v[k] for k in ['id','letter','name','en','tag','recommended','description','evolution','change','expected_components']} for v in VARIANTS],
 'recommended':'03-dwell','master_sizes':[1024,120,60],
 'integration':'Design assets only; no AppIcon, project, app behavior, install, commit, push or publish.',
 'preview_mask':'Superellipse 4.6, illustrative; final system treatment untested.'
}
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')

points=[]
for i in range(256):
 a=math.tau*i/256
 points.append(f'{.5+.5*math.copysign(abs(math.cos(a))**(2/4.6),math.cos(a)):.6f},{.5+.5*math.copysign(abs(math.sin(a))**(2/4.6),math.sin(a)):.6f}')

def icon(v,size):
 asset=size if size in [120,60] else 1024
 return f'<div class="icon-wrap" style="width:{size}px;height:{size}px"><img class="masked" src="{v["id"]}/icon-{asset}.png" alt="HomePad {v["name"]}"></div>'

cards=''.join(f'''<article class="concept"><div class="label"><span>{v['letter']} / {v['en'].upper()}</span>{'<em>推荐继续深化</em>' if v['recommended'] else ''}</div><div class="hero-icon">{icon(v,288)}</div><h2>{v['name']}<span>{v['tag']}</span></h2><p>{v['description']}</p><div class="mono"><img src="{v['id']}/symbol-monochrome.svg" alt="{v['name']}同色轮廓"><span>同色轮廓<br><b>{v['tag']}</b></span><div class="mini">{icon(v,60)}</div></div></article>''' for v in VARIANTS)
backgrounds=''.join(f'''<div class="wallpaper {theme}"><div class="wall-label">{theme.upper()} / {v['letter']} · {v['name']}</div><div class="pair"><div>{icon(v,120)}<b>HomePad</b><small>120 px</small></div><div>{icon(v,60)}<b>HomePad</b><small>60 px</small></div></div></div>''' for theme in ['light','dark'] for v in VARIANTS)
evolutions=''.join(f'''<article class="evolution"><div class="evolution-head"><b>{v['letter']} · {v['name']}</b><span>{v['tag']}</span></div><div class="journey"><div class="original"><svg viewBox="0 0 278.398 208.801">{ORIGINAL}</svg><small>VILHIL 正式原标</small></div><span class="arrow">→</span><div class="derived"><img src="{v['id']}/symbol-monochrome.svg" alt="新符号"><small>HomePad 原创变形</small></div></div><p>{v['evolution']}</p><small class="explain">{v['change']}</small></article>''' for v in VARIANTS)
links=''.join(f'''<article><h3>{v['letter']} · {v['name']}</h3><a href="{v['id']}/icon-1024.png">1024 PNG</a><a href="{v['id']}/icon.svg">可编辑 SVG</a><a href="{v['id']}/icon-120.png">120 PNG</a><a href="{v['id']}/icon-60.png">60 PNG</a></article>''' for v in VARIANTS)
html=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>HomePad · 新的形状</title><style>
*{{box-sizing:border-box}}:root{{color-scheme:light}}body{{margin:0;background:#ecefed;color:#27362f;font:16px/1.5 -apple-system,BlinkMacSystemFont,"Helvetica Neue","PingFang SC",sans-serif;-webkit-font-smoothing:antialiased}}.board{{width:1600px;max-width:100%;margin:0 auto;padding:51px 68px 42px;background:#f4f6f3}}.eyebrow{{display:flex;justify-content:space-between;color:#7a887e;font-size:11px;font-weight:600;letter-spacing:2px}}h1{{font-size:60px;line-height:1.2;letter-spacing:-2px;margin:22px 0 13px;font-weight:550}}.lede{{color:#819087;font-size:18px;margin:0}}.concepts{{display:grid;grid-template-columns:repeat(3,1fr);gap:22px;margin:38px 0 25px}}.concept{{border-radius:28px;background:#fff;padding:25px 27px 21px;border:1px solid #e4e9e2}}.label{{display:flex;justify-content:space-between;align-items:center;color:#839087;font-size:11px;font-weight:550;letter-spacing:1.8px;min-height:26px}}em{{font-style:normal;font-size:10px;background:#eaf4e9;color:#5e8a69;border-radius:20px;padding:5px 12px;letter-spacing:.7px}}.hero-icon{{height:333px;display:flex;justify-content:center;align-items:center}}.icon-wrap{{display:inline-block;flex-shrink:0;filter:drop-shadow(0 8px 14px #283e2c0b)}}.icon-wrap img{{width:100%;height:100%;display:block}}.masked{{clip-path:url(#mask)}}h2{{font-size:27px;font-weight:550;margin:3px 0 9px;letter-spacing:.5px}}h2 span{{font-size:12px;font-weight:400;letter-spacing:1px;color:#89968c;margin-left:17px}}.concept p{{font-size:14px;color:#7d8b82;white-space:nowrap;margin:0 0 24px}}.mono{{border-top:1px solid #edf0ea;padding-top:17px;display:flex;align-items:center;gap:10px;color:#a0a99f;font-size:10px;letter-spacing:.5px}}.mono>img{{width:58px;height:58px}}.mono b{{color:#819081;font-weight:400}}.mini{{margin-left:auto}}.foot{{border-top:1px solid #dce3da;padding-top:22px;display:flex;justify-content:space-between;gap:24px;color:#89958a;font-size:12px}}.section-title{{font-size:34px;font-weight:550;letter-spacing:-.6px;margin:16px 0 11px}}.backgrounds{{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;margin:32px 0 25px}}.wallpaper{{height:295px;position:relative;border-radius:22px;overflow:hidden}}.light{{background:radial-gradient(ellipse at 0 0,#fff4e2,transparent 65%),radial-gradient(ellipse at 100% 100%,#b7cdbd,transparent 80%),#e2e8df;color:#405747}}.dark{{background:radial-gradient(ellipse at 100% 0,#3b5759,transparent 70%),radial-gradient(ellipse at 0 100%,#4f5556,transparent 85%),#192a2c;color:#fff}}.wall-label{{position:absolute;left:22px;top:18px;font-size:10px;letter-spacing:1.8px;opacity:.55}}.pair{{display:flex;justify-content:center;align-items:center;gap:64px;height:100%;padding-top:24px}}.pair>div{{display:flex;flex-direction:column;align-items:center}}.pair b{{font-size:12px;font-weight:500;margin-top:10px}}.pair small{{font-size:10px;opacity:.45;letter-spacing:1px;margin-top:8px}}.evolutions{{display:grid;grid-template-columns:repeat(3,1fr);gap:22px;margin:34px 0 29px}}.evolution{{background:#fff;border:1px solid #e4e9e2;border-radius:23px;padding:24px 25px 29px}}.evolution-head{{display:flex;justify-content:space-between;align-items:center}}.evolution-head b{{font-weight:500;font-size:17px}}.evolution-head>span{{font-size:11px;letter-spacing:1px;color:#94a08e}}.journey{{display:flex;align-items:center;justify-content:center;gap:18px;height:214px}}.journey>div{{display:flex;align-items:center;flex-direction:column;justify-content:center}}.original svg{{width:99px;height:99px;fill:#697b6c}}.derived img{{width:155px;height:155px}}.original small{{margin-top:29px}}.derived small{{margin-top:0}}.journey small{{font-size:10px;color:#9ba695;letter-spacing:.6px}}.arrow{{font-size:24px;font-weight:200;color:#c4cec0;margin-bottom:26px}}.evolution p{{color:#5e7765;font-size:14px;line-height:1.9;margin:2px 0 16px;min-height:54px}}.explain{{display:block;color:#97a38e;font-size:12px;line-height:1.9}}.recommendation{{background:#eaf1e6;border-radius:20px;padding:23px 29px;display:flex;gap:26px;align-items:center;color:#74906f;margin:20px 0 30px}}.recommendation strong{{color:#4c6e53;font-size:17px;white-space:nowrap;font-weight:500}}.recommendation p{{font-size:13px;line-height:1.9;margin:0}}.downloads{{display:grid;grid-template-columns:repeat(3,1fr);gap:22px;margin-top:28px}}.downloads article{{border-top:1px solid #dce3da;padding-top:10px}}h3{{font-weight:500;font-size:16px}}a{{display:inline-block;font-size:12px;color:#6c8a72;margin:0 18px 12px 0;text-decoration:none;border-bottom:1px solid #b5c5b0}}.notes{{font-size:12px;color:#93a08c;line-height:1.9;margin-top:24px}}@media(max-width:1000px){{.board{{padding:32px 22px}}h1{{font-size:43px}}.concepts,.backgrounds,.evolutions,.downloads{{grid-template-columns:1fr}}.concepts,.backgrounds,.evolutions{{max-width:560px;margin:28px auto}}.concept p{{white-space:normal}}.foot,.recommendation{{flex-direction:column;align-items:flex-start}}}}
</style><svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs><clipPath id="mask" clipPathUnits="objectBoundingBox"><polygon points="{' '.join(points)}"/></clipPath></defs></svg><main>
<section class="board overview-board"><div class="eyebrow"><span>HOMEPAD / SHAPE EXPLORATION 02</span><span>16 OCT 2026 · ORIGINAL APP SYMBOLS</span></div><h1>让它更像你的家。</h1><p class="lede">从 VILHIL 的斜面与节点出发，长出三种更轻松的形状。</p><div class="concepts">{cards}</div><div class="foot"><span>结构探索：开放空间 / 连接聚合 / 模块窗口</span><span>下方同色轮廓与 60 px 图标，可直接比较形状。</span><span>HomePad 原创变形 · 非正式企业 Logo</span></div></section>
<section class="board background-board"><div class="eyebrow"><span>SMALL BUT CLEAR</span><span>120 PX + 60 PX / 1× PREVIEW</span></div><h2 class="section-title">小一点，也有自己的样子。</h2><p class="lede">使用实际导出的缩略图，检查轮廓、连接与窗格的留白。</p><div class="backgrounds">{backgrounds}</div><div class="foot"><span>深浅背景均为合成图，无私人照片。</span><span>圆角为桌面示意；原稿保持不透明正方形。</span><span>浏览器 100% 缩放可检查真实像素。</span></div></section>
<section class="board evolution-board"><div class="eyebrow"><span>FROM BRAND DNA TO A PERSONAL APP</span><span>RETAIN THE IDEA / CHANGE THE FORM</span></div><h2 class="section-title">保留来处，改变形状。</h2><p class="lede">保留斜面、负空间与核心节点；三种新构图都为 HomePad 单独绘制。</p><div class="evolutions">{evolutions}</div><div class="recommendation"><strong>推荐 C · 家窗</strong><p>它把“家”与“面板”融成一个轻盈轮廓，三个不等尺寸的窗格也更贴近 HomePad 的实际内容。颜色去掉以后，仍然是一个完整、独立的符号。</p></div><div class="foot"><span>参考 Home 的空间直觉、SmartThings 的连接语义。</span><span>不采用它们的具体轮廓、层叠房屋或五向圆环结构。</span><span>正式 VILHIL 原标另存，未作覆盖。</span></div><div class="downloads">{links}</div><p class="notes">本轮尚未替换 AppIcon、修改工程或应用功能。系统最终遮罩、特殊外观及真机色彩待选定后再验证。可编辑源文件、官方参考与检查结果见同目录 README.md、BRIEF.md 和 manifest.json。</p></section></main></html>'''
(ROOT/'index.html').write_text(html)
print(json.dumps({'output':str(ROOT),'variants':[v['id'] for v in VARIANTS],'recommended':'03-dwell'},ensure_ascii=False))
