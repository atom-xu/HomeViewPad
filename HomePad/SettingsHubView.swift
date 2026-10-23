import SwiftUI
import HomeKit
import UIKit
import CoreLocation
import Photos
import MusicKit
import EventKit
import AVFoundation

/// Dashboard retains the store instances, system photo picker,
/// import task, permission/lifecycle handlers, privacy cover and standby overlay.
/// One native title and background hierarchy serves every settings destination.
struct SettingsHubView: View {
    @ObservedObject var home: HomeStore
    @ObservedObject var display: DisplayCoordinator
    @ObservedObject var wallpaper: WallpaperStore
    @ObservedObject var photos: PhotoLibraryStore
    @ObservedObject var weather: WeatherStore
    @ObservedObject var location: WeatherLocation

    @Binding var appLanguage: String
    @Binding var tealWallpaper: Bool
    @Binding var showPersonal: Bool
    @Binding var wallpaperPickerPresented: Bool

    let connectHome: () -> Void
    let exploreDemo: () -> Void
    let disconnectHome: () -> Void
    let simulateState: (HomeStatus) -> Void
    let openPhotos: () -> Void
    let openWeather: () -> Void
    var openMusic: () -> Void = {}
    var openAgenda: () -> Void = {}
    var openCameras: () -> Void = {}
    var musicConnectionStatus = "Not connected"
    var calendarConnectionStatus = "Not connected"
    var showPageNavigation: () -> Void = {}

    @State private var path: [Destination] = []
    @State private var permissionRevision = UUID()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("musicArtworkBackground") private var musicArtworkBackground = true
    @ScaledMetric(relativeTo: .title3) private var entryIconWidth: CGFloat = 28

    private enum Destination: Hashable {
        case home, display, contentPrivacy, permissions, general, help, about, diagnostics, wake, guidedAccess

        var title: String {
            switch self {
            case .home: "Home".tr
            case .display: "Display & standby".tr
            case .contentPrivacy: "Content & permissions".tr
            case .permissions: "Permissions".tr
            case .general: "General".tr
            case .help: "Help".tr
            case .about: "About".tr
            case .diagnostics: "Advanced diagnostics".tr
            case .wake: "Return from standby".tr
            case .guidedAccess: "Dedicated iPad".tr
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            index
                .navigationTitle("Settings".tr)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { pageNavigationToolbar }
                .navigationDestination(for: Destination.self) { destination in
                    destinationContent(destination)
                        .navigationTitle(destination.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { pageNavigationToolbar }
                }
        }
        .foregroundStyle(Color.primary)
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        // Keep child IDs distinct from the settings-page container.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settingsHub")
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { permissionRevision = UUID() }
        }
    }

