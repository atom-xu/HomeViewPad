"""Independent icon study. Does not read or write application assets."""
from pathlib import Path
import json
import shutil

ROOT = Path(__file__).resolve().parent
ORIGINAL = ROOT.parent / '2026-10-homepad-v2' / '03-dwell'

DEFS = '''<defs>
<linearGradient id="canvas" x1=".1" y1="0" x2=".8" y2="1"><stop stop-color="#FFFFFF"/><stop offset=".65" stop-color="#FAFBFA"/><stop offset="1" stop-color="#EFF2F1"/></linearGradient>
<linearGradient id="body" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#7BD7BB"/><stop offset=".55" stop-color="#48BEA6"/><stop offset="1" stop-color="#2AA68F"/></linearGradient>
<linearGradient id="roof" x1="0" y1="0" x2=".8" y2="1"><stop stop-color="#A5E5C4"/><stop offset="1" stop-color="#67CFA8"/></linearGradient>
<linearGradient id="core" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#F7D79A"/><stop offset="1" stop-color="#ECC17A"/></linearGradient>
<filter id="soft" x="-20%" y="-20%" width="140%" height="145%" color-interpolation-filters="sRGB"><feDropShadow dx="0" dy="9" stdDeviation="10" flood-color="#32AA94" flood-opacity=".11"/></filter>
</defs>'''

# These are hand-edited Bezier paths after raster concept exploration, not
# embedded raster files or an automatic bitmap trace. Each new mark has 3 paths.
STUDIES = [
    dict(id='a', transform='translate(113.1 113) scale(.635)', paths=[
        ('body', 'M448 234 H746 C818 234 864 267 864 314 C864 350 843 373 802 387 L455 502 C402 519 375 554 375 604 V703 C375 752 357 789 323 831 C301 859 286 891 279 919 C276 928 269 934 260 927 C238 905 225 870 225 826 V439 C225 316 322 234 448 234 Z'),
        ('roof', 'M963 359 C1005 359 1031 396 1031 469 V835 C1031 945 939 1020 824 1020 H409 C348 1020 315 981 315 947 C315 891 371 851 448 851 H747 C837 851 868 813 868 724 V485 C868 412 904 359 963 359 Z'),
        ('core', 'M716 468 C785 468 828 518 828 590 V731 C828 785 801 812 747 812 H497 C446 812 419 785 419 734 V628 C419 587 438 557 478 542 L681 475 Q698 468 716 468 Z'),
    ]),
    dict(id='b', transform='translate(81.535 79.012) scale(.686)', paths=[
        ('body', 'M617 258 C639 255 650 270 650 292 V657 C650 677 639 695 621 706 L407 827 Q381 840 367 864 C354 884 337 890 318 877 C301 864 292 845 292 824 V482 C292 451 306 423 332 407 L587 268 Q607 257 617 258 Z'),
        ('roof', 'M710 350 L917 469 C947 486 963 513 963 548 V766 C963 785 949 797 932 788 L708 691 Q681 681 681 658 V379 C681 352 693 343 710 350 Z'),
        ('core', 'M710 726 L929 813 C957 824 962 847 947 868 Q941 879 927 886 L699 992 Q659 1011 620 991 L421 909 C393 897 393 865 411 848 L645 728 Q676 711 710 726 Z'),
    ]),
    dict(id='c', transform='translate(141.775 149) scale(.59)', paths=[
        ('body', 'M366 190 C435 190 472 222 472 278 V456 C472 503 490 529 510 535 Q520 540 509 543 C409 565 348 607 348 660 C348 716 411 758 444 794 C464 817 472 848 472 886 V941 C472 1009 439 1032 368 1032 H333 C233 1032 186 949 186 894 V340 C186 239 264 190 366 190 Z'),
        ('roof', 'M874 297 C1009 297 1070 343 1070 445 V895 C1070 999 975 1032 895 1032 H881 C814 1032 783 998 783 942 V887 C783 843 800 816 831 791 C873 758 910 715 910 660 C910 607 881 565 832 544 C799 529 783 506 783 466 V380 C783 326 815 297 874 297 Z'),
        ('core', 'M536 550 H765 C823 550 850 579 871 624 Q894 659 872 694 L811 750 C794 767 784 786 778 805 Q774 818 760 818 H558 Q546 818 541 806 C529 786 521 781 505 769 L404 694 C376 671 375 644 400 618 L465 571 Q492 550 536 550 Z'),
    ]),
]

for folder in ['concepts', 'exports', 'exploration']:
    (ROOT / folder).mkdir(exist_ok=True)
