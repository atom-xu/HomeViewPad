# Physical hardware validation — NOT YET VERIFIED

## Pending for music refinement 08

2026-10-17: final08 source snapshot `7c794f69a68c8a3201aed9988764cab6051478e7223dba2c52210055d7f2666c` signed, installed and ordinarily launched on the paired Boom pad / iPadOS27.0.1 over user-connected USB. Exact installation URL and matching process readback passed. No device viewer or route/volume changes. This is installation evidence; physical acceptance remains separate.

- [x] Queue → player → Back reaches selectable album cards: user confirmed “到了专辑卡片页，不再循环” on08 after USB update (2026-10-17). This accepts the specified physical journey, not every playback-source/focus variant.
- [ ] From a real playing album, enter the full player and use Back: selectable Albums cards, focused on the playing album, without entering tracks or queue. Explicitly open queue, return to player, then Back again; repeat with playlist and unknown/restored playback.
- [ ] Reopen with an empty queue; it may remain empty. Choose an album and confirm full collection playback still works. No persistence requirement was added.
- [ ] Inspect actual cover art top/bottom/side fading and floating shadows while dragging in both landscape directions. Check Songs too; synthetic placeholders do not establish real artwork quality.

  Partial08 acceptance: user opened real album cards; viewer-free SDK27 devicectl static screenshot was inspected. Full card bounds, vertical fade/shadow space and aligned header circles were visible at rest. Dragging, Songs, both physical orientations and user aesthetic approval remain unchecked.
- [x] New volume slider visibility and dragging: after08 USB update, user confirmed “能看到滑杆，拖动正常” (2026-10-17). This is user-reported slider operation, not independently measured output volume or audible/AirPlay acceptance. Dismissal/playback continuity is simulator-tested; verify physical continuity separately. Native MPVolumeView does not draw a hardware slider on this simulator.
- [ ] Confirm no Search UI remains and all three header output/settings icons align. Recheck actual AirPlay and sound; older-package feedback does not accept this candidate.

## Pending for music browsing 06 and weather city 07

2026-10-17 installation follow-up: the unchanged signed candidate is now installed and ordinarily launched on Boom pad, with exact install URL and PID/executable readback. CoreDevice reports wired/connected. The installation-only requirement is complete; functional/visual/audio/location hardware checks below remain open. See [physical update evidence](evidence/ipad-music-browser-weather-physical-update-summary.json).

- Completed 2026-10-17: final signed candidate installed, exact installation URL read back, ordinary launch and matching process executable verified. Local signature checks and cached pairing details alone do not establish installation.
- Verify real album artwork fading, album/song/playlist selection, source-aware player return and readable settings. Keep the Mac device viewer closed during audible testing; its previous association with silence does not establish a cause.
- Test manual city search/save/reopen, then deliberately tap Locate once. Confirm the actual resolved city is saved and reopening, foreground activation and forecast refresh never restart location. Cancellation, denial and failure must retain the old city. Simulator denial and controlled geocoder tests do not prove physical Apple reverse-geocoding success.
- Previous-version feedback does not validate this candidate's audio, AirPlay, HomeKit/camera, location or sustained display behavior.

## General hardware checks

Simulator success does not establish any of the following. Use an iPad and a HomePod mini owned by you, with a disposable/test accessory where practical.