    private var index: some View {
        Form {
            Section {
                entry(.home, symbol: "house", summary: homeSummary, id: "settingsHome")
                entry(.display, symbol: "display", summary: DisplaySettingsView.title(for: display.screenBehaviorSelection), id: "settingsDisplay")
                entry(.contentPrivacy, symbol: "photo.on.rectangle", summary: "Photos, music and calendar".tr, id: "settingsContentPrivacy")
                entry(.general, symbol: "gearshape", summary: languageTitle, id: "settingsGeneral")
            }
            Section("Calendar, weather & permissions".tr) {
                featureEntry("Calendar", symbol: "calendar", summary: calendarConnectionStatus.tr,
                             id: "settingsCalendar", perform: openAgenda)
                featureEntry("Weather city and units", symbol: "cloud.sun", summary: weatherSummary,
                             id: "settingsWeather", perform: openWeather)
                entry(.permissions, symbol: "hand.raised", summary: "Review system access".tr, id: "settingsPermissions")
            }
            Section {
                HStack(spacing: 20) {
                    Button { path.append(.help) } label: {
                        Label("Help".tr, systemImage: "questionmark.circle")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("settingsHelp")
                    Button { path.append(.about) } label: {
                        Label("About".tr, systemImage: "info.circle")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("settingsAbout")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settingsIndex")
    }

    @ToolbarContentBuilder private var pageNavigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: showPageNavigation) {
                Label("Pages".tr, systemImage: "square.grid.2x2")
            }
            .accessibilityLabel("Switch page".tr)
            .accessibilityIdentifier("showNavigationButton")
        }
    }

    private func featureEntry(_ title: String, symbol: String, summary: String, id: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 16) {
                Image(systemName: symbol).font(.title3).frame(width: entryIconWidth).foregroundStyle(Color.accentColor)
                Text(title.tr).font(.headline)
                Spacer(minLength: 12)
                Text(summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary).accessibilityHidden(true)
            }.frame(maxWidth: .infinity, minHeight: 56, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }

    private func entry(_ destination: Destination, symbol: String, summary: String, id: String) -> some View {
        Button { path.append(destination) } label: {
            HStack(spacing: 16) {
                Image(systemName: symbol).font(.title3).frame(width: entryIconWidth)
                    .foregroundStyle(Color.accentColor)
                Text(destination.title).font(.headline)
                Spacer(minLength: 12)
                Text(summary).font(.subheadline).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.tail)
                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private var homeSummary: String {
        if home.demo { return "Demo mode — sample data only".tr }
        if home.selectedHomeID != nil { return home.homeName }
        return homeConnectionStatus
    }

    private var weatherSummary: String {
        let city = weather.demo ? "DEMO".tr : weather.city?.displayName ?? "Choose a city".tr
        return city + " · " + (weather.fahrenheit ? "°F" : "°C")
    }

    private var languageTitle: String {
        (AppLanguage(rawValue: appLanguage) ?? .system).title
    }

    @ViewBuilder private func destinationContent(_ destination: Destination) -> some View {
        switch destination {
        case .home: homeSettings
        case .display: displaySettings
        case .contentPrivacy: contentPrivacySettings
        case .permissions: permissionSettings
        case .general: generalSettings
        case .help: helpSettings
        case .about: aboutSettings
        case .diagnostics: diagnosticsSettings
        // Wake and Guided Access are complete Forms.
        // They are complete Forms, so do not wrap them in another Form.
        case .wake: WakeSettingsView(coordinator: display)
        case .guidedAccess: GuidedAccessHelpView()
        }
    }

    private var homeSettings: some View {
        Form {
            Section("Current home".tr) {
                LabeledContent("Selected home".tr, value: home.demo ? "Demo mode — sample data only".tr : home.selectedHomeID == nil ? "No home selected".tr : home.homeName)
                    .accessibilityIdentifier("settingsSelectedHome")
                Text(homeConnectionStatus).foregroundStyle(.secondary)
                    .accessibilityIdentifier("settingsHomeConnectionStatus")
                if home.demo {
                    action("Connect Apple Home", id: "connectHome", perform: connectHome)
                    action("Leave demo", id: "disconnectHome", role: .destructive, perform: disconnectHome)
                } else if home.status == .loading {
                    ProgressView("Connecting…".tr)
                    action("Cancel", id: "disconnectHome", perform: disconnectHome)
                } else {
                    if home.selectedHomeID != nil {
                        action("Refresh home", id: "refreshHome") { home.refresh() }
                    } else {
                        action("Connect Apple Home", id: "connectHome", perform: connectHome)
                    }
                    if home.status == .denied {
                        action("Open iPad permission settings", id: "homePermissionSettings", perform: openPermissionSettings)
                    }
                    if home.status != .welcome {
                        action("Disconnect home", id: "disconnectHome", role: .destructive, perform: disconnectHome)
                    }
                }
            }
            if !home.demo && !home.homes.isEmpty {
                Section {
                    ForEach(home.homes, id: \.uniqueIdentifier) { item in
                        Button { home.select(item) } label: {
                            HStack {
                                // A household's own name is never translated.
                                Text(item.name)
                                Spacer()
                                if home.selectedHomeID == item.uniqueIdentifier {
                                    Image(systemName: "checkmark").accessibilityHidden(true)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(home.selectedHomeID == item.uniqueIdentifier ? "Selected".tr : "")
                        .accessibilityAddTraits(home.selectedHomeID == item.uniqueIdentifier ? .isSelected : [])
                        .accessibilityIdentifier("selectHome-\(item.uniqueIdentifier.uuidString)")
                    }
                } header: {
                    Text("Choose a home".tr)
                } footer: {
                    Text("These are the homes shared with your Apple Account in Apple's Home app.".tr)
                }
            }
            Section {
                Text("Home access lets HomePad show and control accessories and view compatible home cameras. Add homes, people and devices in Apple's Home app.".tr)
                    .font(.footnote).foregroundStyle(.secondary)
                if !home.demo && home.selectedHomeID != nil {
                    action("Choose a home camera", id: "homeCameraSettings", perform: openCameras)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settingsHomePage")
    }

    private var displaySettings: some View {
        Form {
            DisplaySettingsView(coordinator: display, openPhotos: openPhotos)
            Section {
                destinationRow(.wake, title: "Return from standby", symbol: "hand.tap", id: "settingsWake")
            }
            WallpaperSettings(wallpaper: wallpaper, isPresented: $wallpaperPickerPresented)
            Section("Default background".tr) {
                HStack(alignment: .top, spacing: 16) {
                    defaultBackgroundChoice(teal: false, title: "Warm gray", id: "wallpaperDefault-warmGray")
                    defaultBackgroundChoice(teal: true, title: "Teal", id: "wallpaperDefault-teal")
                }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("tealWallpaper")
                if wallpaper.image != nil {
                    Text("Your photo is the current background. Choosing a color replaces the background photo.".tr)
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Music artwork".tr) {
                Toggle("Use playing artwork as the background".tr, isOn: $musicArtworkBackground)
                    .accessibilityIdentifier("musicArtworkBackground")
                Text("While Apple Music is playing, its artwork appears behind Home and Clock. Pausing restores your chosen background. The Photos page stays separate.".tr)
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settingsDisplayPage")
    }

    private func defaultBackgroundChoice(teal: Bool, title: String, id: String) -> some View {
        let selected = wallpaper.image == nil && tealWallpaper == teal
        return Button {
            tealWallpaper = teal
            wallpaper.clear()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                AmbientWallpaper(teal: teal)
                    .frame(height: 90).clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                HStack {
                    Text(title.tr)
                    Spacer()
                    if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor) }
                }
            }
            .padding(10).frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2) }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityValue(selected ? "Selected".tr : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    private var contentPrivacySettings: some View {
        Form {
            Section("Photos".tr) {
                Text(photos.displayAlbumTitle).foregroundStyle(.secondary)
                    .accessibilityIdentifier("settingsPhotosStatus")
                if let message = photos.message { Text(message.tr).font(.footnote).foregroundStyle(.secondary) }
                action("Choose photos and albums", id: "photoSettings", perform: openPhotos)
                Text("Choose the photos and albums for the Photos page and photo wall. Home and Clock background photos are selected separately under Display & standby.".tr)
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Apple Music".tr) {
                LabeledContent("Connection".tr, value: musicConnectionStatus.tr)
                    .accessibilityIdentifier("settingsMusicStatus")
                LabeledContent("System permission".tr, value: musicPermission)
                action("Open music and connect", id: "musicSettings", perform: openMusic)
                Text("Music access is requested when you connect. Playback availability depends on your Apple Music account.".tr)
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Calendar".tr) {
                LabeledContent("Connection".tr, value: calendarConnectionStatus.tr)
                    .accessibilityIdentifier("settingsCalendarStatus")
                LabeledContent("System permission".tr, value: calendarPermission)
                action("Open calendar", id: "calendarSettings", perform: openAgenda)
                Toggle("Show calendar on this shared screen".tr, isOn: $showPersonal)
                    .accessibilityIdentifier("showPersonal")
                Text("Anyone looking at this iPad can see displayed events. Connecting asks for calendar access; turning this switch off hides events and clears them from HomePad.".tr)
                    .font(.footnote).foregroundStyle(.secondary)
                // Dashboard keeps the showPersonal=false handler that clears
                // PersonalStore and invalidates pending loads. Turning it on
                // alone does not request system permission.
            }
            Section("Home cameras".tr) {
                Text(home.demo ? "Demo mode — sample data only".tr : home.selectedHomeID == nil ? "Connect Apple Home first".tr : L10n.format("%lld home cameras available", home.cameras.count))
                    .foregroundStyle(.secondary).accessibilityIdentifier("settingsCameraStatus")
                action("Choose a home camera", id: "cameraSettings", perform: openCameras)
                Text("Uses Apple Home access to view a compatible camera. This is separate from using this iPad's front camera to wake the standby screen.".tr)
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Weather".tr) {
                if weather.demo {
                    Text("DEMO · Fixed sample weather. Leave demo mode in Settings to use live weather.".tr)
                        .foregroundStyle(.secondary)
                } else {
                    Text(weather.city?.displayName ?? "Weather city and units".tr)
                        .foregroundStyle(.secondary).accessibilityIdentifier("settingsWeatherStatus")
                }
                // Keep panel=.weather so forecast refresh retains its visibility rules.
                // Location is a separate explicit one-shot action in WeatherPanel.
                action("Weather city and units", id: "weatherSettings", perform: openWeather)
            }
            Section("Permissions".tr) {
                Text("Connection status and system permission are separate. Review access here, or change it in iPad Settings.".tr)
                    .font(.footnote).foregroundStyle(.secondary)
                destinationRow(.permissions, title: "Review permissions", symbol: "hand.raised", id: "reviewPermissions")
                action("Open iPad permission settings", id: "appPermissionSettings", perform: openPermissionSettings)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settingsContentPrivacyPage")
    }

    private var permissionSettings: some View {
        Form {
            Section {
                Text("Connection status and system permission are separate. Review access here, or change it in iPad Settings.".tr)
                    .font(.callout)
                LabeledContent("Photos".tr, value: photoPermission).accessibilityIdentifier("permissionPhotos")
                LabeledContent("Apple Music".tr, value: musicPermission).accessibilityIdentifier("permissionMusic")
                LabeledContent("Calendar".tr, value: calendarPermission).accessibilityIdentifier("permissionCalendar")
                LabeledContent("Front camera".tr, value: frontCameraPermission).accessibilityIdentifier("permissionCamera")
                LabeledContent("Location".tr, value: locationPermission).accessibilityIdentifier("permissionLocation")
            } header: {
                Text("System access".tr)
            } footer: {
                Text("Access is requested only when you connect or enable a feature. Turn it off at any time in iPad Settings.".tr)
            }
            Section("Apple Home".tr) {
                Text(home.demo ? "Demo mode — sample data only".tr : home.status == .denied ? "Home access is off. Allow HomePad in iPad Settings, then connect again.".tr : "Home access is checked when connecting. Homes and cameras are managed in Apple's Home app.".tr)
                    .foregroundStyle(.secondary)
                action("Choose a home", id: "permissionHome") { path.append(.home) }
            }
            Section("Weather".tr) {
                Text("A chosen city does not need location access. To set it from your location once, open Weather and choose Locate once.".tr)
                    .foregroundStyle(.secondary)
                action("Weather city and units", id: "permissionWeather", perform: openWeather)
            }
            Section {
                action("Open iPad permission settings", id: "appPermissionSettings", perform: openPermissionSettings)
                Text("Photo access is for albums and the photo wall. A background photo can be chosen separately without full photo-library access. Calendar reading requires full calendar access.".tr)
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .id(permissionRevision)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settingsPermissionsPage")
    }

    private var locationPermission: String {
        // Passive process-wide status only; never create a manager or prompt.
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse: return "Allowed".tr
        case .denied: return "Not allowed".tr
        case .restricted: return "Restricted".tr
        case .notDetermined: return "Not requested".tr
        @unknown default: return "Unavailable".tr
        }
    }

    private var photoPermission: String {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized: return "Allowed".tr
        case .limited: return "Selected photos only".tr
        case .denied: return "Not allowed".tr
        case .restricted: return "Restricted".tr
        case .notDetermined: return "Not requested".tr
        @unknown default: return "Unavailable".tr
        }
    }

    private var musicPermission: String {
        switch MusicAuthorization.currentStatus {
        case .authorized: return "Allowed".tr
        case .denied: return "Not allowed".tr
        case .restricted: return "Restricted".tr
        case .notDetermined: return "Not requested".tr
        @unknown default: return "Unavailable".tr
        }
    }

    private var calendarPermission: String {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return "Full access".tr
        case .writeOnly: return "Add events only".tr
        case .denied: return "Not allowed".tr
        case .restricted: return "Restricted".tr
        case .notDetermined: return "Not requested".tr
        @unknown default: return "Unavailable".tr
        }
    }

    private var frontCameraPermission: String {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return "Allowed".tr
        case .denied: return "Not allowed".tr
        case .restricted: return "Restricted".tr
        case .notDetermined: return "Not requested".tr
        @unknown default: return "Unavailable".tr
        }
    }

    private var generalSettings: some View {
        Form {
            Section("Language".tr) {
                Picker("App language".tr, selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in Text(language.title).tag(language.rawValue) }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("appLanguagePicker")
            }
            if home.demo {
                Section {
                    destinationRow(.diagnostics, title: "Advanced diagnostics", symbol: "stethoscope", id: "advancedDiagnostics")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settingsGeneralPage")
    }

    private var diagnosticsSettings: some View {
        Form {
            if home.demo {
                Section("Demo diagnostics".tr) {
                    ForEach([HomeStatus.ready, .loading, .denied, .empty, .offline], id: \.self) { state in
                        Button { simulateState(state) } label: {
                            rowLabel(L10n.format("Simulate %@", state.title))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityIdentifier("simulate-\(state.rawValue)")
                    }
                }
            } else {
                Section {
                    Text("Diagnostics are available in demo mode only.".tr).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settingsDiagnosticsPage")
    }

    private var helpSettings: some View {
        Form {
            Section("Dedicated iPad".tr) {
                destinationRow(.guidedAccess, title: "Guided Access setup", symbol: "lock.rectangle", id: "guidedAccessTutorial")
            }
            Section("Navigation and widgets".tr) {
                Text("Touch and hold a widget to show navigation, change category items, resize or remove it. Swipe left or right to change pages, and scroll vertically when widgets overflow. VoiceOver offers the same actions.".tr)
                    .font(.callout)
            }
            Section("Display and lock screen".tr) {
                Text("Does not replace the lock screen or reopen the app after reboot. Use Guided Access in iPad Settings if appropriate. Automatic display features work only while this app remains open.".tr)
                    .font(.callout)
            }
            Section("HomePod mini".tr) {
                Text("Add HomePod mini to the same home in Apple's Home app. It provides supported home hub, Thread and Siri functions independently. Choose it through AirPlay for audio. HomePad cannot access its microphone, host Siri, or send Intercom messages.".tr)
                    .font(.callout)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settingsHelpPage")
    }

    private var aboutSettings: some View {
        Form {
            Section("About".tr) {
                Text("HomePad · Independent open-source iPad dashboard\nNo analytics. No accounts. No server.\nNot affiliated with Apple.".tr)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settingsAboutPage")
    }

    private var homeConnectionStatus: String {
        if home.demo { return "Demo mode — sample data only".tr }
        switch home.status {
        case .welcome: return "Not connected".tr
        case .loading: return "Connecting…".tr
        case .ready: return "Connected to Apple Home".tr
        case .denied: return "Home access is off. Allow HomePad in iPad Settings, then connect again.".tr
        case .empty:
            return (home.selectedHomeID == nil
                    ? "No home found. Add a home in Apple's Home app, then connect again."
                    : "This home has no accessories yet. Add them in Apple's Home app.").tr
        case .offline: return "Home is unavailable. Check Wi-Fi and your home devices, then try again.".tr
        }
    }

    private func openPermissionSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func action(_ key: String, id: String, role: ButtonRole? = nil, perform: @escaping () -> Void) -> some View {
        Button(role: role, action: perform) { rowLabel(key.tr) }
            .buttonStyle(.plain)
            .foregroundStyle(role == .destructive ? Color.red : Color.accentColor)
            .accessibilityIdentifier(id)
    }

    private func rowLabel(_ title: String) -> some View {
        Text(title).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
    }

    private func destinationRow(_ destination: Destination, title: String, symbol: String, id: String) -> some View {
        Button { path.append(destination) } label: {
            HStack {
                Label(title.tr, systemImage: symbol)
                Spacer()
                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary).accessibilityHidden(true)
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }
}
