# HomeViewPad

**Your home, at a glance.**

A quiet, native iPad dashboard for Apple Home, personal photos, and time. Built with SwiftUI, with glass widgets, an immersive photo wall, and controls that stay out of the way until you need them.

[简体中文](docs/README.zh-CN.md) · [Get started](#get-started) · [Privacy](docs/ARCHITECTURE.md) · [Validation](docs/VALIDATION.md) · [MIT license](LICENSE)

![An iPad displaying HomeViewPad beside a HomePod mini on a living-room sideboard](docs/media/ipad-homepod-use-case.png)

*AI-generated use-case illustration based on an actual app screenshot. The screen shows demo data. This is an independent project, not an Apple product or an endorsement by Apple.*

## An iPad with a place in your home

Put an iPad on a stand or a wall mount. See the room temperature, adjust a compatible thermostat, run a scene, or turn on a light. Swipe over to a clock or let your chosen album fill the screen.

A HomePod mini can sit alongside it as your home's independent Siri speaker and home hub. **HomeViewPad runs on the iPad; HomePod mini is optional and is not directly paired with this app.** Audio routing uses the system AirPlay picker. Home hub requirements depend on your Apple Home setup.

## See it in action

![Actual simulator recording of HomeViewPad demo controls, widget stacks, clock, photo wall, and navigation](docs/media/demo.gif)

*Recorded from the running app in an iPad simulator: deterministic demo accessories and original, non-personal gradient images in the simulator's Photos library. The GIF shows UI interaction, not physical HomeKit or HomePod verification. See [media provenance and reproduction](docs/MEDIA.md).*

## What it does

- **An immersive glass dashboard.** One large square climate widget and five smaller widgets; warm-gray and teal themes; no persistent header or navigation bar.
- **Distinct widget stacks.** Climate, clock/calendar, photos/camera, scenes, other devices, and lights each have their own content. Position dots appear briefly while switching.
- **Apple Home controls.** Select a home, filter rooms, read supported accessories, adjust writable numeric values, and run existing scenes with confirmation. Thermostat arrows respect the device's range and step. Writes are read back before being reported as successful.
- **Your photos, on display.** Choose a PhotoKit album or a single image. The photo wall combines a large clock with a foreground slideshow and crossfades. Full and limited Photos access are supported.
- **Optional extras.** Open a compatible HomeKit camera, show upcoming calendar events and reminders, or play a local audio file through the system AirPlay picker.
- **A self-contained demo.** Explore without a home or accessories. Demo mode is visibly labeled and never initializes the real HomeKit manager.

### Gestures

| Action | Result |
| --- | --- |
| Swipe left or right | Switch between Home, Clock, Photos, and Settings |
| Swipe up or down inside a widget | Cycle that widget's available content |
| Tap empty wallpaper | Reveal navigation on the right in landscape or at the bottom in portrait |
| Tap the photo wall | Reveal navigation |
| Tap thermostat arrows | Adjust a writable target temperature |

Transitions respect Reduce Motion. Optional foreground screen-awake mode is available in Settings.

## Get started

### Explore in the simulator

1. Clone the repository and open `HomePad.xcodeproj` in Xcode.
2. Select the **HomePad** scheme and an installed iPad simulator running iPadOS 17 or later.
3. Build and run, then choose **Explore demo**.

The app's display name is **HomeViewPad**. The Xcode project, scheme, and source directory retain their original `HomePad` names to keep existing development workflows stable. There are no third-party package dependencies.

### Use your own iPad

1. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`.
2. Set your own unique bundle identifier and Apple development team in that local file. It is ignored by Git; do not commit signing identities or provisioning profiles.
3. Connect the iPad, select it in Xcode, and build with the **HomePad** scheme. Your signing account must be able to provision the HomeKit entitlement. Complete Apple's device trust and Developer Mode prompts when required.
4. Choose **Connect Apple Home**, allow access, and select your home in Settings. Configure accessories and scenes in Apple's Home app first.
5. Tap the photo widget to choose a single photo, or connect the photo library and select an album. With limited access, the app displays only allowed photos.

Photos rotate every 30 seconds while the Home page or photo wall is visible. Rotation pauses when a panel is open or the app is inactive. Permission-denied, empty, offline, and unavailable states are shown explicitly.

## Privacy and boundaries

No app account, backend, analytics, or tracking SDK. HomeKit, PhotoKit, EventKit, and AirPlay use Apple's public APIs and system permissions. Optional calendar and reminder content is hidden until you opt in.

Album images are requested on demand; iCloud images may download through PhotoKit. A single imported photo is saved inside the app's sandbox. The app never edits your Photos library. Anyone who can see this shared screen can see the personal content you enable. Read the [data lifecycle](docs/ARCHITECTURE.md).

**This is an early personal project.** Simulator tests cover UI and application logic; real accessory compatibility, camera streaming, AirPlay, and long-running wall-display use still need hardware validation. See the [hardware checklist](docs/HARDWARE_CHECKLIST.md).

HomeViewPad is not a home hub. It does not host Siri, access a HomePod microphone, send Intercom messages, or embed FaceTime. It does not create automations or directly edit locks, blinds, or thermostat modes. Existing scenes can include those actions, so scene execution always asks for confirmation. There is no weather service, Apple Music catalog integration, presence detection, or background camera recording.

## Development

Requires macOS and Xcode with an iPadOS simulator runtime. The deployment target is iPadOS 17; the currently validated toolchain is recorded in [VALIDATION.md](docs/VALIDATION.md).

```sh
# List available simulator destinations.
xcrun simctl list devices available

# Seed non-personal image fixtures once on your booted test simulator.
python3 scripts/seed_test_photos.py SIMULATOR_UUID

# Run XCTest and XCUITest.
sh scripts/test.sh SIMULATOR_UUID

# Record the demo journey and encode a GIF with Apple's media frameworks.
python3 scripts/record_demo.py SIMULATOR_UUID
```

The demo recording script interacts only with the selected simulator. Use a dedicated test simulator containing no personal photos. Raw video, test results, and logs stay in the ignored `.validation/` directory.

The checked-in project can be regenerated with `python3 scripts/generate_project.py` after adding source files. This overwrites generated project settings but preserves the separate, ignored `Config/Local.xcconfig` file. Keep personal signing overrides there.

Launch arguments `--demo`, `--state denied|empty|offline|loading`, `--far`, and `--fresh` support reproducible review. `--state` only applies to demo mode.

## Contributing

Bug reports and focused improvements are welcome. Include your iPad model, iPadOS version, reproduction steps, and whether the issue occurs in demo or real-home mode. Remove home names, accessory identifiers, photos, and signing information from reports.

Keep the project independent of employer code and private services. Use public APIs and original or appropriately licensed assets. Follow [AGENTS.md](AGENTS.md), including this repository's commit-time policy: actual commits only after 22:00 on weekdays or anytime on weekends in America/New_York. Run `python3 scripts/commit_guard.py` before committing; never alter timestamps. The optional local hook can be enabled with `git config core.hooksPath .githooks`.

## License

[MIT](LICENSE). Apple, iPad, HomePod mini, HomeKit, and AirPlay are trademarks of Apple Inc. HomeViewPad is independently developed and is not affiliated with Apple or other similarly named products. See [media notes](docs/MEDIA.md) for the README illustration and demo fixtures.
