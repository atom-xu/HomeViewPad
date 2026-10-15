#!/usr/bin/env python3
"""Export named XCUITest screenshots from an xcresult, without altering pixels."""
import json, pathlib, re, shutil, struct, subprocess, sys, tempfile
bundle, destination = sys.argv[1:3]
out = pathlib.Path(destination); out.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='homepad-shots-') as temp:
    subprocess.run(['xcrun','xcresulttool','export','attachments','--path',bundle,'--output-path',temp], check=True)
    manifest = json.loads((pathlib.Path(temp)/'manifest.json').read_text())
    for test in manifest:
        for item in test['attachments']:
            source = pathlib.Path(temp)/item['exportedFileName']
            if source.suffix != '.png': continue
            name = re.sub(r'[^a-z0-9]+','-',item['suggestedHumanReadableName'].split('_0_')[0].lower()).strip('-')+'.png'
            shutil.copy2(source,out/name)
            width,height = struct.unpack('>II',source.read_bytes()[16:24])
            print(name, width, height)
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2))
