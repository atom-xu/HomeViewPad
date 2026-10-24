#!/usr/bin/env python3
"""Build an offline icon study from the unmodified, approved VILHIL paths."""
from pathlib import Path
import hashlib
import json
import math
import shutil
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
SOURCE = Path('/Users/atom/Desktop/软件项目/entroWEB/public/vilhil-mark-vi-20261013.svg')
VI = Path('/Users/atom/Desktop/vilhil/品牌/VilHil 视觉识别系统_8.16.pdf')
OLD = ROOT.parents[2] / 'HomePad/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
SOURCE_DIR = ROOT / 'source'
SOURCE_DIR.mkdir(exist_ok=True)
if SOURCE.exists():
    shutil.copyfile(SOURCE, SOURCE_DIR / 'vilhil-mark-original.svg')
source = SOURCE_DIR / 'vilhil-mark-original.svg'
tree = ET.parse(source)
paths = [node.attrib['d'] for node in tree.getroot() if node.tag.endswith('path')]
assert len(paths) == 3
mark = '\n'.join(f'<path d="{d}"/>' for d in paths)
width = 600
scale = width / 278.398
height = 208.801 * scale
transform = f'translate(212 266) scale({scale:.12f})'

SCHEMES = [
    dict(id='01-graphite', letter='A', name='深石墨', en='Graphite', recommended=True,
         description='石墨底色，微光白标。白天清楚，夜里安静。',
         bg='''<linearGradient id="base" x1="0" y1="0" x2="0.65" y2="1" gradientUnits="objectBoundingBox"><stop stop-color="#30343B"/><stop offset=".52" stop-color="#1C2027"/><stop offset="1" stop-color="#11151B"/></linearGradient>
<radialGradient id="light" cx=".24" cy="-.08" r=".94"><stop stop-color="#9299A5" stop-opacity=".16"/><stop offset=".7" stop-color="#A0A5B0" stop-opacity="0"/></radialGradient>
<radialGradient id="low" cx=".85" cy="1.14" r=".78"><stop stop-color="#03070D" stop-opacity=".4"/><stop offset="1" stop-color="#03070D" stop-opacity="0"/></radialGradient>
<linearGradient id="ink" x1="0" y1="0" x2=".25" y2="1"><stop stop-color="#FFFFFF"/><stop offset=".6" stop-color="#F7F8FA"/><stop offset="1" stop-color="#E6E9EF"/></linearGradient>''',
         shadow='#000000', shadow_opacity='.24', shadow_y='9', shadow_blur='10'),
    dict(id='02-porcelain', letter='B', name='瓷白', en='Porcelain', recommended=False,
         description='柔和瓷白，深色图案。最贴近品牌黑白本色。',
         bg='''<linearGradient id="base" x1=".15" y1="0" x2=".8" y2="1"><stop stop-color="#FCFCFA"/><stop offset=".5" stop-color="#F3F3F1"/><stop offset="1" stop-color="#E1E4E8"/></linearGradient>
<radialGradient id="light" cx=".15" cy="0" r="1"><stop stop-color="#FFFFFF" stop-opacity=".9"/><stop offset=".85" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>
<radialGradient id="low" cx=".9" cy="1.2" r=".8"><stop stop-color="#B9C0CC" stop-opacity=".12"/><stop offset="1" stop-color="#B9C0CC" stop-opacity="0"/></radialGradient>
<linearGradient id="ink" x1=".1" y1="0" x2=".8" y2="1"><stop stop-color="#343A42"/><stop offset=".45" stop-color="#23282F"/><stop offset="1" stop-color="#14191F"/></linearGradient>''',
         shadow='#46505C', shadow_opacity='.13', shadow_y='6', shadow_blur='7'),
    dict(id='03-daylight', letter='C', name='晨光', en='Daylight', recommended=False,
         description='取自 VI 的浅黄，让家的温度留在主屏。',
         bg='''<linearGradient id="base" x1=".1" y1="0" x2=".8" y2="1"><stop stop-color="#FFF4BE"/><stop offset=".5" stop-color="#FEEB8F"/><stop offset="1" stop-color="#EDD384"/></linearGradient>
<radialGradient id="light" cx=".2" cy="-.05" r=".92"><stop stop-color="#FFFDF1" stop-opacity=".32"/><stop offset=".85" stop-color="#FFFDF1" stop-opacity="0"/></radialGradient>
<radialGradient id="low" cx=".9" cy="1.12" r=".75"><stop stop-color="#B58B3F" stop-opacity=".08"/><stop offset="1" stop-color="#B58B3F" stop-opacity="0"/></radialGradient>
<linearGradient id="ink" x1="0" y1="0" x2=".6" y2="1"><stop stop-color="#34342D"/><stop offset=".5" stop-color="#22231F"/><stop offset="1" stop-color="#151813"/></linearGradient>''',
         shadow='#735E30', shadow_opacity='.14', shadow_y='6', shadow_blur='7'),
]

