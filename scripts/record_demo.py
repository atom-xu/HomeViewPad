#!/usr/bin/env python3
"""Record the deterministic XCTest demo journey, then convert its video to a GIF.
Usage: python3 scripts/record_demo.py SIMULATOR_UUID [--full-suite]
Requires Xcode and at least two approved demo photos in the selected simulator.
Use scripts/seed_test_photos.py for synthetic fixtures, or simctl addmedia for
photos you have permission to include in the recorded GIF.
Raw recording, test logs and xcresult stay in ignored .validation/.
"""
import json, pathlib, signal, subprocess, sys, time
root = pathlib.Path(__file__).resolve().parents[1]
if len(sys.argv) < 2:
    raise SystemExit(__doc__)
simulator = sys.argv[1]
stamp = time.strftime('%Y%m%d-%H%M%S')
out = root / '.validation' / f'demo-{stamp}'
out.mkdir(parents=True)
video = out / 'demo.mov'
cmd = ['xcodebuild', '-project', 'HomePad.xcodeproj', '-scheme', 'HomePad',
       '-destination', f'platform=iOS Simulator,id={simulator}', '-parallel-testing-enabled', 'NO',
       '-collect-test-diagnostics', 'never', '-derivedDataPath', '/tmp/HomeViewPadDemoDerived',
       '-resultBundlePath', str(out / 'tests.xcresult'), 'CODE_SIGNING_ALLOWED=NO', 'test']
if '--full-suite' not in sys.argv:
    cmd += ['-only-testing:HomePadUITests/HomePadUITests/testReadmeDemoJourney']
recorder = None
completed = False
started_at = None
markers = {}
try:
    with (out / 'tests.log').open('w') as log, (out / 'recording.log').open('w') as recordlog:
        proc = subprocess.Popen(cmd, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        for line in proc.stdout:
            log.write(line); log.flush()
            if 'HOMEVIEWPAD_DEMO_READY' in line and recorder is None:
                recorder = subprocess.Popen(['xcrun', 'simctl', 'io', simulator, 'recordVideo', '--codec=h264', str(video)], stdout=recordlog, stderr=recordlog)
                started_at = time.monotonic()
                print('Recording started:', video, flush=True)
            if started_at is not None:
                for marker in ['PHOTOS', 'PHOTO_2', 'PHOTO_3', 'RETURN']:
                    if f'HOMEVIEWPAD_DEMO_{marker}' in line:
                        markers[marker] = time.monotonic() - started_at
            if 'HOMEVIEWPAD_DEMO_DONE' in line and recorder is not None:
                recorder.send_signal(signal.SIGINT); recorder.wait(timeout=20)
                recorder = None; completed = True
                print('Recording finalized.', flush=True)
        result = proc.wait()
    (out / 'markers.json').write_text(json.dumps(markers, indent=2))
    if result != 0 or not completed:
        raise SystemExit(f'Tests or capture failed ({result}); inspect {out}')
finally:
    if recorder is not None:
        recorder.send_signal(signal.SIGINT); recorder.wait(timeout=20)
subprocess.run(['swift', str(root / 'scripts/video_to_gif.swift'), str(video), str(root / 'docs/media/demo.gif'), str(out / 'markers.json')], check=True)
print('Evidence:', out, flush=True)
