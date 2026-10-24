#!/usr/bin/env python3
from pathlib import Path
import json,re

ROOT=Path(__file__).resolve().parent
(ROOT/'symbols').mkdir(exist_ok=True)
T='#40B49B';M='#99D8BC';G='#E9C27F';W='#FAFCF8';INK='#3D5548'
IDEAS=[
 ('01','窗里','把家藏进一扇窗，外方内柔。',f'''
<rect x="48" y="48" width="160" height="160" rx="38" fill="{T}"/>
<path d="M88 171 V119 Q88 111 95 105 L119 84 Q128 77 137 84 L161 105 Q168 111 168 119 V171 Q168 178 161 178 H95 Q88 178 88 171 Z" fill="{W}" data-cutout="house"/>
<rect x="115" y="139" width="26" height="39" rx="9" fill="{G}"/>
'''),
 ('02','合院','四块日常模块，围出一片自己的空间。',f'''
<rect x="62" y="54" width="88" height="40" rx="18" fill="{T}"/>
<rect x="162" y="62" width="40" height="88" rx="18" fill="{G}"/>
<rect x="106" y="162" width="88" height="40" rx="18" fill="{T}"/>
<rect x="54" y="106" width="40" height="88" rx="18" fill="{M}"/>
'''),
 ('03','开页','像翻开面板，把两个空间轻轻展开。',f'''
<path d="M55 65 Q50 63 50 70 V166 Q50 174 57 177 L112 201 Q122 205 122 196 V103 Q122 95 115 92 Z" fill="{T}"/>
<path d="M201 65 Q206 63 206 70 V166 Q206 174 199 177 L144 201 Q134 205 134 196 V103 Q134 95 141 92 Z" fill="{M}"/>
<path d="M163 110 L182 102 Q189 99 189 107 V128 Q189 135 183 138 L164 146 Q157 149 157 141 V120 Q157 113 163 110 Z" fill="{G}"/>
'''),
 ('04','里外','窗中还有一扇窗，内外收在同一眼里。',f'''
<rect x="51" y="48" width="118" height="118" rx="28" fill="none" stroke="{M}" stroke-width="16"/>
<rect x="87" y="89" width="118" height="118" rx="28" fill="{W}" stroke="{T}" stroke-width="16"/>
<rect x="124" y="126" width="44" height="44" rx="13" fill="{G}"/>
'''),
 ('05','互嵌','两片斜面错位咬合，留出一个共同的中心。',f'''
<path d="M111 56 L60 107 Q49 118 60 129 L111 180" fill="none" stroke="{T}" stroke-width="28" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M145 76 L196 127 Q207 138 196 149 L145 200" fill="none" stroke="{M}" stroke-width="28" stroke-linecap="round" stroke-linejoin="round"/>
<rect x="112" y="116" width="31" height="31" rx="9" transform="rotate(45 127.5 131.5)" fill="{G}"/>
'''),
 ('06','开间','从房屋立面转到平面，给生活留一个入口。',f'''
<path d="M151 57 H87 Q57 57 57 87 V169 Q57 199 87 199 H169 Q199 199 199 169 V151" fill="none" stroke="{T}" stroke-width="20" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M101 156 V119 Q101 109 111 109 H143" fill="none" stroke="{M}" stroke-width="18" stroke-linecap="round" stroke-linejoin="round"/>
<rect x="177" y="67" width="30" height="58" rx="12" fill="{G}"/>
'''),
 ('07','抱窗','让两侧的空间弯下来，抱住中间的一点灯光。',f'''
<path d="M101 53 C68 73 49 98 49 132 C49 170 73 197 108 207 Q123 211 129 197 Q134 183 119 177 C96 168 82 151 82 132 C82 113 91 101 108 90 Q131 75 120 59 Q113 49 101 53 Z" fill="{T}"/>
<path d="M101 53 C68 73 49 98 49 132 C49 170 73 197 108 207 Q123 211 129 197 Q134 183 119 177 C96 168 82 151 82 132 C82 113 91 101 108 90 Q131 75 120 59 Q113 49 101 53 Z" transform="translate(256 0) scale(-1 1)" fill="{M}"/>
<rect x="108" y="109" width="40" height="40" rx="13" fill="{G}"/>
'''),
 ('08','拼合','一个主空间和一块新模块，刚好接进彼此。',f'''
<path d="M81 52 H146 Q169 52 169 75 V100 H134 V96 Q134 87 125 87 H96 Q87 87 87 96 V160 Q87 169 96 169 H125 Q134 169 134 160 V155 H169 V181 Q169 204 146 204 H81 Q52 204 52 175 V81 Q52 52 81 52 Z" fill="{T}"/>
<path d="M165 109 H190 Q207 109 207 126 V139 Q207 156 190 156 H165 Q160 156 160 151 V147 H143 Q134 147 134 138 V127 Q134 118 143 118 H160 V114 Q160 109 165 109 Z" fill="{G}"/>
'''),
]

