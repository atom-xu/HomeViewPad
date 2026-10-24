# Aerial / music transition 15

User scenario: starting music on Home or Clock fades artwork over an already playing aerial. The aerial must not jump back to its static opening poster while it is still visible.

Scope: distinguish opaque music coverage from a page/background lifecycle stop. Let the same silent player continue through the 0.8-second music fade, then pause it in place with its actual video surface retained. Uncover resumes that same queue and position. Cancel delayed pauses after rapid toggles; actual offscreen/background/reduced-motion/static-selection cleanup still releases playback. Do not change Home layout, audio routing, or other pending work.

Acceptance: actual AVQueuePlayer identity/time/paused-frame readiness before and after coverage; delayed-task cancellation and immediate lifecycle cleanup; synthetic native Aerial + music UI on the independent simulator, recording inspection; signed build and Boom pad update with install/launch/manual acceptance reported separately. No commit/push.

## Result — 2026-10-24

Confirmed cause: `musicArtworkVisible` immediately made the aerial invisible, so `stopPlayer()` removed its queue while the music overlay was still fading. The visible surface fell back to the saved opening poster. Music coverage now has a separate state: the existing muted player runs through the shared 0.8-second fade, pauses in place with its rendered surface retained, and resumes without seeking or rebuilding when uncovered. True offscreen/background/reduced-motion/static-selection cleanup still releases it; already covered backgrounds do not create a decoder, and shuffle is suspended while covered.

Xcode 27.0 / SDK 27.0, independent iPad Pro 11-inch M5 / iPadOS 26.5 simulator (arm64): 42 focused unit methods and two native UI journeys passed in `regression.xcresult`. The new native Aerial/music UI journey passed again in 44.689 seconds during recording. The first combined run had a long wall-clock gap during its second tap and is not used as performance evidence. The explicitly labeled synthetic video is a silent three-second loop, not a real streaming service or account. Native screenshots and the 48–55-second, six-frames-per-second transition filmstrip were inspected; no opening-poster swap appears during the fade.

Signed Release build and strict codesign verification passed. Installed on Boom pad `00008112-000A4861368A201E`, iPadOS 27.0.1 (24A446), then read back `cn.vilhil.homeviewpad` version 1.0 / build 1 at installation `3E0B3B0B-9632-46DC-B7FC-45F966DEF780`; ordinary Home launch succeeded. The user then confirmed the physical start/pause transition is normal, with no reversal. This acceptance covers the reported transition, not general performance, all video assets or other HomeKit/AirPlay features.

Raw evidence, commands, movie, screenshots and package/input hashes: `.validation/local/aerial-music-15/`. No live viewer, route/volume changes, commit or push. Existing performance/photo/design WIP remains preserved.