- [ ] Select a personal signing team and unique bundle identifier. Confirm HomeKit entitlement provisioning succeeds, install on iPad, and launch without signing warnings.
- [ ] Deny Home permission; verify denied state and Settings recovery. Grant, return, retry, and verify the correct home's actual accessories appear.
- [ ] Check multiple homes and home selection. Revoke permission while suspended and verify no stale controls or personal data remain visible on return.
- [ ] Switch a test light on/off repeatedly; compare physical state and the Apple Home app. Disconnect accessory power/Wi-Fi and confirm offline status; restore and retry.
- [ ] Adjust supported brightness, thermostat target temperature and fan speed within device-advertised bounds; verify the device and Apple Home agree. Test rejected writes, missing metadata and write-success/read-back-failure.
- [ ] Read temperature/humidity and compare with Apple Home. Validate units and service names for each vendor.
- [ ] Inspect a harmless scene in Apple Home, cancel its HomePad confirmation, then run it. Verify every physical effect and completion/error reporting. Check scene rejection from a restricted shared-home account.
- [ ] Open a supported HomeKit camera, confirm video, close, reopen, background, and return. Confirm no background stream remains. Test unavailable/offline camera and retry. Verify no audio transmission or microphone permission is requested.
- [ ] Configure HomePod mini in Apple Home; verify hub status and supported Thread routing independently. Do not credit HomePad with those functions.
- [ ] Choose a downloaded audio file, select HomePod mini via AirPlay, play/pause, interrupt, and change routes. Validate codec failure and lost-speaker behavior. Test selecting and dismissing Files repeatedly.
- [ ] Grant full and limited Photos access; select a named album/Allowed photos, verify rotation and pause behavior, change the allowed set, delete the selected album/photo in Photos, and revoke access in Settings while suspended. Check no old image returns; test iCloud download failure/retry and library edits.
- [ ] Pick a large/iCloud photo, cancel the picker, replace it, relaunch, and remove it. Confirm removal after relaunch and inspect storage growth.
- [ ] Confirm first launch opens Home, then open Overview for weather. Choose a city manually; verify save/reopen, °C/°F, offline/stale labeling and saved-city forecast refresh. Explicitly use Locate once, deny/allow approximate location and revoke in Settings; verify cancellation/failure preserves the old selection and passive use never retries. Do not expect a fabricated Philadelphia fallback or automatic following.
- [ ] Deny and grant calendar permission. Test empty calendars, all-day events, time-zone changes, duplicate titles, and revocation; confirm Reminders permission is never requested. Confirm shared-display opt-in and hiding when disabled.
- [ ] Verify thermostat up/down arrows against the actual target temperature and advertised step/range; confirm read-back, bound/offline/busy disabling, and no write from read-only sensors or vertical swipes.
- [ ] Test near/far, portrait/landscape, split view, largest Dynamic Type, VoiceOver, Voice Control, external keyboard, Reduce Motion and increased contrast. Verify touch targets and text remain usable.
- [ ] Keep the iPad near vertical and stationary for the selected idle delay; verify foreground standby, touch/movement wake and original brightness restoration. Repeat in portrait/landscape and after backgrounding, camera/panel interruptions and night-schedule changes.
- [ ] Confirm face wake is off by default and asks for camera access only after explicit opt-in. Verify an existing wake preference plus system permission retains standby-only capture, with no automatic expanded consent. Separately enable continuous foreground detection and remain in view for several idle-delay intervals: the display must stay awake without repeated dim/wake cycles. Leave the view for the full configured delay and verify standby; return and verify wake. Withdraw the expanded scope and confirm standby-only capture; turn the master off/on and confirm extra consent is not restored. Check denied/revoked permission, interruption, navigation/panel suspension, background stopping and the system camera indicator. Measure actual sensing range and power/heat separately.
- [ ] Enable foreground-awake; verify it resets on leaving HomePad. Validate Guided Access manually if wanted. Observe long-running heat, power, OLED/LCD wear considerations, charging and mounting under actual conditions.

No physical-device, HomePod, camera, AirPlay, EventKit-permission, or long-duration hardware validation is claimed by the simulator suite.

## Real-use revision 01

- [ ] Select multiple real photos, cancel/replace, relaunch, remove HomePad copies; check iCloud-only assets and Favorites without changing originals.
- [ ] Connect Apple Music, confirm real library/catalog response and subscription errors, play/pause a chosen track, switch to a local file without overlapping playback, and select an AirPlay output.

  2026-10-16 partial acceptance: on physical iPad Pro 11-inch (4th generation) / iPadOS 27.0.1, real library artwork, album browsing and current-track progress were observed; the user confirmed audible HomePad playback after the audio comparison described in VALIDATION. Remote AirPlay/HomePod audibility, local-file handoff and subscription-error hardware paths remain unchecked, so this combined item stays open.
- [ ] Select each available Apple Home household, check data/stream cleanup after switching, and verify icon power commands separately from opening text/details. Test supported brightness/hue/saturation/color temperature against device readback.
- [ ] Explicitly choose a compatible camera for the rectangular sidebar, verify muted live video, open/close the same camera, background/foreground, revoke Home access and switch homes. The unconfigured sidebar must not open the first camera automatically.
- [ ] Preview real photo-wall standby, verify 30-second progression, touch wake and brightness restoration; camera/motion wake still requires separate consent and physical checks.

## Music navigation 04 — physical follow-up

2026-10-17: after the initial local-only checkpoint, user authorized updating. The same verified signed package is now installed on the physical iPad; ordinary launch and exact executable/installation URL readback succeeded. Network settings were untouched and Device Hub was not opened. The physical interaction checks below remain pending. See [update readback](evidence/ipad-music-navigation-physical-update-summary.json).

