# Credits

HomePad is independently developed as a native iPad home dashboard, with its own interface, feature set and product direction.

## Project foundation

HomePad originated from [kuscholar/HomeViewPad](https://github.com/kuscholar/HomeViewPad). Its upstream history and MIT copyright notice are retained. The original source baseline used for this development line was `3c395111ab2a6c85e62ca763f7c156da4845b49c`.

The project continues in [atom-xu/HomeViewPad](https://github.com/atom-xu/HomeViewPad) under the HomePad name. The repository URL and historical filenames preserve that lineage; they do not define HomePad's current interface or product scope.

The [MIT license](LICENSE) covers the project code under its included notices. This documentation does not remove or replace the original copyright attribution.

## Interface and media

The current app icon is the HomePad design in `HomePad/Assets.xcassets/AppIcon.appiconset/AppIcon.png`. README screenshots show the running native HomePad interface with labeled demo accessories and synthetic music data. Sources, transformations and checksums are in [Media](docs/MEDIA.md) and its [manifest](docs/evidence/homepad-readme-media.json).

Historical logos, illustrations and recordings remain documented as historical assets. They are not used as the current project preview.

## Apple and other services

HomePad uses public Apple frameworks including SwiftUI, HomeKit, PhotoKit, MusicKit, EventKit, AVFoundation and system AirPlay controls. Apple product names, SF Symbols, services, music artwork and Aerial media retain their respective owners' rights.

Aerial metadata points to Apple's servers; selected videos download into the user's app storage. No Aerial movie is bundled in this repository, and the project's MIT license does not relicense Apple's media. Source selection and checks are documented in [Dynamic backgrounds](docs/DYNAMIC-SCREENSAVER-10.md).

Weather is provided by [Open-Meteo](https://open-meteo.com/). See [Architecture](docs/ARCHITECTURE.md) for requests and data lifecycle.

HomePad is an independent project and is not affiliated with or endorsed by Apple or Open-Meteo.
