#!/usr/bin/env python3
"""Check the actual exported assets and original mark geometry (requires Pillow)."""
from pathlib import Path
import hashlib
import json
import platform
import sys
import xml.etree.ElementTree as ET
from PIL import Image, __version__ as pillow_version

ROOT = Path(__file__).resolve().parent
manifest = json.loads((ROOT / 'manifest.json').read_text())
original = ET.parse(ROOT / 'source/vilhil-mark-original.svg')
paths = [node.attrib['d'] for node in original.getroot() if node.tag.endswith('path')]
assert paths == manifest['unmodified_path_data']
assert hashlib.sha256((ROOT / 'source/vilhil-mark-original.svg').read_bytes()).hexdigest() == manifest['source_svg_sha256']

def components(image, light_mark):
    gray = image.convert('L')
    w, h = image.size
    pixels = gray.load()
    remaining = {(x, y) for y in range(h) for x in range(w) if pixels[x, y] > 200} if light_mark else {(x, y) for y in range(h) for x in range(w) if pixels[x, y] < 100}
    groups = []
    while remaining:
        start = remaining.pop()
        queue = [start]
        group = [start]
        while queue:
            x, y = queue.pop()
            for dx, dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
                p = (x+dx, y+dy)
                if p in remaining:
                    remaining.remove(p)
                    queue.append(p)
                    group.append(p)
        xs, ys = zip(*group)
        groups.append({'pixels':len(group), 'bounds':[min(xs),min(ys),max(xs)+1,max(ys)+1]})
    return sorted(groups, key=lambda g: g['pixels'], reverse=True)

checks = []
for variant in manifest['variants']:
    directory = ROOT / variant['id']
    tree = ET.parse(directory / 'icon.svg')
    g = next(n for n in tree.getroot().iter() if n.attrib.get('id') == 'brand-mark')
    assert [p.attrib['d'] for p in g] == paths, f'Altered brand paths: {variant["id"]}'
    use = next(n for n in tree.getroot().iter() if n.tag.endswith('use'))
    assert use.attrib['transform'] == f'translate(212 266) scale({manifest["layout"]["uniform_scale"]:.12f})'
    for size in [1024, 120, 60]:
        file = directory / f'icon-{size}.png'
        im = Image.open(file)
        assert im.size == (size, size), (file, im.size)
        assert im.convert('RGBA').getchannel('A').getextrema() == (255,255), f'Transparent pixel: {file}'
        record = {'asset':str(file.relative_to(ROOT)), 'size':list(im.size), 'mode':im.mode, 'fully_opaque':True}
        if size in [120,60]:
            groups = components(im, variant['id'] == '01-graphite')
            # The formal sloped paths meet at one zero-area apex point. Depending
            # on target-pixel coverage, they form one or two thresholded regions.
            # The business requirement is an intact, independent center node.
            assert 2 <= len(groups) <= 3, f'Unexpected source-shape topology: {groups}'
            center = [g for g in groups if g['bounds'][0] > size*.4 and g['bounds'][2] < size*.6 and g['bounds'][1] > size*.5]
            assert len(center) == 1, f'Center node is missing or joined to an arm: {groups}'
            scale = manifest['layout']['uniform_scale']
            expected = [(212+119.352*scale)*size/1024, (266+139.199*scale)*size/1024,
                        (212+159.047*scale)*size/1024, (266+208.801*scale)*size/1024]
            assert all(abs(a-b) <= 1 for a,b in zip(center[0]['bounds'],expected)), f'Center node geometry changed: {center}'
            for x,y in [(40,170),(238.398,170),(139.199,174)]:
                px,py = round((212+x*scale)*size/1024),round((266+y*scale)*size/1024)
                value = im.convert('L').getpixel((px,py))
                assert value > 200 if variant['id'] == '01-graphite' else value < 100
            record['mark_components'] = groups
            record['center_node_independent_and_bounds_within_one_pixel'] = True
        checks.append(record)

report = {
    'status':'passed',
    'environment':{'platform':platform.platform(), 'python':sys.version.split()[0], 'pillow':pillow_version},
    'paths_preserved':True,
    'uniform_scale':manifest['layout']['uniform_scale'],
    'assets':checks,
    'visual_review':{
        'inspected':['previews/overview.png','previews/backgrounds-120-60.png','previews/source-and-recommended.png','01-graphite/icon-1024.png','02-porcelain/icon-1024.png','03-daylight/icon-1024.png'],
        'result':'Mark proportions, clear space, gradients, edges and separated center node inspected. No clipping or unexpected transparency.',
        'limitations':'Desktop masking is an illustration. No actual system icon rendering, tinted/clear appearance, simulator install or physical iPad validation.'
    },
    'xctest_xcuitest':'Not run: independent design assets only, no app behavior, view layout or AppIcon integration changed.'
    ,'check_correction':'The first custom check incorrectly assumed the two sloped source paths always form a connected raster region. They touch at a zero-area apex point in the official vector. The final check preserves all paths, checks the three geometric sample points, verifies the independent center-node bounds within one target pixel, and accepts the mathematically expected two or three thresholded regions. No icon geometry was changed for the check.'
}
(ROOT / 'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
hashes = {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(ROOT.rglob('*')) if p.is_file() and p.name != 'sha256.json'}
(ROOT / 'sha256.json').write_text(json.dumps(hashes,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'status':'passed','png_assets':len(checks),'preserved_original_paths':len(paths),'small_size_component_checks':6},ensure_ascii=False))