for number,name,concept,art in IDEAS:
 for mono in [False,True]:
  content=art
  if mono:
   for color in [T,M,G]:content=content.replace(color,INK)
  title=f'HomePad concept {number} · {name}'
  svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256" role="img" aria-labelledby="title"><title id="title">{title}</title>{content}</svg>'
  (ROOT/'symbols'/f'{number}{"-mono" if mono else ""}.svg').write_text(svg)

cards=''.join(f'''<article class="card"><div class="number">{number}<span>CONCEPT EXPLORATION</span></div><div class="art"><img src="symbols/{number}.svg" alt="{name}创意草案"></div><h2>{name}</h2><p>{concept}</p></article>''' for number,name,concept,art in IDEAS)
smalls=''.join(f'''<div class="small-cell"><span>{number}</span><div><img src="symbols/{number}.svg" width="60" height="60" alt="{name}60像素"><img src="symbols/{number}-mono.svg" width="60" height="60" alt="{name}单色60像素"></div></div>''' for number,name,concept,art in IDEAS)
html=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>HomePad · 八种空间想法</title><style>
*{{box-sizing:border-box}}:root{{color-scheme:light}}body{{margin:0;background:#eef1eb;color:#304638;font:16px/1.5 -apple-system,BlinkMacSystemFont,"Helvetica Neue","PingFang SC",sans-serif;-webkit-font-smoothing:antialiased}}.board{{width:1600px;max-width:100%;margin:0 auto;background:#f2f5ee;padding:46px 62px 36px}}.eyebrow{{display:flex;justify-content:space-between;letter-spacing:2px;font-size:11px;font-weight:550;color:#91a085}}h1{{font-size:53px;line-height:1.2;letter-spacing:-1.5px;font-weight:550;margin:22px 0 13px}}.lede{{color:#8a9b7d;font-size:17px;margin:0}}.grid{{display:grid;grid-template-columns:repeat(4,1fr);gap:19px;margin:31px 0 30px}}.card{{background:#fafcf8;border:1px solid #dfe7d7;border-radius:23px;padding:21px 23px 23px}}.number{{font-size:20px;font-weight:450;color:#78956e;display:flex;justify-content:space-between;align-items:center;letter-spacing:.5px}}.number span{{font-size:8px;letter-spacing:1.5px;color:#b4bfaa;font-weight:400}}.art{{height:203px;display:flex;align-items:center;justify-content:center}}.art img{{width:236px;height:236px}}h2{{font-size:24px;font-weight:550;letter-spacing:.7px;margin:0 0 8px}}.card p{{font-size:12px;line-height:1.9;color:#8b9c7d;margin:0;min-height:45px}}.small-heading{{display:flex;justify-content:space-between;color:#8b9f7d;font-size:11px;letter-spacing:.5px;border-top:1px solid #d7e1ce;padding-top:22px}}.small-row{{display:grid;grid-template-columns:repeat(8,1fr);gap:12px;margin:15px 0 23px}}.small-cell{{display:flex;align-items:center;flex-direction:column}}.small-cell>span{{font-size:10px;letter-spacing:1px;color:#a6b49b}}.small-cell>div{{display:flex;gap:9px;align-items:center;margin-top:4px}}.small-cell img{{display:block}}.footer{{display:flex;justify-content:space-between;gap:24px;border-top:1px solid #d7e1ce;padding-top:20px;color:#9bac8b;font-size:11px;line-height:1.8}}@media(max-width:1000px){{.board{{padding:28px 20px}}h1{{font-size:38px}}.grid{{grid-template-columns:repeat(2,1fr)}}.small-row{{grid-template-columns:repeat(4,1fr)}}.footer{{flex-direction:column}}}}@media(max-width:600px){{.grid{{grid-template-columns:1fr}}.small-row{{grid-template-columns:repeat(2,1fr)}}}}
</style><main class="board"><div class="eyebrow"><span>HOMEPAD / CREATIVE EXPLORATION</span><span>04 · IDEAS BEFORE DETAILS</span></div><h1>让「家窗」再长出八种可能。</h1><p class="lede">窗口、模块、围合、折叠与嵌合——先打开结构，再选择值得继续的方向。</p><div class="grid">{cards}</div><div class="small-heading"><span>60 px 彩色＋单色轮廓 / 每个图形同等尺寸</span><span>只看缩小后是否仍有自己的结构</span></div><div class="small-row">{smalls}</div><div class="footer"><span>八个同等呈现的创意草案，不作定稿排序。</span><span>延续几何斜面与核心节点的来源，不冻结原 C 的数量或轮廓。</span><span>颜色为探索基准 · 尚未替换 AppIcon</span></div></main></html>'''
(ROOT/'index.html').write_text(html)
(ROOT/'concepts.json').write_text(json.dumps([{'number':n,'name':name,'concept':concept,'editable_svg':f'symbols/{n}.svg'} for n,name,concept,art in IDEAS],ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'output':str(ROOT),'concepts':8},ensure_ascii=False))
