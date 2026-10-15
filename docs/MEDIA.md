# README media

## HomeViewPad logo

`media/homeviewpad-logo.png` is an original logo concept generated with the built-in imagegen tool on 2026-10-14: an evergreen glass tile, ivory house/window outline, modular panes and a small amber light. The transparent PNG is used in both README headers. No Apple logo or third-party brand artwork was supplied as a reference. The exact prompt is in [media/logo-prompt.txt](media/logo-prompt.txt). The logo is included with the project materials under the MIT license; no exclusive rights to AI-generated output are claimed.

## Use-case illustration

`media/ipad-homepod-use-case.png` was generated with the built-in imagegen tool on 2026-10-14. The supporting image was an actual HomeViewPad/HomePad simulator screenshot from the reference-layout validation run. No Apple promotional photograph or private photo was used as an input.

The image is concept art: a landscape iPad on a stand beside a HomePod mini. Generated screen details may differ slightly from the running app. It is not evidence of hardware integration or Apple endorsement. The screenshot's DEMO label is retained.

The exact generation prompt is preserved in [media/hero-prompt.txt](media/hero-prompt.txt). The project includes this generated illustration with its MIT-licensed materials; third-party product names and trade dress remain their owners' property, and no exclusive rights to AI-generated output are claimed.

## Recorded demo

`media/demo.gif` is encoded from a real simulator video, not a sequence of generated UI mockups. It shows the deterministic demo home's thermostat, light controls and widget switching, followed by the clock, photo wall and navigation rail.

The updated recording uses three photographs supplied by the project owner specifically for this demo: fish, a museum display, and a city park fountain. They were imported into a newly created, dedicated iPad simulator, so the album contains only those three images. The original JPEG files are not included in the repository or app bundle. Their appearance in this recording does not offer the underlying photographs as reusable MIT-licensed photo assets.

The capture waits for two actual album transitions so all three photographs appear on the photo wall. The app's normal 30-second rotation and crossfade timing are unchanged. The DEMO label refers to the simulated home accessories and clock; PhotoKit reads actual image assets in the simulator.

To reproduce with your own approved photos, use a dedicated, booted iPad simulator:

```sh
xcrun simctl addmedia SIMULATOR_UUID /path/to/photo-1.jpg /path/to/photo-2.jpg /path/to/photo-3.jpg
python3 scripts/record_demo.py SIMULATOR_UUID
```

For ordinary tests, `python3 scripts/seed_test_photos.py SIMULATOR_UUID` provides non-personal gradient fixtures instead. Do not mix these with the three-photo showcase if you want the same presentation.

The script records between explicit markers in `testReadmeDemoJourney`, ends recording with SIGINT so the movie is finalized, and converts it using AVFoundation and ImageIO. The GIF loops at 12.5 fps with its longest edge bounded to 880 px. Raw recordings and test evidence remain in ignored `.validation/`. See [validation](VALIDATION.md) and the [media checksum manifest](evidence/media-manifest.json) for the final recording details.