shutil.copyfile(ORIGINAL / 'icon.svg', ROOT / 'concepts' / 'original.svg')

for study in STUDIES:
    paths = ''.join(f'<path data-part="{name}" fill="url(#{name})" d="{d}"' + (' transform="translate(25.2 27.36) scale(.96)"' if study['id'] == 'c' and name == 'core' else '') + '/>' for name, d in study['paths'])
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024" role="img" aria-labelledby="title desc">
<title id="title">HomePad silhouette study {study['id'].upper()}</title>
<desc id="desc">New HomePad concept, not a formal VILHIL mark. Three editable filled Bezier paths. Raster exploration interpreted and simplified by hand. Full opaque square master; rounded tile mask is for preview only.</desc>
{DEFS}<rect width="1024" height="1024" fill="url(#canvas)"/>
<g filter="url(#soft)"><g id="homepad-symbol" transform="{study['transform']}">{paths}</g></g></svg>'''
    (ROOT / 'concepts' / (study['id'] + '.svg')).write_text(svg)

cards = ''.join(f'''<section class="card"><h2>{label}</h2><img class="big tile" src="concepts/{key}.svg" alt="{label}"><div class="tiny"><img class="tile" width="60" height="60" src="exports/{key}-60.png" alt="{label} at 60 pixels"><span>60 px</span></div></section>''' for key, label in [('original', '原版'), ('a', 'A'), ('b', 'B'), ('c', 'C')])
desktop_cells = lambda size: ''.join(f'<img class="tile" width="{size}" height="{size}" src="exports/{key}-{size}.png" alt="{key}">' for key in ['original', 'a', 'b', 'c'])
html = f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>HomePad icon silhouettes</title><style>
*{{box-sizing:border-box}}body{{margin:0;background:#e7eae7;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;color:#31483d}}.board{{width:1680px;padding:38px 48px 42px;background:#f1f3ee}}header{{font-size:14px;color:#819184;letter-spacing:.12em;margin-bottom:28px}}.grid{{display:grid;grid-template-columns:repeat(4,1fr);gap:28px}}.card{{display:flex;align-items:center;flex-direction:column}}h2{{font-size:23px;font-weight:500;margin:0 0 23px;line-height:28px}}.tile{{clip-path:url(#mask);display:block}}.big{{width:366px;height:366px}}.tiny{{display:flex;flex-direction:column;align-items:center;gap:12px;margin-top:36px}}.tiny span{{font-size:11px;color:#849385;letter-spacing:.04em}}.desktop{{width:1680px;background:#f1f3ee;padding:38px 48px 48px}}.desk-grid{{display:grid;grid-template-columns:1fr 1fr;gap:28px}}.scene{{padding:28px 40px 40px;border-radius:24px}}.light{{background:linear-gradient(140deg,#edf2e4,#cdded3)}}.dark{{background:linear-gradient(140deg,#1a2928,#10191e)}}.row{{display:flex;justify-content:space-between;align-items:center}}.labels{{margin-bottom:28px;color:#53675e;font-size:16px;text-align:center}}.labels span{{width:120px}}.dark .labels{{color:#cbd8d1}}.small-row{{margin:36px 30px 0}}.size{{font-size:11px;text-align:center;color:#7a8d81;margin:15px 0 0}}.dark .size{{color:#8ca79e}}svg.defs{{position:absolute;width:0;height:0}}</style>
<svg class="defs" aria-hidden="true"><defs><clipPath id="mask" clipPathUnits="objectBoundingBox"><path d="M.22 0H.78C.95 0 1 .05 1 .22V.78C1 .95 .95 1 .78 1H.22C.05 1 0 .95 0 .78V.22C0 .05 .05 0 .22 0Z"/></clipPath></defs></svg>
<main class="board"><header>HOMEPAD</header><div class="grid">{cards}</div></main>
<div class="desktop"><header>HOMEPAD · 120 / 60 PX</header><div class="desk-grid">''' + ''.join(f'''<section class="scene {scene}"><div class="row labels"><span>原版</span><span>A</span><span>B</span><span>C</span></div><div class="row">{desktop_cells(120)}</div><div class="row small-row">{desktop_cells(60)}</div><p class="size">120 / 60 px</p></section>''' for scene in ['light', 'dark']) + '</div></div></html>'
(ROOT / 'index.html').write_text(html)
(ROOT / 'concepts.json').write_text(json.dumps(STUDIES, indent=2))
print('Wrote 3 editable concepts and original reference; application assets untouched.')
