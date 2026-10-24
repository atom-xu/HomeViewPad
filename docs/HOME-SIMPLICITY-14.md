# Home simplicity 14

User scenario: a wall-mounted iPad provides immediate common Home controls, with editing and technical information kept out of daily use.

Scope:
- Preserve the approved landscape geometry: three square base columns, a wider right column with the same row height, vertical overflow.
- Long press → Edit Home. Only editing shows removal, resizing and drag handles. Add is grouped by left controls / right cards. Keep an accessible list ordering alternative. Editing never operates accessories and ends when leaving Home or losing access.
- Fade saved backgrounds and music artwork without a blank intermediate frame. Keep Photos independent, respect Reduce Motion, avoid adding video decoders or full-resolution animated blur.
- Device text opens common controls and state. Color controls and full information remain reachable through separate entries. Preserve HomeStore writes and readback.

Acceptance: pure tests for home/lane/session drop boundaries and minimal control selection; native UI journeys for add/remove/reorder persistence, edit safety, simple control → details → back, light adjustment, known HomeKit families and music/wallpaper round trip. Inspect English and Chinese large-text screenshots in both landscape directions. Record implementation, test, install and physical acceptance separately.

Existing performance 13 and asynchronous PhotoKit follow-up are pre-existing WIP. Do not claim their unresolved photo navigation test or presence timeout rule is fixed by this iteration. No Git commit/push in this scope.

## Delivered behavior and evidence

- Normal Home exposes editing by long press or navigation. Editing shows a small add/list/Done toolbar and per-card remove, size/configuration and drag handles. Left and right lanes reorder independently. Removing only changes this iPad's saved dashboard. The accessible list editor remains available.
- Device actions are disabled during editing; page swiping and idle entry are suspended. Editing ends when leaving Home, backgrounding, losing Home access or changing home. A session/home/lane payload validates each reorder. Drag geometry is collected only in editing and updated without animation.
- Saved configuration explicitly invalidates the observable layout cache. The reproduced failure was a successful five-card JSON save with a still-visible six-card canvas. Notification repaired immediate removal; the full native add/remove/reorder/relaunch journey then passed.
- Common controls and current state open first. Color tuning has its own entry; all secondary controls, readings, maintenance and refresh remain in Details. Small controls use a compact sheet, adjustable devices a taller sheet, and accessibility text sizes a full-height scrollable sheet. HomeStore still owns writes/readback.
- Saved wallpaper remains beneath music. Colors, selected photo identity and music coverage fade over approximately 0.8 seconds. Music background images decode off the main actor at up to 512 px and retain the previous image until the next load completes. Aerial poster/Starting/Playing transitions fade; no extra video decoder is introduced. Photos remains a separate page.

Final verification: 21 focused XCTest methods plus nine native UI journeys passed in `acceptance.xcresult`. Both landscape directions, Chinese maximum accessibility text, dimmer readback/offline state, complete context previews, simple controls → Details → back, in-place editing and relaunch persistence, list editing/restore cancellation, music background round trip and selected-photo wallpaper cancellation/replacement/relaunch/removal were covered. Exported screenshots and two filmstrips of the native recording were inspected. Raw evidence, exact command logs and 65 frozen source hashes are in `.validation/local/home-simplicity-14/`.

Earlier full XCTest execution: 219/220 passed; the existing Presence09 30-second-rule test remains failing. Earlier UI repair attempts are retained but superseded by the final nine passing journeys. Unfiltered complete UI suite was not rerun. Synthetic music verifies state/visual transitions, not real CDN downloads or physical audio. Actual Aerial video transitions, the system Reduce Motion toggle and the prior complete selected multi-photo wall/standby follow-up are not newly accepted here.

The signed Release was installed on Boom pad (iPadOS 27.0.1); CoreDevice readback confirms its new installation URL. Automatic launch was denied because the device was locked. No live device viewer was opened; manual physical acceptance remains pending. No Git commit or push.
