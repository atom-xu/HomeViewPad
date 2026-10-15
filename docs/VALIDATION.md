# Validation

## README identity and copy refresh — 2026-10-14

Documentation and media only; app source and behavior were unchanged. Both READMEs now use the generated HomeViewPad logo, centered headers, feature tables, the existing actual demo GIF, and collapsible setup/development sections. The DIY HomeView comparison is limited to overlapping everyday uses; HomePod features and app features remain explicitly distinguished.

Both language versions were checked with GitHub's GFM rendering API: seven images and three tables each, three English/two Chinese disclosure sections retained. Local links and heading targets resolve. The 1254 × 1254 RGBA logo was inspected and its transparent alpha verified. The exact generation prompt and provenance are in [MEDIA.md](MEDIA.md). No app tests were rerun for this documentation-only change; existing test evidence below remains applicable to its tested code.

## Real-photo demo refresh — 2026-10-14, 22:09 EDT

Re-recorded the README demo using only the owner's three supplied photos in a new, dedicated iPad Pro 11-inch (M5) simulator, iPadOS 27.0 (24A434), with Xcode 27.0. The original JPEGs are not distributed. App production code was not changed.

- The recording UI test passed: **1 selected test, zero failures and zero skips**; see the [sanitized summary](evidence/photo-demo-summary.json). The prior full 30-test result below remains the latest full-suite run.
- The capture now waits for two actual PhotoKit album advances. Exported screenshots and GIF frames were inspected and show the city park, museum display, and fish photos in turn, with the digital clock and DEMO label.
- Portrait photographs use the existing centered fill crop in a landscape photo wall; the museum photograph is visibly cropped at the top and bottom. No photo-layout behavior was changed for the recording.
- GIF: 1119 frames, 880 × 606 px, 12.5 fps, 89.52 seconds, 9,005,627 bytes. No slideshow speed-up or synthesized frames.
- No new physical HomeKit, HomePod or real-iPad verification is claimed. Raw video, results, screenshots and the previous GIF remain in ignored `.validation/`.

## Publication preparation — 2026-10-14

The display name and user-facing copy are now **HomeViewPad**. Internal Xcode project/scheme names remain HomePad. Shared signing settings use `Config/Signing.xcconfig`; the owner's existing installation identity is preserved only in ignored `Config/Local.xcconfig`.

- Toolchain: Xcode 27.0 (27A266a), macOS 27.0.1, arm64.
- Simulator: iPad Pro 11-inch (M5), iPadOS 27.0 (24A434).
- Deployment target: iPadOS 17.0.
- Initial rename run: all 14 UI tests passed; one unit assertion still expected the old display name. The assertion was updated.
- Final full suite completed at 21:58 EDT: **30 passed (15 unit + 15 UI), zero failures, zero skips**. The added UI journey records the README demo. See the [sanitized result summary](evidence/publication-summary.json).
- A separate simulator build with the generic `org.homeviewpad.app` bundle identifier and no development team succeeded.
- The generator was rerun and its output hashes were identical; the ignored local signing override was preserved.
- Renamed-app screenshots and GIF sample frames were visually inspected: complete thermostat digits/arrows, correct landscape layout, visible DEMO badges, clock, photo wall and navigation transitions.
- GIF: 337 frames, 880 × 606 px, 12.5 fps, 26.96 seconds, 3,387,820 bytes. The source video is about 27.19 seconds; conversion trims 0.1 seconds at each end.

The new README hero is AI-generated concept art using an actual app screenshot as its reference. It is not a photograph of a tested hardware installation. The GIF is captured from the running simulator using XCUITest and `simctl recordVideo`; only demo accessories and non-personal test photos are used.

## Previous verified baseline

Before this publication preparation, the full suite passed **29 tests: 15 unit + 14 UI, zero failures and zero skips**, on the same simulator/runtime at 20:42 EDT on 2026-10-14. The sanitized [result summary](evidence/reference-layout-summary.json) retains the counts and runtime. Layout screenshots were inspected in portrait and landscape, including complete thermostat digits and arrows.

A signed Debug build of that baseline was installed and launched on an iPad Pro 11-inch running iPadOS 26.6 (23G71). Installation and process launch were confirmed separately. The renamed build has not been installed on physical hardware during this documentation task.

## Limits

No physical HomeKit thermostat write, HomePod/AirPlay playback, real camera stream, or sustained wall-display performance has been verified by these simulator results. PhotoKit simulator authorization and reads are separate from physical iPad album testing. Use the [hardware checklist](HARDWARE_CHECKLIST.md).

Raw xcresult bundles, videos, machine-specific logs and historical screenshots are retained locally under ignored `.validation/`; they are not shipped in this repository. Public summaries omit personal device and signing identifiers.