- [ ] On the updated real iPad, swipe the player artwork left/right to leave Music, return, then tap the artwork: a tap opens albums, a drag must not change the music subpage or playback. Drag the timeline and Cover Flow separately; the latter two remain local controls. Swipe outside Cover Flow to change Dashboard pages.
- [ ] From player, albums, tracks, queue, search and disconnected states, use the labeled Pages entry to reach Home/Clock/Photos/Settings. Check returning preserves browsing and playback; repeat at maximum text size and both supported landscape directions. Real audio/AirPlay remain separate from simulator TEST DATA.

## Interaction fixes 03 — physical follow-up

- [x] Music AirPlay page continuity: after the final update, user confirmed “页面保持不变，不再跳加载” on the physical iPad (2026-10-17 Asia/Shanghai). This does not verify Home-widget presentation, background ordering or audible output.
- [x] Visible selected Home-camera static snapshot updates: user confirmed “能看到静态快照更新” on the same package. Exact cadence/capture timestamps, offline errors and live-stream teardown remain unchecked below.

- [ ] Open AirPlay from Music and Home, select/cancel an output, and verify the current music page/album remains visible without reconnecting; verify actual audible output separately.
- [ ] With AirPlay still open, actually background/lock the iPad; verify private music content clears and return rechecks permissions. Simulator lifecycle regressions do not establish this system presentation ordering.
- [ ] On the selected real camera, watch Home snapshots for at least three capture updates; compare actual capture timestamps and confirm earlier/error status when offline. HomeKit may return an earlier frame.
- [ ] Leave Home and return within ten seconds: retained snapshot appears without starting a sidebar stream. Open the camera explicitly for muted live video, then close it and verify the stream stops.
- [ ] Switch households or revoke Home access while snapshot requests are pending; no previous-household frame may reappear. Check visible-only polling on the actual iPad/window mode.
- [ ] Repeat Overview horizontal paging and long-press climate/edge widgets on the real iPad. Check full black gutters and complete lifted content at normal and accessibility sizes.

## Playback and display 05 — physical follow-up

- [ ] Play an entire real album and playlist, let a song end naturally, and confirm automatic continuation and actual sound; include a collection exceeding one MusicKit response batch and a playlist containing duplicates. Select its final duplicate and verify the correct occurrence, not the first one.
- [ ] Shuffle a collection and the whole current queue. Verify the complete real queue remains present, including previously played entries, and starts from the new first entry. Subscription, unavailable songs, denied access and interrupted fetches need actual-account checks.
- [ ] While Apple Music is audibly playing, inspect Home's music card and Home/Clock cover backdrop. Confirm Photos/slideshow and Overview remain their own content; pause and verify the chosen background returns. Revoke music access and change to a local file to check cleanup.
- [ ] Explicitly select Keep current page and a 30-second delay. While playing music, wait without touching: the same page should dim. Touch over a Home control or playback button once to restore brightness without activating it; the next ordinary touch operates it. Repeat background/foreground and real auto-brightness/night schedule.
- [ ] Select automatic clock/photos and follow-system Auto-Lock separately. Check legacy installations retain previous sensing behavior until a mode is chosen; HomePad cannot unlock a system-locked iPad.
- [ ] In unified Settings, check large Chinese text, Calendar/Weather city & units/Permissions entrypoints, denied-to-granted return, and Add calendar to Home after actual connection. Choosing a background/default color must leave the independent photo wall intact.

2026-10-17 partial acceptance for playback/display 05: final signed package installed and ordinarily launched on iPad Pro 11-inch (4th generation) / iPadOS 27.0.1. The user confirmed “有声音，且自动进入下一首” to the requested real-album end-of-track test. Large playlists, duplicates, real shuffle/artwork, calendar Add to Home and long-duration dim/night behavior remain unchecked, so the combined hardware items above stay open.

## Music browsing 06 — separate physical acceptance

The current iteration uses labeled synthetic music on the isolated simulator. Previous 05 audible automatic-next feedback does not validate this new package's navigation, rendering, refresh or source identity.

- [x] Install/launch the exact 06/07 signed candidate on the paired iPad: 2026-10-17 exact installation URL and process readbacks passed; cached pairing alone is insufficient.
- [ ] Play a real album A, browse album B without changing playback, open the player and return to A. Repeat with a playlist.
- [ ] Verify Albums/Songs/Playlists selection, soft Cover Flow edges, explicit song selection and full-library queue on the real account.
- [ ] Verify opaque Music settings at normal/largest text; Refresh must stay connected without invoking Disconnect or stopping real playback.
- [ ] Verify audio and AirPlay with the new package while the Mac device viewer remains closed.