for s in SCHEMES:
    dest = ROOT / s['id']
    dest.mkdir(exist_ok=True)
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1024" height="1024" viewBox="0 0 1024 1024" role="img" aria-labelledby="title desc">
<title id="title">HomePad — VILHIL / {s['en']}</title>
<desc id="desc">Formal VILHIL pictorial mark. Original paths and aspect ratio preserved. Opaque, square icon master; system mask is applied only in preview.</desc>
<defs>
{s['bg']}
<g id="brand-mark">{mark}</g>
<filter id="relief" x="-20%" y="-20%" width="140%" height="150%" color-interpolation-filters="sRGB"><feDropShadow dx="0" dy="{s['shadow_y']}" stdDeviation="{s['shadow_blur']}" flood-color="{s['shadow']}" flood-opacity="{s['shadow_opacity']}"/></filter>
</defs>
<rect width="1024" height="1024" fill="url(#base)"/>
<rect width="1024" height="1024" fill="url(#light)"/>
<rect width="1024" height="1024" fill="url(#low)"/>
<g filter="url(#relief)"><use xlink:href="#brand-mark" transform="{transform}" fill="url(#ink)"/></g>
</svg>
'''
    (dest / 'icon.svg').write_text(svg)

shutil.copyfile(OLD, SOURCE_DIR / 'current-homepad-icon.png')
manifest = {
    'date': '2026-10-16',
    'brand': 'VILHIL',
    'source_svg_original': str(SOURCE),
    'source_svg_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    'source_vi_original': str(VI),
    'source_vi_sha256': hashlib.sha256(VI.read_bytes()).hexdigest() if VI.exists() else None,
    'source_vi_pages': [15, 19, 24, 25],
    'source_viewbox': tree.getroot().attrib['viewBox'],
    'unmodified_path_data': paths,
    'layout': {'canvas': [1024, 1024], 'mark_translate': [212, 266], 'uniform_scale': scale,
               'mark_bounds': [212, 266, 212 + width, 266 + height],
               'clear_space': {'left': 212, 'right': 212, 'top': 266, 'bottom': 1024 - 266 - height}},
    'recommended': '01-graphite',
    'variants': [{k: s[k] for k in ['id', 'letter', 'name', 'en', 'description']} for s in SCHEMES],
    'preview_mask': 'superellipse n=4.6, illustration only; final system mask is not simulated exactly',
    'integration': 'Design assets only. No AppIcon binding, source, install, commit, push or publish.',
}
(ROOT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')

def tile(s, size, extra=''):
    asset_size = size if size in [60, 120] else 1024
    return f'<div class="icon-wrap {extra}" style="width:{size}px;height:{size}px"><img class="app-icon" src="{s["id"]}/icon-{asset_size}.png" width="{size}" height="{size}" alt="{s["name"]} HomePad 图标"></div>'

cards = ''.join(f'''<article class="concept">
    <div class="concept-head"><span>{s['letter']} / {s['en'].upper()}</span>{'<em>推荐</em>' if s['recommended'] else ''}</div>
    <div class="display">{tile(s, 292)}</div>
    <h2>{s['name']}</h2><p>{s['description']}</p>
    <div class="swatches"><span>原图案 · 原比例</span><span>1024 px</span></div>
    </article>''' for s in SCHEMES)
comparisons = ''.join(f'''<div class="wallpaper {theme}"><div class="wallpaper-label">{theme.upper()} / {s['letter']} · {s['name']}</div><div class="size-pair"><div>{tile(s,120)}<b>HomePad</b><small>120 px</small></div><div>{tile(s,60)}<b>HomePad</b><small>60 px</small></div></div></div>''' for theme in ['light','dark'] for s in SCHEMES)
downloads = ''.join(f'''<article><h3>{s['letter']} · {s['name']}</h3><a href="{s['id']}/icon-1024.png">1024 PNG</a><a href="{s['id']}/icon.svg">可编辑 SVG</a><a href="{s['id']}/icon-120.png">120 PNG</a><a href="{s['id']}/icon-60.png">60 PNG</a></article>''' for s in SCHEMES)
points = []
for i in range(256):
    a = 2 * math.pi * i / 256
    points.append(f'{.5+.5*math.copysign(abs(math.cos(a))**(2/4.6), math.cos(a)):.6f},{.5+.5*math.copysign(abs(math.sin(a))**(2/4.6), math.sin(a)):.6f}')
html = f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>HomePad · VILHIL Icon Study</title>
<style>
*{{box-sizing:border-box}}:root{{color-scheme:light}}body{{margin:0;background:#ececeb;color:#1d2329;font:16px/1.5 -apple-system,BlinkMacSystemFont,"Helvetica Neue","PingFang SC",sans-serif;-webkit-font-smoothing:antialiased}}.board{{width:1600px;max-width:100%;margin:0 auto;background:#f5f5f3;padding:54px 70px 46px}}.eyebrow{{display:flex;justify-content:space-between;color:#62686e;letter-spacing:2px;font-size:12px;font-weight:600}}h1{{font-size:62px;line-height:1.1;letter-spacing:-2.5px;margin:22px 0 15px;font-weight:600}}.lede{{font-size:19px;color:#747a7f;margin:0;letter-spacing:.2px}}.concepts{{display:grid;grid-template-columns:repeat(3,1fr);gap:24px;margin:42px 0 28px}}.concept{{padding:24px 27px 21px;background:#fff;border:1px solid #e6e7e5;border-radius:26px}}.concept-head{{display:flex;align-items:center;justify-content:space-between;color:#7a7e82;font-size:11px;letter-spacing:1.7px;font-weight:600;height:24px}}em{{font-style:normal;letter-spacing:1px;font-size:11px;border-radius:20px;background:#edf0ed;color:#535e57;padding:4px 13px}}.display{{height:340px;display:flex;align-items:center;justify-content:center}}.icon-wrap{{display:inline-block;filter:drop-shadow(0 8px 14px #12192412);flex-shrink:0}}.app-icon{{display:block;width:100%;height:100%;clip-path:url(#app-mask)}}h2{{font-weight:550;font-size:25px;letter-spacing:.4px;margin:3px 0 8px}}.concept p{{font-size:14px;color:#747a7f;line-height:1.7;white-space:nowrap;margin:0 0 26px;letter-spacing:.1px}}.swatches{{border-top:1px solid #ececea;padding-top:16px;display:flex;justify-content:space-between;font-size:11px;color:#92969a;letter-spacing:.5px}}.foot{{display:flex;align-items:center;justify-content:space-between;gap:24px;border-top:1px solid #dfe1df;padding-top:23px;font-size:13px;color:#7b8185}}.old{{display:flex;gap:15px;align-items:center}}.old img{{width:44px;height:44px;border-radius:10px}}.foot b{{font-weight:500;color:#50585f}}.background-board{{margin-top:2px;background:#f5f5f3}}.section-title{{font-size:34px;font-weight:550;letter-spacing:-.5px;margin:13px 0 12px}}.backgrounds{{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;margin:34px 0 25px}}.wallpaper{{height:306px;border-radius:22px;overflow:hidden;position:relative;border:1px solid #00000008}}.light{{background:radial-gradient(ellipse at 5% 0%,#fff8e6 0,transparent 65%),radial-gradient(ellipse at 100% 100%,#abc0ca 0,transparent 80%),linear-gradient(135deg,#eae8e4,#d4dce0);color:#25333c}}.dark{{background:radial-gradient(ellipse at 90% 10%,#2c3d52 0,transparent 68%),radial-gradient(ellipse at 0 100%,#3f414a 0,transparent 75%),#141c28;color:#f6f7fa}}.wallpaper-label{{position:absolute;top:19px;left:22px;opacity:.55;font-size:10px;font-weight:600;letter-spacing:1.8px}}.size-pair{{display:flex;align-items:center;justify-content:center;gap:65px;height:100%;padding-top:28px}}.size-pair>div{{display:flex;flex-direction:column;align-items:center}}.size-pair b{{font-size:12px;font-weight:500;margin-top:10px;text-shadow:0 1px 2px #00000008}}.size-pair small{{font-size:10px;opacity:.5;letter-spacing:1px;margin-top:9px}}.dark .icon-wrap{{filter:drop-shadow(0 6px 9px #00000025)}}.downloads{{display:grid;grid-template-columns:repeat(3,1fr);gap:24px;margin-top:30px}}.downloads article{{border-top:1px solid #d9dcda;padding-top:13px}}h3{{font-size:16px;font-weight:500}}a{{display:inline-block;margin:0 18px 12px 0;text-decoration:none;color:#525f6c;font-size:13px;border-bottom:1px solid #aab2b9}}.notes{{font-size:13px;color:#788087;line-height:1.9;max-width:980px}}.spec{{display:grid;grid-template-columns:1fr 1fr;gap:40px;margin:40px 0}}.spec figure{{margin:0;background:#fff;padding:35px;border-radius:20px;text-align:center}}.spec img{{width:100%;max-width:520px}}.spec p{{font-size:13px;color:#7b8185}}@media(max-width:1000px){{.board{{padding:32px 22px}}h1{{font-size:46px}}.concepts,.backgrounds,.downloads{{grid-template-columns:1fr}}.concept p{{white-space:normal}}.concepts{{max-width:560px;margin:auto;margin-top:28px}}.foot{{align-items:flex-start;flex-direction:column}}.backgrounds{{max-width:560px;margin:auto;margin-top:28px}}.spec{{grid-template-columns:1fr}}}}
</style>
<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs><clipPath id="app-mask" clipPathUnits="objectBoundingBox"><polygon points="{' '.join(points)}"/></clipPath></defs></svg>
<main>
<section class="board overview-board"><div class="eyebrow"><span>HOMEPAD / VILHIL</span><span>ICON STUDY · 16 OCT 2026</span></div><h1>一个安静、清楚的入口。</h1><p class="lede">保留正式品牌图案，让光、材质与留白完成图标。</p><div class="concepts">{cards}</div><div class="foot"><div class="old"><img src="source/current-homepad-icon.png" alt="现有 HomePad 图标"><span><b>当前图标</b><br>保留，等待设计确认。</span></div><span>推荐 A：黑白识别最直接，放在深浅桌面都稳定。</span><span>圆角为桌面效果示意 · 原始资产为不透明正方形</span></div></section>
<section class="board background-board"><div class="eyebrow"><span>ON YOUR HOME SCREEN</span><span>120 PX + 60 PX / 1× PREVIEW</span></div><h2 class="section-title">换个背景，依然一眼找到。</h2><p class="lede">三个方案使用相同图案和占比；下方按实际像素大小展示。</p><div class="backgrounds">{comparisons}</div><div class="foot"><span>浅色与深色均为合成桌面背景，不含私人图片。</span><span>60 px 时，斜面与中心节点仍独立清楚。</span><span>浏览器按 100% 查看可比较真实像素大小。</span></div></section>
<section class="board details-board"><div class="eyebrow"><span>DESIGN ASSETS</span><span>OFFLINE / EDITABLE / READY FOR REVIEW</span></div><h2 class="section-title">精确的形状，完整的源文件。</h2><div class="spec"><figure><img src="01-graphite/icon-1024.png" alt="推荐深石墨图标全幅正方形原稿"><p>A · 1024 px 原稿，全幅不透明，未预裁圆角</p></figure><div><h3>沿用已有正式图案</h3><p class="notes">以 VILHIL VI 的独立图案为基础，复用既有 SVG 三条原始路径。所有方案等比缩放，不改节点、斜率或笔画；不新造字母标，也不挤入长字标。</p><h3>为小尺寸安排留白</h3><p class="notes">主体宽 600 px，占画布 58.6%。左右各留 212 px，顶部 266 px，整体略向上作视觉平衡。1024、120、60 px 均由同一矢量输出。</p><h3>三种克制的材质</h3><p class="notes">A 用微光白标和深石墨形成清楚轮廓；B 用瓷白和深色图案延续品牌黑白；C 的浅黄基色取自正式 VI 的 LIGHT YELLOW。渐变只提供轻微材质与光照，轮廓不依赖细线或光晕。</p><h3>替换前可自由调整</h3><p class="notes">本包仅用于设计审阅。AppIcon 绑定、工程与现有功能保持原样。系统最终圆角、色调模式、实体 iPad 显示待选定方案接入后验证。</p></div></div><div class="downloads">{downloads}</div><p class="notes">素材来源、检查结果和重建方法见同目录 README.md、BRIEF.md 与 manifest.json。此页完全离线，无脚本、网络字体或外部图片。</p></section>
</main></html>'''
(ROOT / 'index.html').write_text(html)
print(json.dumps({'output':str(ROOT),'variants':[s['id'] for s in SCHEMES],'mark_bounds':manifest['layout']['mark_bounds']},ensure_ascii=False))
