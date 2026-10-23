<p align="center">
  <img src="docs/media/homeviewpad-logo.png" width="128" height="128" alt="HomePad">
</p>
<h1 align="center">HomePad</h1>
<p align="center">A native iPad dashboard for Apple Home, clocks, photos and foreground standby.</p>
<p align="center">
  <a href="docs/README.zh-CN.md">简体中文</a> · <a href="SETUP.md">Local setup</a> · <a href="docs/VALIDATION.md">Validation</a> · <a href="docs/ARCHITECTURE.md">Architecture and privacy</a>
</p>

HomePad is a personal fork of [kuscholar/HomeViewPad](https://github.com/kuscholar/HomeViewPad), developed in the local `homepad` directory. The fork repository remains [atom-xu/HomeViewPad](https://github.com/atom-xu/HomeViewPad). The app, Xcode project and scheme are named **HomePad**. It uses SwiftUI and public Apple frameworks, supports iPadOS 17+, and has no third-party packages or app-owned backend.

## The current interface

**Home opens first.** Home controls, Clock and Settings use the full iPad viewport. The current version supports landscape left and landscape right only. Home uses three square columns on the left, with additional rows scrolling vertically. The fixed right column fills the remaining width with rectangular cards, each the same row height as the left cells. The climate widget remains a 2×2 square. Home has no header, home-name label, room selector, section titles or permanent editing toolbar. Photo display has its own page; large accessibility text remains scrollable. In Settings → Display & standby → Wallpaper, browse a Mac-style thumbnail gallery of photos, colors and Apple Aerial videos. Home, Clock and clock standby share the selection. Aerials download over Wi-Fi and loop silently offline; shuffle rotates downloaded videos every 1, 5 or 15 minutes. Reduce Motion uses a still, and hidden/background playback stops. The independent Photos page keeps its own source. See [source and validation notes](docs/DYNAMIC-SCREENSAVER-10.md).

| Feature | How it works |
| :--- | :--- |
| Apple Home controls | Choose a home in Settings and filter rooms in the Controls panel. Control supported accessories and confirm before running scenes. Thermostat arrows follow device-advertised limits and steps. |
| Editable widgets | Add accessories, scenes, cameras or display widgets through revealed navigation or context menus. Touch and hold a widget to resize or remove it. Extra widgets scroll vertically; layouts are saved separately for demo and each selected home. |
| Clear device state | Tap an accessory icon to switch power; tap its name for supported brightness, color and other details. VoiceOver retains the exact state without a redundant On/Off line. Unknown/offline values remain explicit and cannot be switched. |
| Custom shortcuts | The extra column starts with Camera, Music and Controls. A chosen camera can show live muted video; an unconfigured card opens camera selection. Add camera, scene or other supported entries through navigation; touch and hold a shortcut to edit or remove it. Scene shortcuts still require confirmation. |
| Chinese and English | Settings offers Follow system, 简体中文 and English. The choice persists; real home, room and accessory names remain unchanged. |
| Photos | Choose 1–24 photos, an iPad album or Favorites. The independent Photos page offers a wall of up to four images or one full-screen photo. Selected-photo copies are saved locally; originals are unchanged. Visible photos rotate every 30 seconds, including photo-wall standby; panels and inactivity pause rotation. |
| Night and standby | Manual or scheduled night appearance; an app standby clock or photo wall after the iPad stays nearly vertical, stationary and untouched for the selected delay. Preview standby from Settings. |

Overview remains a separate black four-widget page with date, clock, album and weather. Live weather uses [Open-Meteo](https://open-meteo.com/), with optional foreground location or manual city selection. The independent Music page connects Apple Music for library/catalog access and selected-song playback, or plays an audio file. The calendar connection reads the next seven days after explicit consent; Reminders are not requested. The system AirPlay picker selects a speaker. A HomePod mini works independently through Apple's Home and AirPlay features.

Demo mode is visibly labeled **DEMO / 演示**, uses fixed sample home data, time and weather, and never creates the real HomeKit manager. A demo camera is a placeholder, not a live stream.

## Navigation

| Action | Result |
| :--- | :--- |
| Long-press a widget and choose Show navigation | Open navigation on the right. |
| Swipe left / right | Move along Overview → Home → Clock → Photos → Settings. |
| Scroll up / down in Home controls | Reach additional widgets. |
| Touch and hold, then choose Next / Previous widget | Switch that category's content without controlling a device. |
| Touch and hold a widget | Change its size or remove it. |
| Tap the standby screen | Return to the previous page. |

Animations respect Reduce Motion. Widget categories remain independent. Home no longer contains a photo tile; choose **Photos** or **Albums** in navigation to configure photos.

## Get started

Use macOS and Xcode with a compatible installed iPad simulator runtime. Follow [SETUP.md](SETUP.md) for environment checks, an isolated simulator and exact test commands.

```sh
git clone https://github.com/atom-xu/HomeViewPad.git homepad
cd homepad
open HomePad.xcodeproj
```

Choose the **HomePad** scheme and an available iPad simulator. Run, then choose **Explore demo** on Home. No accessories are needed for demo mode. For a deterministic preview, add the `--demo` launch argument.

For your own iPad:

1. Copy `Config/Local.xcconfig.example` to the ignored `Config/Local.xcconfig`; enter your unique bundle identifier and development team.
2. Connect and pair the iPad, complete Apple's signing, trust and Developer Mode requirements, and run the HomePad scheme.
3. On Home, choose **Connect Apple Home** and grant permission. Configure homes, accessories and scenes in Apple's Home app first.
4. Use the separate Photos page to choose an image or authorize an album. Limited Photos access shows only permitted images.

Compilation, simulator execution, device installation and physical accessory acceptance are separate outcomes. See [current validation](docs/VALIDATION.md) and the [hardware checklist](docs/HARDWARE_CHECKLIST.md).

## Foreground display and privacy

Standby is an **in-app foreground mode**. Touch restores the controls; supported motion sensing can also restore them. Front-camera face wake is off by default. Enabling it and granting camera permission allows detection during standby. A separate **Allow continuous foreground face detection** switch explicitly permits sampling on non-standby pages, including after waking. This additional choice is off by default; existing face-wake settings and system permission never enable it automatically. With that choice enabled, ongoing presence delays automatic standby, and absence must last the selected idle delay before standby returns. System Auto-Lock follows the selected Screen behavior. Turning it off restores standby-only detection; turning face wake off also clears this additional consent. Detection checks presence, not identity, and never saves images, records video or sends frames anywhere. Navigation, presented panels and scene confirmations pause detection; leaving the foreground stops it. The system camera indicator remains visible while detection runs.

Proximity wake works only where the device exposes a supported proximity sensor. Generic infrared sensing is not available as an app feature on every iPad. The app cannot unlock or wake a system-locked iPad, replace the system lock screen, or guarantee reopening after reboot. Users may enable Guided Access in iPad Settings for a dedicated display; see [foreground kiosk research and limits](docs/IPAD-KIOSK-RESEARCH.md).

Night mode darkens the app; standby also temporarily lowers screen brightness and uses a subdued warm clock. Brightness is restored when standby ends or the app leaves the foreground. Real sensing range, orientation behavior, heat, battery use and long-running display behavior still require physical iPad checks.

No app account, analytics or tracking SDK is used. HomeKit, PhotoKit, EventKit and AirPlay retain their system permissions. The app never edits the Photos library; an imported single image is stored in its sandbox. People nearby can see whatever you choose to display.

Weather sends city searches and coordinates to Open-Meteo; automatic coordinates are rounded to about 1 km and kept in memory. Manual city and unit choices are local preferences. The free endpoint has personal/non-commercial terms; review the provider's [licensing](https://open-meteo.com/en/pricing) before commercial distribution. See the [data lifecycle](docs/ARCHITECTURE.md) for details.

HomePad is not a home hub. It cannot host Siri, access a HomePod microphone, send Intercom messages or embed FaceTime. Apple Music requires MusicKit App Service configuration, user authorization and an eligible account for catalog playback. Household identity recognition and background camera recording are not provided. Scene execution always asks for confirmation because existing scenes may affect locks, doors or other accessories.

## Historical upstream media

<p align="center">
  <img src="docs/media/demo.gif" width="880" alt="Historical upstream HomeViewPad simulator demo, before this fork's full-screen editable Home interface">
  <br><sub>Inherited upstream recording. It shows the earlier square layout and gestures, not the current fork or current acceptance evidence.</sub>
</p>

The inherited [setup illustration](docs/media/ipad-homepod-use-case.png) also uses an older screenshot. These assets are retained with their [original media provenance](docs/MEDIA.md); they do not demonstrate the new layout, standby sensing or hardware integration. Current test results belong in [docs/VALIDATION.md](docs/VALIDATION.md).

## Development

Start with [SETUP.md](SETUP.md), [development conventions](docs/DEVELOPMENT.md), [initialization and handoff](docs/INITIALIZATION.md), and [AGENTS.md](AGENTS.md). The current iteration scope is recorded in [IPAD-DISPLAY-01](docs/IPAD-DISPLAY-01.md).

Use a dedicated simulator and synthetic photos for routine tests. Run the HomePad scheme's XCTest/XCUITest suite after meaningful behavior changes, export screenshots after layout changes, and report runtime, failures and untested hardware separately. Generated files come from `python3 scripts/generate_project.py`; preserve intentional settings and keep personal signing configuration out of Git.

Use public APIs and original or licensed materials. Actual commits are limited to after 22:00 on weekdays or any time on weekends in America/New_York; check `python3 scripts/commit_guard.py`. Never backdate commits. Push and publication need their own explicit authorization and destination.

[MIT license](LICENSE) · [Upstream](https://github.com/kuscholar/HomeViewPad) · [Architecture](docs/ARCHITECTURE.md) · [Validation](docs/VALIDATION.md)

Apple, iPad, HomePod mini, HomeKit and AirPlay belong to Apple Inc. HomePad is an independent project, not affiliated with or endorsed by Apple. Upstream names and historical asset filenames remain unchanged where they identify their actual source.
