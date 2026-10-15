# Physical hardware validation — NOT YET VERIFIED

Simulator success does not establish any of the following. Use an iPad and a HomePod mini owned by you, with a disposable/test accessory where practical.

- [ ] Select a personal signing team and unique bundle identifier. Confirm HomeKit entitlement provisioning succeeds, install on iPad, and launch without signing warnings.
- [ ] Deny Home permission; verify denied state and Settings recovery. Grant, return, retry, and verify the correct home's actual accessories appear.
- [ ] Check multiple homes and home selection. Revoke permission while suspended and verify no stale controls or personal data remain visible on return.
- [ ] Switch a test light on/off repeatedly; compare physical state and the Apple Home app. Disconnect accessory power/Wi-Fi and confirm offline status; restore and retry.
- [ ] Adjust supported brightness, thermostat target temperature and fan speed within device-advertised bounds; verify the device and Apple Home agree. Test rejected writes, missing metadata and write-success/read-back-failure.
- [ ] Read temperature/humidity and compare with Apple Home. Validate units and service names for each vendor.
- [ ] Inspect a harmless scene in Apple Home, cancel its HomeViewPad confirmation, then run it. Verify every physical effect and completion/error reporting. Check scene rejection from a restricted shared-home account.
- [ ] Open a supported HomeKit camera, confirm video, close, reopen, background, and return. Confirm no background stream remains. Test unavailable/offline camera and retry. Verify no audio transmission or microphone permission is requested.
- [ ] Configure HomePod mini in Apple Home; verify hub status and supported Thread routing independently. Do not credit HomeViewPad with those functions.
- [ ] Choose a downloaded audio file, select HomePod mini via AirPlay, play/pause, interrupt, and change routes. Validate codec failure and lost-speaker behavior. Test selecting and dismissing Files repeatedly.
- [ ] Grant full and limited Photos access; select a named album/Allowed photos, verify rotation and pause behavior, change the allowed set, delete the selected album/photo in Photos, and revoke access in Settings while suspended. Check no old image returns; test iCloud download failure/retry and library edits.
- [ ] Pick a large/iCloud photo, cancel the picker, replace it, relaunch, and remove it. Confirm removal after relaunch and inspect storage growth.
- [ ] Deny and grant calendar/reminder permissions separately. Test empty stores, all-day events, time-zone changes, duplicate titles, and revocation. Confirm shared-display opt-in and hiding when disabled.
- [ ] Verify thermostat up/down arrows against the actual target temperature and advertised step/range; confirm read-back, bound/offline/busy disabling, and no write from read-only sensors or vertical swipes.
- [ ] Test near/far, portrait/landscape, split view, largest Dynamic Type, VoiceOver, Voice Control, external keyboard, Reduce Motion and increased contrast. Verify touch targets and text remain usable.
- [ ] Enable foreground-awake; verify it resets on leaving HomeViewPad. Validate Guided Access manually if wanted. Observe long-running heat, power, OLED/LCD wear considerations, charging and mounting under actual conditions.

No physical-device, HomePod, camera, AirPlay, EventKit-permission, or long-duration hardware validation is claimed by the simulator suite.
