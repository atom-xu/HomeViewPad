# Validation

## Black four-widget Overview page — 2026-10-14

Added Overview between Home and Clock, with date and a numbered analog clock above an album and weather. The entire viewport and all four square widgets use opaque black, white typography and yellow accents. The existing glass Home page is unchanged. Tapping the album opens the shared PhotoKit chooser; the visible Overview album participates in the existing 30-second slideshow.

- Toolchain and runtime: Xcode 27.0, iPad Pro 11-inch (M5), iPadOS 27.0 (24A434), iOS Simulator. Deployment target remains iPadOS 17.0.
- The [complete scheme run](evidence/overview-suite-summary.json) executed **31 tests: 30 passed, one failed, zero skips** (15 unit + 16 UI). The failed paging test assumed an empty photo wall but inherited a previously selected simulator album. It now explicitly removes the app's displayed-photo selection before checking the empty state; library assets are untouched.
- A separate preview run passed the new layout test with the owner's supplied photos. A later rerun caught an intermediate accessibility frame during the animated page transition. The geometry check now waits for the four square frames to settle and reads each frame once. The [final focused rerun](evidence/overview-followup-summary.json) passed **both affected tests, zero failures or skips**, on the final source. All 31 distinct test methods have therefore passed across the complete run and focused reruns; this is not a claim of a subsequent all-green 31-test bundle. The only app changes after the complete-run build were the single-photo accessibility description and the slideshow help text.
- Portrait and landscape screenshots were exported and visually inspected, including the owner's previously supplied park photo. Date and temperature digits, dial numerals, photo thumbnail and labels are complete. All four viewport corners are RGB (0, 0, 0); no glass, borders or header appear on the new page. Raw screenshots remain under ignored `.validation/overview-preview-shots/`.
- Tests cover four square cells and their row/column placement, album-panel access, page order in both directions, hidden navigation and its landscape placement, and the live/demo weather distinction. The album lifecycle test also waits for an actual Overview album advance at the unchanged 30-second interval.
- Weather has no configured provider. Only labeled demo mode shows the fixed San Francisco fixture; live mode shows “Not connected / No weather source.” No new location permission, network integration or HomeKit initialization in demo mode was added.
- The generator was rerun with identical output and preserved the ignored local signing override. The existing README GIF predates this page; its recording was not replaced in this change.
- This build has not been installed on the physical iPad. No physical HomeKit, HomePod, camera or AirPlay validation is claimed.

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
