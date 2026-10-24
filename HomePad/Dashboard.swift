import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import HomeKit
import os

/// Opt-in signposts for reproducible performance recordings, never user data.
enum HomePadPerformanceTrace {
    private static let log = OSLog(subsystem: "org.homepad.performance", category: .pointsOfInterest)
    private static let enabled: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--uitesting") && ProcessInfo.processInfo.arguments.contains("--performance-audit")
        #else
        return false
        #endif
    }()
    static func event(_ name: StaticString) {
        if enabled { os_signpost(.event, log: log, name: name) }
    }
}

private let ink = Color(red: 0.36, green: 0.35, blue: 0.39)
private let lavender = Color(red: 0.78, green: 0.76, blue: 0.88)
private let paper = Color.white

private struct MusicWidgetFrameKey: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

enum Panel: String, Identifiable { case settings, music, agenda, camera, controls, photos, accessory, weather, shortcut, widget, layout; var id: String { rawValue } }
enum HomeShortcutKind: String, CaseIterable, Codable, Identifiable {
    case camera, scene, agenda, music, controls
    var id: String { rawValue }
    var title: String {
        switch self {
        case .camera: "Camera".tr
        case .scene: "Scene".tr
        case .agenda: "Today".tr
        case .music: "Music".tr
        case .controls: "Controls".tr
        }
    }
    var symbol: String {
        switch self {
        case .camera: "video.fill"
        case .scene: "sun.max.fill"
        case .agenda: "calendar"
        case .music: "music.note"
        case .controls: "switch.2"
        }
    }
}
struct HomeShortcut: Codable, Identifiable {
    var id: String
    var kind: HomeShortcutKind
    var target: String?
    var name: String = ""
    var homeID: String? = nil
    func belongs(to currentHomeID: String?) -> Bool {
        let requiresHome = kind == .scene || (kind == .camera && target != nil)
        if requiresHome { return homeID != nil && currentHomeID != nil && homeID == currentHomeID }
        return homeID == nil || homeID == currentHomeID
    }
    static let defaults = [HomeShortcut(id: "camera", kind: .camera), HomeShortcut(id: "music", kind: .music), HomeShortcut(id: "controls", kind: .controls)]
}
struct Dashboard: View {
    @StateObject private var configurationCache = HomeConfigurationCache()
    @StateObject private var home = HomeStore()
    @StateObject private var display = DisplayCoordinator()
    @StateObject private var agendaStore = AgendaStore()
    @StateObject private var music = MusicStore(client: musicValidationClientIfRequested())
    @StateObject private var audio = AudioStore()
    @StateObject private var cameraSnapshots = CameraSnapshotStore()
    @State private var musicNavigation = MusicNavigationState()
    @StateObject private var photos = PhotoLibraryStore()
    @StateObject private var wallpaper = WallpaperStore()
    @StateObject private var aerial = makeAerialStore()
    @StateObject private var weatherLocation = WeatherLocation()
    @StateObject private var weather = WeatherStore(demo: ProcessInfo.processInfo.arguments.contains("--demo") || (!ProcessInfo.processInfo.arguments.contains("--fresh") && UserDefaults.standard.string(forKey: "homeMode") == "demo"))
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("appLanguage") private var appLanguage = "system"
    @AppStorage("homeWidgetLayouts") private var widgetLayoutsData = ""
    @AppStorage("homeShortcuts") private var shortcutsData = ""
    @AppStorage("musicArtworkBackground") private var musicArtworkBackground = true
    @AppStorage("tealWallpaper") private var tealWallpaper = false
    @AppStorage("keepAwake") private var keepAwake = false
    @AppStorage("showPersonal") private var showPersonal = false
    @AppStorage("display.standbyContent") private var standbyContent = "clock"
    @State private var didConfigure = false
    @State private var page = DashboardPage.home
    @State private var navigationVisible = false
    @State private var pageForward = true
    @State private var widgetOffsets = Array(repeating: 0, count: 6)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var panel: Panel?
    @State private var sceneToRun: String?
    @State private var selectedCamera: HMAccessory?
    @State private var selectedAccessoryID: UUID?
    @State private var wallpaperPickerPresented = false
    @State private var musicPickerPresented = false
    @State private var airPlayPresented = false
    @State private var homeRefreshOnResume = false
    @State private var musicWidgetFrames: [CGRect] = []
    @State private var wallpaperItem: PhotosPickerItem?
    @State private var pendingWidgetReveal: String?
    @State private var highlightedWidget: String?
    @State private var restoreConfirmation = false
    @State private var editingShortcutID: String?
    @State private var shortcutKind = HomeShortcutKind.camera
    @State private var shortcutTarget = ""
    @State private var shortcutName = ""
    @State private var editingShortcuts = false
    private var musicDemo: Bool { home.demo && !music.isValidationFixture }
    private var demoDate: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 10, minute: 9, second: 30))!
    }
    private var musicArtworkVisible: Bool {
        MusicArtworkBackdropPolicy.shows(on: page, enabled: musicArtworkBackground && !musicDemo && music.state == .ready,
                                         playing: music.nowPlaying?.playing == true,
                                         hasArtwork: music.nowPlaying?.artwork != nil || (music.isValidationFixture && music.nowPlaying != nil),
                                         localFileSelected: audio.hasFile)
    }
    private var aerialVisible: Bool {
        let clockStandby = display.isStandby && !display.standbyKeepsCurrentPage && standbyContent != "photos"
        let pageShowsBackground = (!display.isStandby || display.standbyKeepsCurrentPage) && (page == .home || page == .clock)
        return phase == .active && panel == nil && !wallpaperPickerPresented && !navigationVisible && !musicArtworkVisible
            && (clockStandby || pageShowsBackground)
    }
    private func updateAerialPresentation() {
        aerial.setPresentation(visible: aerialVisible, reducedMotion: reduceMotion, deterministic: home.demo)
    }
    private var dashboardSurface: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            ZStack {
                Group {
                    if musicArtworkVisible {
                        MusicPageBackdrop(artwork: music.nowPlaying?.artwork, trackID: music.nowPlaying?.id, fixture: music.isValidationFixture)
                            .transition(.opacity)
                    } else if aerial.enabled {
                        AerialWallpaperView(aerial: aerial)
                    } else if let image = wallpaper.image {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                            .accessibilityLabel("Wallpaper".tr).accessibilityValue(wallpaper.accessibilityValue)
                            .accessibilityIdentifier("customWallpaper")
                    } else { AmbientWallpaper(teal: tealWallpaper) }
                }.ignoresSafeArea().allowsHitTesting(false)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: tealWallpaper)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: musicArtworkVisible)
                Color.black.opacity(display.nightActive ? 0.45 : 0).ignoresSafeArea().allowsHitTesting(false)
                // Only uncovered wallpaper receives taps. Widget taps retain their own actions.
                Color.clear.contentShape(Rectangle())
                    .onTapGesture(perform: toggleNavigation)
                    .accessibilityLabel("Show navigation".tr).accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("navigationBackdrop").accessibilityHidden(display.isStandby)
                ZStack {
                    Group {
                        if page == .photos {
                            PhotoWall(photos: photos, demoDate: home.demo ? demoDate : nil, navigationVisible: navigationVisible,
                                      chooseAlbum: { panel = .photos }, showNavigation: toggleNavigation)
                        } else { pageContent(size: geometry.size) }
                    }.frame(width: geometry.size.width, height: geometry.size.height)
                        .id(page).transition(pageTransition)
                }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
                    .opacity(display.isStandby && !display.standbyKeepsCurrentPage ? 0 : 1)
                    .accessibilityHidden(display.isStandby)
                    .accessibilityAction(named: "Show navigation".tr) { withAnimation(navigationAnimation) { navigationVisible = true } }
                    .accessibilityAction(named: "Next page".tr) { movePage(forward: true) }
                    .accessibilityAction(named: "Previous page".tr) { movePage(forward: false) }
                if navigationVisible && !display.isStandby {
                    if landscape {
                        HStack {
                            Spacer(minLength: 0)
                            navigationRail.frame(width: 142).frame(maxHeight: geometry.size.height - 28)
                        }.padding(.trailing, 14)
                            .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                    } else {
                        VStack {
                            Spacer(minLength: 0)
                            bottomNavigation.frame(maxWidth: 760).padding(.horizontal, 16).padding(.bottom, max(18, geometry.safeAreaInsets.bottom))
                        }.transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }
                }
                if !navigationVisible && page != .home && page != .settings && page != .music && !display.isStandby {
                    VStack { HStack { Spacer(); showNavigationButton }; Spacer() }.padding(24)
                }
                if display.isStandby {
                    Group {
                        if display.standbyKeepsCurrentPage {
                            // The first touch belongs solely to waking, never
                            // to a HomeKit or playback control underneath it.
                            Button { display.noteInteraction() } label: {
                                Color.black.opacity(display.nightActive ? 0.5 : 0.2)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
                            }.buttonStyle(.plain).ignoresSafeArea()
                                .accessibilityLabel("Touch to restore brightness".tr)
                                .accessibilityIdentifier("standbyCurrentPageWake")
                        } else if standbyContent == "photos" {
                            PhotoWall(photos: photos, demoDate: home.demo ? demoDate : nil, navigationVisible: false,
                                      chooseAlbum: { display.noteInteraction() }, showNavigation: { display.noteInteraction() }, standby: true)
                        } else { StandbyDisplayView(coordinator: display, demoDate: home.demo ? demoDate : nil) }
                    }.transition(.opacity).zIndex(10)
                }
            }.foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .simultaneousGesture(TapGesture().onEnded { display.noteInteraction() })
                .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { _ in display.noteInteraction() })
                .simultaneousGesture(DragGesture(minimumDistance: 30, coordinateSpace: .global).onEnded { value in
                    guard !display.isStandby else { return }
                    guard music.state != .ready || !musicWidgetFrames.contains(where: { $0.contains(value.startLocation) }) else { return }
                    guard page != .music, panel != .music else { return }
                    switch DashboardSwipe.classify(x: value.translation.width, y: value.translation.height) {
                    case .left: movePage(forward: true)
                    case .right: movePage(forward: false)
                    default: break
                    }
                // Music owns its gesture sequence. Disabling root paging at
                // recognition avoids a second page change after Music's onEnded.
                // A standby drag only wakes; activity tracking remains separate.
                }, including: page == .music || panel == .music || display.isStandby ? .subviews : .all)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task { await wallpaper.restore() }
        .onChange(of: aerialVisible, initial: true) { _, _ in updateAerialPresentation() }
        .onChange(of: reduceMotion) { _, _ in updateAerialPresentation() }
        .onPreferenceChange(MusicWidgetFrameKey.self) { musicWidgetFrames = $0 }
        .overlay { if phase == .background || (phase == .inactive && !airPlayPresented) { paper.ignoresSafeArea().overlay { Label("HomePad".tr, systemImage: "house.fill").font(.largeTitle).foregroundStyle(ink) } } }
        .preferredColorScheme(display.nightActive ? .dark : .light)
        .environment(\.locale, AppLanguage(rawValue: appLanguage)?.locale ?? .current)
        .onDisappear { display.setActive(false); cameraSnapshots.setAccess(allowed: false); aerial.setForeground(false) }
    }
    private var presentedDashboard: some View {
        dashboardSurface
        .photosPicker(isPresented: $wallpaperPickerPresented, selection: $wallpaperItem, matching: .images)
        .task(id: wallpaperItem) {
            guard let wallpaperItem else { return }
            if await wallpaper.importPhoto(wallpaperItem) { aerial.useStaticBackground() }
            if !Task.isCancelled { self.wallpaperItem = nil }
        }
        .sheet(item: $panel) { panel in
            NavigationStack {
                panelContent(panel).navigationTitle(panel == .accessory ? "" : panel == .layout ? "Edit Home".tr : panel.rawValue.capitalized.tr)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done".tr) { self.panel = nil }.accessibilityIdentifier("dismissPanel") } }
            }.foregroundStyle(panel == .accessory ? Color.white : Color.primary)
                .preferredColorScheme(panel == .accessory ? .dark : nil)
                .presentationBackground(panel == .accessory ? .ultraThinMaterial : .regularMaterial)
                .modifier(SceneConfirmation(name: $sceneToRun, enabled: true, demo: home.demo, run: home.runScene))
                .overlay { if phase == .background || (phase == .inactive && !airPlayPresented) { paper.ignoresSafeArea().overlay { Text("HomePad".tr).font(.largeTitle) } } }.presentationDetents([.large])
        }
        .confirmationDialog("Restore default widgets?".tr, isPresented: Binding(get: { restoreConfirmation && panel == nil }, set: { restoreConfirmation = $0 }), titleVisibility: .visible) {
            Button("Restore layout".tr, role: .destructive) { saveWidgets(HomeWidgetConfiguration.defaults); widgetOffsets = Array(repeating: 0, count: 6) }.accessibilityIdentifier("confirmRestoreWidgets")
            Button("Cancel".tr, role: .cancel) {}
        } message: { Text("This replaces the left column layout. Right column cards are kept.".tr) }
        .modifier(SceneConfirmation(name: $sceneToRun, enabled: panel == nil, demo: home.demo, run: home.runScene))
        .alert("Home needs attention".tr, isPresented: Binding(get: { home.error != nil }, set: { if !$0 { home.error = nil } })) { Button("OK".tr) { home.error = nil } } message: { Text(home.error ?? "") }
    }
    private var configuredDashboard: some View {
        presentedDashboard
        .task {
            guard !didConfigure else { return }
            didConfigure = true
            if ProcessInfo.processInfo.arguments.contains("--uitesting") { tealWallpaper = false }
            photos.restore()
            migrateLegacyWidgets()
            if ProcessInfo.processInfo.arguments.contains("--demo") {
                let args = ProcessInfo.processInfo.arguments
                let state = args.firstIndex(of: "--state").flatMap { $0 + 1 < args.count ? HomeStatus(rawValue: args[$0 + 1]) : nil } ?? .ready
                home.startDemo(state: state)
                #if DEBUG
                if args.contains("--uitesting") && args.contains("--home-legacy-fixture") {
                    widgetLayoutsData = #"{"demo":[{"id":"old-camera","kind":"camera","target":"first-available","size":"large"},{"id":"old-calendar","kind":"agenda","size":"small"},{"id":"old-clock","kind":"clock","size":"small"}]}"#
                    shortcutsData = ""
                    migrateLegacyWidgets()
                }
                if args.contains("--uitesting") && args.contains("--home-controls-fixture") {
                    home.configureControlValidation(offline: args.contains("--home-offline-fixture"))
                }
                if args.contains("--uitesting") && args.contains("--homekit-coverage-fixture") {
                    home.configureHomeKitValidation()
                    let favorites = home.primaryTiles.prefix(6).map {
                        HomeWidgetConfiguration(id: "fixture-\($0.name)", kind: .accessory, target: $0.id.uuidString, size: .small)
                    }
                    saveWidgets(favorites)
                }
                #endif
            } else if !ProcessInfo.processInfo.arguments.contains("--fresh") {
                let mode = UserDefaults.standard.string(forKey: "homeMode")
                if mode == "demo" { home.startDemo() } else if mode == "live" { home.connect() }
            }
            updateCameraAccess()
            display.setKeepAwake(keepAwake)
            display.setActive(phase == .active)
            aerial.setForeground(phase == .active)
            weather.setDemo(home.demo)
            music.setDemo(musicDemo); music.setActive(phase == .active)
            music.open()
            agendaStore.setDemo(home.demo); agendaStore.setEnabled(showPersonal); agendaStore.setActive(phase == .active)
            if ProcessInfo.processInfo.arguments.contains("--far") { page = .clock }
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "--page"), index + 1 < args.count,
               let raw = Int(args[index + 1]), let requested = DashboardPage(rawValue: raw) { page = requested }
            if args.contains("--standby-preview") { display.previewStandby() }
        }
        .task(id: phase == .active && photoPresentationVisible && panel == nil && photos.slideshow) {
            guard phase == .active, photoPresentationVisible, panel == nil, photos.slideshow else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                photos.next()
            }
        }
        .task(id: "\(phase == .active)-\(home.demo)-\(page == .overview || panel == .weather)-\(weather.city?.latitude ?? 0)-\(weather.city?.longitude ?? 0)") {
            guard phase == .active, !home.demo, page == .overview || panel == .weather else { return }
            while !Task.isCancelled {
                await weather.refresh()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
    }
    var body: some View {
        let _ = HomePadPerformanceTrace.event("DashboardBody")
        configuredDashboard
        .onChange(of: showPersonal) { _, value in agendaStore.setEnabled(value) }
        .onChange(of: appLanguage) { _, _ in
            if !home.demo && home.status == .ready { home.refresh(read: false) }
        }
        .onChange(of: keepAwake) { _, value in display.setKeepAwake(value) }
        .onChange(of: wallpaperPickerPresented) { _, value in
            display.noteInteraction()
            updatePresentationSuspension()
        }
        .onChange(of: panel) { _, value in
            display.noteInteraction()
            updatePresentationSuspension()
        }
        .onChange(of: navigationVisible) { _, value in
            display.noteInteraction()
            updatePresentationSuspension()
        }
        .onChange(of: sceneToRun) { _, value in
            display.noteInteraction()
            updatePresentationSuspension()
        }
        .onChange(of: home.error) { _, value in
            display.noteInteraction()
            updatePresentationSuspension()
        }
        .onChange(of: musicPickerPresented) { _, _ in display.noteInteraction(); updatePresentationSuspension() }
        .onChange(of: airPlayPresented) { _, _ in display.noteInteraction(); updatePresentationSuspension() }
        .onChange(of: phase) { _, value in
            aerial.setForeground(value == .active)
            weatherLocation.setScenePhase(value)
            display.setActive(value == .active)
            photos.setActive(value == .active)
            agendaStore.setActive(value == .active)
            music.setScenePhase(value, routePickerPresented: airPlayPresented)
            updateCameraAccess()
            if value == .active {
                if homeRefreshOnResume { home.refresh() }
                homeRefreshOnResume = false
            } else if value == .background || !airPlayPresented {
                homeRefreshOnResume = true
                musicNavigation.reset(); audio.pause(); navigationVisible = false
            }
        }
        .onChange(of: home.status) { _, value in
            updateCameraAccess()
            if !home.demo && value != .ready && panel == .camera { panel = nil; selectedCamera = nil }
        }
        .onChange(of: widgetNamespace) { _, _ in migrateLegacyWidgets(); pendingWidgetReveal = nil; highlightedWidget = nil }
        .onChange(of: home.homeName) { _, _ in widgetOffsets = Array(repeating: 0, count: 6) }
        .onChange(of: home.selectedHomeID) { _, _ in
            cameraSnapshots.clear(); updateCameraAccess()
            widgetOffsets = Array(repeating: 0, count: 6); selectedAccessoryID = nil; sceneToRun = nil
            if panel == .accessory || panel == .camera { panel = nil; selectedCamera = nil }
        }
        .onChange(of: music.state) { _, state in
            if state == .disconnected || state == .denied || state == .restricted { musicNavigation.reset() }
        }
        .onChange(of: home.demo) { _, value in
            updateAerialPresentation()
            updateCameraAccess()
            musicNavigation.reset()
            weather.setDemo(value); music.setDemo(musicDemo); agendaStore.setDemo(value)
            if value { weatherLocation.stop() }
            widgetOffsets = Array(repeating: 0, count: 6); audio.stop()
        }
    }
    private var photoPresentationVisible: Bool {
        if display.isStandby && !display.standbyKeepsCurrentPage { return standbyContent == "photos" }
        return page == .overview || page == .photos
    }
    private func updatePresentationSuspension() {
        display.setPresentationSuspended(panel != nil || wallpaperPickerPresented || musicPickerPresented || airPlayPresented || navigationVisible || sceneToRun != nil || home.error != nil)
    }
    private func updateCameraAccess() {
        cameraSnapshots.setAccess(allowed: phase == .active && !home.demo && home.status == .ready)
    }
    private func activate(_ tile: HomeTile) {
        if let target = home.quickToggle(for: tile) { home.toggle(target) }
        else { selectedAccessoryID = tile.id; panel = .accessory }
    }
    private var visibleTiles: [HomeTile] { home.primaryTiles }
    private var navigationAnimation: Animation { reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.46, bounce: 0.06) }
    private var pageTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(insertion: .move(edge: pageForward ? .trailing : .leading).combined(with: .opacity),
                           removal: .move(edge: pageForward ? .leading : .trailing).combined(with: .opacity))
    }
    private func toggleNavigation() { display.noteInteraction(); withAnimation(navigationAnimation) { navigationVisible.toggle() } }
    private func showMusicPageNavigation() {
        panel = nil
        display.noteInteraction()
        withAnimation(navigationAnimation) { navigationVisible = true }
    }
    private func moveMusicPage(forward: Bool) {
        guard page == .music, panel == nil, !display.isStandby, !navigationVisible,
              !musicPickerPresented, !airPlayPresented else { return }
        movePage(forward: forward)
    }
    private func selectPage(_ destination: DashboardPage) {
        display.noteInteraction()
        pageForward = destination.position >= page.position
        withAnimation(navigationAnimation) { page = destination; navigationVisible = false }
    }
    private func movePage(forward: Bool) { selectPage(page.adjacent(forward: forward)) }
    @ViewBuilder private func pageContent(size: CGSize) -> some View {
        let side = max(1, min(size.width, size.height) - 16)
        switch page {
        case .home:
            ZStack {
                if home.keepsDashboard { homeDashboard(size: size) }
                else {
                    VStack(spacing: 0) {
                        dashboardHeader(title: "Home", subtitle: "Your home, at a glance")
                        ScrollView {
                            VStack {
                                if home.status == .welcome { welcome } else { stateCard }
                            }.padding(24).frame(maxWidth: 900)
                        }
                    }
                }
            }.frame(width: size.width, height: size.height)
                .accessibilityElement(children: .contain).accessibilityIdentifier("homePage")
        case .overview:
            OverviewBoard(photos: photos, weather: weather, demoDate: home.demo ? demoDate : nil, side: side, chooseAlbum: { panel = .photos }, configureWeather: { panel = .weather })
                // The black gutters and square board are one opaque page. A
                // separate backdrop can fade independently during a page swipe.
                .frame(width: size.width, height: size.height)
                .background { Color.black.allowsHitTesting(false) }
                .compositingGroup()
                .accessibilityElement(children: .contain).accessibilityIdentifier("overviewBoard")
        case .clock:
            fullScreenClock(size: size)
        case .photos: EmptyView()
        case .music:
            MusicPage(store: music, audio: audio, demo: musicDemo, navigation: $musicNavigation, showPageNavigation: showMusicPageNavigation, changePage: moveMusicPage, presentationChanged: { musicPickerPresented = $0 }, airPlayPresentationChanged: { airPlayPresented = $0 })
                .foregroundStyle(Color.primary).background(.regularMaterial)
        case .settings:
            settings.frame(width: size.width, height: size.height).foregroundStyle(Color.primary)
                .background(Color(uiColor: .systemGroupedBackground))
                .accessibilityElement(children: .contain).accessibilityIdentifier("settingsPage")
        }
    }
    private var showNavigationButton: some View {
        Button { toggleNavigation() } label: {
            Image(systemName: "square.grid.2x2").font(.title3.weight(.medium))
                .frame(width: 48, height: 48).background(.white.opacity(0.08), in: Circle())
        }.buttonStyle(.plain).accessibilityLabel("Show navigation".tr).accessibilityIdentifier("showNavigationButton")
    }
    private func dashboardHeader(title: String, subtitle: String, localizeTitle: Bool = true) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localizeTitle ? title.tr : title).font(.system(.title, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(subtitle.tr).font(.subheadline).opacity(0.9).lineLimit(1)
            }
            Spacer(minLength: 8)
            if home.demo { demoMark }
            showNavigationButton
        }.padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 20).frame(height: dynamicTypeSize.isAccessibilitySize ? 180 : 104)
            .accessibilityElement(children: .contain).accessibilityIdentifier("dashboardHeader")
    }
    private func homeDashboard(size: CGSize) -> some View {
        let gap: CGFloat = 12
        let outer: CGFloat = 12
        let landscape = size.width > size.height
        let geometry = HomeDashboardGeometry(width: size.width, height: size.height)
        let widthSide = (size.width - outer * 2 - gap * 2) / 3
        let cellSide = max(1, landscape ? geometry.cellSide : widthSide)
        let boardWidth = cellSide * 3 + gap * 2
        let contentWidth = landscape ? size.width - outer * 2 : boardWidth
        let viewportHeight = max(1, size.height - outer * 2)
        return ZStack(alignment: .topLeading) {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: gap) {
                        editableBoard(width: size.width - outer * 2, height: size.height - outer * 2)
                        shortcutColumn(width: size.width - outer * 2, cellHeight: 320)
                    }.padding(outer)
                }
            } else if landscape {
                HStack(alignment: .top, spacing: gap) {
                    editableBoard(width: boardWidth, height: viewportHeight, cellHeight: cellSide)
                    shortcutColumn(width: geometry.sidebarWidth, cellHeight: geometry.sidebarCardHeight)
                        .frame(width: geometry.sidebarWidth, height: viewportHeight)
                }.frame(width: contentWidth, height: viewportHeight)
                    .padding(outer).frame(width: size.width)
            } else {
                ScrollView {
                    VStack(spacing: gap) {
                        editableBoard(width: boardWidth, height: nil, cellHeight: cellSide, scrolls: false)
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellSide), spacing: gap), count: 3), spacing: gap) {
                            shortcutTiles(width: cellSide, cellHeight: cellSide)
                        }.frame(width: boardWidth)
                            .accessibilityElement(children: .contain).accessibilityIdentifier("shortcutColumn")
                    }.frame(width: boardWidth).padding(outer).frame(width: size.width)
                }.scrollIndicators(.hidden)
                    .accessibilityIdentifier("homePortraitScroll")
            }
            VStack {
                Spacer()
                HStack { Spacer(); Button { panel = .layout } label: {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 18, weight: .medium)).frame(width: 44, height: 44)
                        .modifier(GlassSurface(radius: 22))
                }.buttonStyle(.plain).accessibilityLabel("Edit Home".tr).accessibilityIdentifier("editHomeLayout") }
            }.padding(24)
            if home.demo {
                demoMark.padding(.leading, dynamicTypeSize.isAccessibilitySize ? 24 : (size.width - contentWidth) / 2 + 12)
                    .padding(.top, 24).allowsHitTesting(false)
            }
        }.frame(width: size.width, height: size.height)
            .accessibilityElement(children: .contain).accessibilityIdentifier("homeDashboard")
    }
    private func fullScreenClock(size: CGSize) -> some View {
        let landscape = size.width > size.height
        let diameter = min(landscape ? size.width * 0.58 : size.width * 0.9, size.height * (landscape ? 0.84 : 0.63))
        return ZStack {
            if landscape {
                HStack(spacing: 24) {
                    AnalogHomeClock(date: home.demo ? demoDate : nil, numbered: true, monochrome: true)
                        .frame(width: diameter, height: diameter).accessibilityIdentifier("fullClockDial")
                    clockInformation.padding(.trailing, 40)
                }.padding(32)
            } else {
                VStack(spacing: 24) {
                    AnalogHomeClock(date: home.demo ? demoDate : nil, numbered: true, monochrome: true)
                        .frame(width: diameter, height: diameter).accessibilityIdentifier("fullClockDial")
                    clockInformation
                }.padding(32)
            }
        }.frame(width: size.width, height: size.height)
            .accessibilityElement(children: .contain).accessibilityIdentifier("fullClock")
            .overlay(alignment: .topLeading) { if home.demo { demoMark.padding(28) } }
    }
    private var clockInformation: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let date = home.demo ? demoDate : context.date
            VStack(spacing: 14) {
                Text(date.formatted(.dateTime.hour().minute().locale(L10n.locale)))
                    .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 56 : 76, weight: .light, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(date.formatted(.dateTime.weekday(.wide).locale(L10n.locale))).font(.title2.weight(.medium))
                Text(date.formatted(.dateTime.month(.wide).day().locale(L10n.locale))).font(.title3).opacity(0.7)
                if home.demo { Text("Demo time".tr).font(.caption).opacity(0.6) }
            }.frame(maxWidth: .infinity)
                .accessibilityElement(children: .contain).accessibilityIdentifier("fullClockInformation")
        }
    }
    private var demoMark: some View {
        Text("DEMO".tr).font(.system(size: 11, weight: .semibold)).tracking(1)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(.black.opacity(0.12), in: Capsule())
            .accessibilityIdentifier("demoBadge")
    }
    private func tabButton(_ destination: DashboardPage, horizontal: Bool) -> some View {
        Button { selectPage(destination) } label: {
            Group {
                if horizontal {
                    VStack(spacing: 5) {
                        Image(systemName: destination.symbol).font(.system(size: 20, weight: .medium))
                        Text(destination.title).font(.caption).lineLimit(1).minimumScaleFactor(0.7)
                    }.frame(maxWidth: .infinity, minHeight: 56)
                } else {
                    Label(destination.title, systemImage: destination.symbol)
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(.horizontal, 12)
                }
            }.background(page == destination ? .white.opacity(0.24) : .clear, in: RoundedRectangle(cornerRadius: 15))
                .contentShape(Rectangle())
        }.accessibilityIdentifier("tab-\(destination.rawValue)")
            .accessibilityAddTraits(page == destination ? .isSelected : [])
    }
    private var navigationRail: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(DashboardPage.allCases, id: \.self) { tabButton($0, horizontal: false) }
                Divider().overlay(.white.opacity(0.25))
                navigationActions(horizontal: false)
            }.padding(8)
        }.frame(maxHeight: 650).modifier(GlassSurface(radius: 24))
            .buttonStyle(.plain).accessibilityElement(children: .contain).accessibilityIdentifier("sideNavigation")
    }
    private var bottomNavigation: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                ForEach(DashboardPage.allCases, id: \.self) { tabButton($0, horizontal: true) }
            }
            Divider().overlay(.white.opacity(0.25))
            HStack(spacing: 5) { navigationActions(horizontal: true) }
        }.padding(9).modifier(GlassSurface(radius: 28))
            .buttonStyle(.plain).accessibilityElement(children: .contain).accessibilityIdentifier("bottomNavigation")
    }
    @ViewBuilder private func navigationActions(horizontal: Bool) -> some View {
        navigationAction("Today", "calendar", id: "agendaCard", horizontal: horizontal) { panel = .agenda }
        navigationAction("Camera", "video", id: "cameraCard", horizontal: horizontal) { selectedCamera = home.cameras.first; panel = .camera }
        navigationAction("Controls", "switch.2", id: "allControls", horizontal: horizontal) { panel = .controls }
        navigationAction("Music", "music.note", id: "musicCard", horizontal: horizontal) { selectPage(.music) }
        navigationAction("Albums", "photo.stack", id: "wallAlbums", horizontal: horizontal) { panel = .photos }
        navigationAction("Add widget", "plus.square", id: "addHomeWidget", horizontal: horizontal) { panel = .widget }
        navigationAction("Add shortcut", "plus", id: "addShortcut", horizontal: horizontal) { editShortcut(nil) }
        navigationAction("Restore default widgets", "arrow.counterclockwise", id: "restoreHomeWidgets", horizontal: horizontal) { restoreConfirmation = true }
        navigationAction("Hide", horizontal ? "chevron.down" : "chevron.right", id: "hideNavigation", horizontal: horizontal) {}
    }
    private func navigationAction(_ title: String, _ symbol: String, id: String, horizontal: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            withAnimation(navigationAnimation) { navigationVisible = false }
        } label: {
            Group {
                if horizontal { Image(systemName: symbol).font(.system(size: 19)).frame(maxWidth: .infinity, minHeight: 44) }
                else { Label(title.tr, systemImage: symbol).font(.system(size: 15, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 12) }
            }.contentShape(Rectangle())
        }.accessibilityLabel(title.tr).accessibilityIdentifier(id)
    }
    private var widgetNamespace: String { home.demo ? "demo" : home.selectedHomeID?.uuidString ?? "unconnected" }
    private var widgetLayouts: [String: [HomeWidgetConfiguration]] {
        configurationCache.widgetLayouts(from: widgetLayoutsData)
    }
    private var storedWidgets: [HomeWidgetConfiguration] { widgetLayouts[widgetNamespace] ?? HomeWidgetConfiguration.defaults }
    private var configuredWidgets: [HomeWidgetConfiguration] { storedWidgets.filter { !$0.kind.rightColumnOnly } }
    private func migrateLegacyWidgets() {
        guard storedWidgets.contains(where: { $0.kind.rightColumnOnly }) else { return }
        let result = HomeFavoriteMigration.migrated(storedWidgets, shortcuts: shortcuts, homeID: widgetNamespace)
        saveShortcuts(result.shortcuts) // Save the destination first; stable IDs make retries idempotent.
        saveWidgets(result.widgets)
    }
    private func saveWidgets(_ widgets: [HomeWidgetConfiguration]) {
        var layouts = widgetLayouts
        layouts[widgetNamespace] = widgets
        guard let data = try? JSONEncoder().encode(layouts), let string = String(data: data, encoding: .utf8) else { return }
        widgetLayoutsData = string
    }
    private func editableBoard(width: CGFloat, height: CGFloat?, cellHeight: CGFloat = 320, scrolls: Bool = true) -> some View {
        let gap: CGFloat = 12
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 3
        let cellWidth = max(1, (width - gap * CGFloat(columns - 1)) / CGFloat(columns))
        let widgets = configuredWidgets
        let widgetsByID = Dictionary(widgets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let placements = configurationCache.placements(for: widgets, columns: columns)
        let rowCount = placements.map { $0.row + $0.rows }.max() ?? 0
        let contentHeight = max(1, CGFloat(rowCount) * (cellHeight + gap) - gap)
        return ScrollViewReader { proxy in
          ScrollView {
            if widgets.isEmpty {
                Button { panel = .widget } label: {
                    boardTile("plus", "Add widget", "Choose controls for this home".tr, width: width, height: cellHeight)
                }.buttonStyle(.plain).accessibilityIdentifier("addHomeWidget")
            } else {
                ZStack(alignment: .topLeading) {
                    // Real layout anchors avoid ScrollViewReader resolving an
                    // offset card at the canvas origin instead of its visible row.
                    VStack(spacing: gap) {
                        ForEach(0..<max(1, rowCount), id: \.self) { row in
                            Color.clear.frame(height: cellHeight).id("home-row-\(row)")
                        }
                    }.allowsHitTesting(false).accessibilityHidden(true)
                    ForEach(placements, id: \.id) { placement in
                        if let configuration = widgetsByID[placement.id] {
                            let widgetWidth = CGFloat(placement.columns) * (cellWidth + gap) - gap
                            let widgetHeight = CGFloat(placement.rows) * (cellHeight + gap) - gap
                            ZStack { configuredWidget(configuration, width: widgetWidth, height: widgetHeight) }
                                .frame(width: widgetWidth, height: widgetHeight)
                                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 30, style: .continuous))
                                .contextMenu {
                                    widgetContextMenu(configuration)
                                } preview: {
                                    widgetMenuPreview(configuration, width: widgetWidth, height: widgetHeight)
                                }
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("homeWidget-\(configuration.id)")
                                .accessibilityValue(configuration.size.title)
                                .overlay { RoundedRectangle(cornerRadius: 30).stroke(highlightedWidget == configuration.id ? Color.white : .clear, lineWidth: 3).allowsHitTesting(false) }
                                .id(configuration.id)
                                .offset(x: CGFloat(placement.column) * (cellWidth + gap), y: CGFloat(placement.row) * (cellHeight + gap))
                        }
                    }
                }.frame(width: width, height: contentHeight, alignment: .topLeading)
                    .accessibilityElement(children: .contain).accessibilityIdentifier("homeWidgetCanvas")
            }
        }.scrollIndicators(.hidden).scrollDisabled(!scrolls)
            .frame(width: width, height: height ?? max(cellHeight, contentHeight))
            .accessibilityElement(children: .contain).accessibilityIdentifier("homeControlGrid")
          .onChange(of: pendingWidgetReveal) { _, id in
              guard let id else { return }
              Task { @MainActor in
                  try? await Task.sleep(for: .milliseconds(350))
                  guard pendingWidgetReveal == id, configuredWidgets.contains(where: { $0.id == id }) else { return }
                  let target = configurationCache.placements(for: configuredWidgets, columns: columns).first { $0.id == id }
                  if let target {
                      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                          proxy.scrollTo("home-row-\(target.row + target.rows - 1)", anchor: .bottom); highlightedWidget = id
                      }
                  }
                  pendingWidgetReveal = nil
                  try? await Task.sleep(for: .seconds(2))
                  if highlightedWidget == id { highlightedWidget = nil }
              }
          }
        }
    }
    private func widgetMenuPreview(_ configuration: HomeWidgetConfiguration, width: CGFloat, height: CGFloat) -> some View {
        // Lift an independent full card, not the ScrollView's clipped source
        // snapshot. A bounded preview also leaves room for the native menu.
        let scale = min(1, 320 / max(1, width), 320 / max(1, height))
        return configuredWidget(configuration, width: width, height: height)
            .frame(width: width, height: height)
            .foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
            .allowsHitTesting(false)
            .disabled(true)
            .scaleEffect(scale)
            .frame(width: width * scale, height: height * scale)
            .padding(12)
            // The UIKit preview host is otherwise opaque white; give the
            // lifted glass the same readable dark backing as the dashboard.
            .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("homeWidgetPreview-\(configuration.id)")
    }
    @ViewBuilder private func widgetContextMenu(_ configuration: HomeWidgetConfiguration) -> some View {
        Button("Show navigation".tr) { withAnimation(navigationAnimation) { navigationVisible = true } }.accessibilityIdentifier("contextShowNavigation")
        Divider()
        if configuration.kind == .stack, let raw = configuration.target, let slot = Int(raw), (0..<6).contains(slot), options(for: slot).count > 1 {
            Button("Next widget".tr) { widgetOffsets[slot] = (widgetOffsets[slot] + 1) % options(for: slot).count }
                .accessibilityIdentifier("contextNextWidget-\(configuration.id)")
            Button("Previous widget".tr) { widgetOffsets[slot] = (widgetOffsets[slot] + options(for: slot).count - 1) % options(for: slot).count }
                .accessibilityIdentifier("contextPreviousWidget-\(configuration.id)")
            Divider()
        }
        ForEach(HomeWidgetSize.allCases) { size in
            Button { resizeWidget(configuration.id, size: size) } label: {
                Label(size.title, systemImage: size == configuration.size ? "checkmark" : "rectangle")
            }.accessibilityIdentifier("widgetSize-\(configuration.id)-\(size.rawValue)")
        }
        Divider()
        Button("Add widget".tr) { panel = .widget }.accessibilityIdentifier("addHomeWidget")
        Button("Restore default widgets".tr) { restoreConfirmation = true }.accessibilityIdentifier("restoreHomeWidgets")
        Divider()
        Button("Remove widget".tr, role: .destructive) { saveWidgets(configuredWidgets.filter { $0.id != configuration.id }) }
            .accessibilityIdentifier("removeWidget-\(configuration.id)")
    }
    private func resizeWidget(_ id: String, size: HomeWidgetSize) {
        var widgets = configuredWidgets
        guard let index = widgets.firstIndex(where: { $0.id == id }) else { return }
        widgets[index].size = size; saveWidgets(widgets); pendingWidgetReveal = id
    }
    @ViewBuilder private func configuredWidget(_ configuration: HomeWidgetConfiguration, width: CGFloat, height: CGFloat) -> some View {
        if configuration.kind == .stack, let raw = configuration.target, let slot = Int(raw), (0..<6).contains(slot) {
            widgetSlot(slot, width: width, height: height)
        } else {
            switch configuration.kind {
            case .accessory:
                if let tile = home.tiles.first(where: { $0.id.uuidString == configuration.target }), !tile.rightColumnOnly {
                    if tile.isClimate { climateTile(tile, width: width, height: height) }
                    else { accessoryWidget(tile, width: width, height: height) }
                } else { boardTile("exclamationmark.triangle", "Accessory unavailable", "Choose again for this home".tr, width: width, height: height) }
            case .scene:
                if let name = configuration.target, home.scenes.contains(name) { widgetContent(.scene(name), width: width, height: height) }
                else { boardTile("exclamationmark.triangle", "Scene unavailable", "Choose again for this home".tr, width: width, height: height) }
            case .camera:
                if let target = configuration.target {
                    let camera = home.cameras.first { $0.uniqueIdentifier.uuidString == target }
                    Button { selectedCamera = camera; panel = .camera } label: {
                        boardTile("video.fill", camera?.name ?? "Camera unavailable".tr,
                                  home.demo ? "Demo · no live feed".tr : "Open camera".tr,
                                  width: width, height: height, localizeTitle: false)
                    }.buttonStyle(.plain).accessibilityIdentifier("cameraWidget")
                } else { widgetContent(.camera, width: width, height: height) }
            case .clock: widgetContent(.clock, width: width, height: height)
            case .agenda: widgetContent(.agenda, width: width, height: height)
            case .stack: EmptyView()
            }
        }
    }
    private func addWidget(_ kind: HomeWidgetKind, target: String? = nil) {
        guard !kind.rightColumnOnly else { return }
        let widget = HomeWidgetConfiguration(id: UUID().uuidString, kind: kind, target: target, size: .small)
        saveWidgets(configuredWidgets + [widget]); panel = nil; pendingWidgetReveal = widget.id
    }
    private func widgetName(_ widget: HomeWidgetConfiguration) -> String {
        switch widget.kind {
        case .accessory: return home.tiles.first { $0.id.uuidString == widget.target }.map { home.demo ? $0.name.tr : $0.name } ?? "Accessory unavailable".tr
        case .scene: return widget.target.map { home.demo ? $0.tr : $0 } ?? "Scene".tr
        case .clock: return "Clock".tr
        case .camera: return "Camera".tr
        case .agenda: return "Today".tr
        case .stack:
            let titles = ["Climate", "Clock", "Add favorite", "Scenes", "Devices", "Lights"]
            return titles[min(5, max(0, Int(widget.target ?? "") ?? 0))].tr
        }
    }
    private var homeLayoutEditor: some View {
        List {
            Section("Favorite controls".tr) {
                ForEach(configuredWidgets) { widget in
                    HStack {
                        Text(widgetName(widget)).frame(maxWidth: .infinity, alignment: .leading)
                        Menu {
                            ForEach(HomeWidgetSize.allCases) { size in
                                Button(size.title) { resizeWidget(widget.id, size: size) }
                            }
                            Divider()
                            Button("Move to top".tr) {
                                var items = configuredWidgets
                                if let index = items.firstIndex(where: { $0.id == widget.id }) {
                                    items.insert(items.remove(at: index), at: 0); saveWidgets(items); pendingWidgetReveal = widget.id
                                }
                            }.accessibilityIdentifier("moveFirst-\(widget.id)")
                        } label: { Text(widget.size.title) }
                            .accessibilityLabel("\(widgetName(widget)), \("Size".tr)")
                            .accessibilityIdentifier("layoutSize-\(widget.id)")
                    }.accessibilityElement(children: .contain).accessibilityIdentifier("layoutRow-\(widget.id)")
                }.onMove { source, destination in
                    var items = configuredWidgets; items.move(fromOffsets: source, toOffset: destination); saveWidgets(items)
                }.onDelete { offsets in
                    var items = configuredWidgets; items.remove(atOffsets: offsets); saveWidgets(items)
                }
                Button { panel = .widget } label: { Label("Add favorite".tr, systemImage: "plus") }
                    .accessibilityIdentifier("layoutAddFavorite").moveDisabled(true).deleteDisabled(true)
            }
            Section("Right column".tr) {
                ForEach(shortcuts) { shortcut in
                    Button { editShortcut(shortcut) } label: {
                        Label(shortcut.name.isEmpty ? shortcut.kind.title : shortcut.name, systemImage: shortcut.kind.symbol)
                    }.accessibilityIdentifier("layoutShortcut-\(shortcut.id)")
                }.onMove { source, destination in
                    var items = shortcuts; items.move(fromOffsets: source, toOffset: destination); saveShortcuts(items)
                }.onDelete { offsets in
                    var items = shortcuts; items.remove(atOffsets: offsets); saveShortcuts(items)
                }
                Button { editShortcut(nil) } label: { Label("Add shortcut".tr, systemImage: "plus") }
                    .accessibilityIdentifier("layoutAddShortcut").moveDisabled(true).deleteDisabled(true)
            }
            Section {
                Button("Restore default widgets".tr, role: .destructive) { restoreConfirmation = true }
                    .accessibilityIdentifier("layoutRestoreDefaults")
            }
        }.environment(\.editMode, .constant(.active))
            .accessibilityIdentifier("homeLayoutEditor")
            .confirmationDialog("Restore default widgets?".tr, isPresented: Binding(get: { restoreConfirmation && panel == .layout }, set: { restoreConfirmation = $0 }), titleVisibility: .visible) {
                Button("Restore layout".tr, role: .destructive) { saveWidgets(HomeWidgetConfiguration.defaults); widgetOffsets = Array(repeating: 0, count: 6) }.accessibilityIdentifier("confirmRestoreWidgets")
                Button("Cancel".tr, role: .cancel) {}
            } message: { Text("This replaces the left column layout. Right column cards are kept.".tr) }
    }
    private var widgetPicker: some View {
        List {
            Section("Display widgets".tr) {
                Button { addWidget(.clock) } label: { Label("Clock".tr, systemImage: "clock") }.accessibilityIdentifier("widgetOption-clock")
            }
            Section("Accessories".tr) {
                ForEach(home.primaryTiles) { tile in
                    Button { addWidget(.accessory, target: tile.id.uuidString) } label: {
                        Label("\(home.demo ? tile.name.tr : tile.name) · \(home.demo ? tile.room.tr : tile.room)", systemImage: tile.displaySymbol)
                    }.accessibilityIdentifier("widgetOption-accessory-\(tile.id.uuidString)")
                }
                if home.tiles.isEmpty { Text("No supported accessories in this home.".tr).foregroundStyle(.secondary) }
            }
            Section("Scenes".tr) {
                ForEach(home.scenes, id: \.self) { name in
                    Button { addWidget(.scene, target: name) } label: { Label(home.demo ? name.tr : name, systemImage: "sun.max") }
                        .accessibilityIdentifier("widgetOption-scene-\(name)")
                }
            }
            Section { Text("Touch and hold a widget to change its size or remove it. Extra widgets scroll vertically.".tr).font(.footnote) }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("widgetPicker")
    }
    private var shortcuts: [HomeShortcut] {
        configurationCache.shortcuts(from: shortcutsData)
    }
    private func saveShortcuts(_ items: [HomeShortcut]) {
        guard let data = try? JSONEncoder().encode(items), let string = String(data: data, encoding: .utf8) else { return }
        shortcutsData = string
    }
    private func shortcutColumn(width: CGFloat, cellHeight: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 12) { shortcutTiles(width: width, cellHeight: cellHeight) }
        }.scrollIndicators(.hidden).frame(width: width)
            .accessibilityElement(children: .contain).accessibilityIdentifier("shortcutColumn")
    }
    @ViewBuilder private func shortcutTiles(width: CGFloat, cellHeight: CGFloat) -> some View {
        ForEach(shortcuts) { shortcut in
            Group {
                if shortcut.kind == .camera {
                    SidebarCameraCard(accessory: camera(for: shortcut), snapshots: cameraSnapshots,
                                      title: shortcut.name.isEmpty ? (camera(for: shortcut)?.name ?? "Camera".tr) : shortcut.name,
                                      demo: home.demo,
                                      active: phase == .active && !display.isStandby && panel == nil && !navigationVisible && sceneToRun == nil,
                                      width: width, height: cellHeight, open: { runShortcut(shortcut) })
                        .id("\(home.selectedHomeID?.uuidString ?? "none")-\(shortcut.id)")
                } else if shortcut.kind == .music {
                    MusicHomeWidget(store: music, audio: audio, demo: musicDemo,
                                    width: width, height: cellHeight, airPlayPresentationChanged: { airPlayPresented = $0 }, open: { runShortcut(shortcut) })
                        .background { GeometryReader { geometry in
                            Color.clear.preference(key: MusicWidgetFrameKey.self, value: [geometry.frame(in: .global)])
                        } }
                } else { Button { runShortcut(shortcut) } label: {
                HStack(spacing: 16) {
                    Image(systemName: shortcut.kind.symbol).font(.system(size: 28, weight: .regular)).frame(width: 48, height: 56)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(shortcut.name.isEmpty ? shortcut.kind.title : shortcut.name).font(.title3.weight(.semibold)).lineLimit(2)
                        Text(shortcutDetail(shortcut)).font(.subheadline).opacity(0.75).lineLimit(2)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).opacity(0.5)
                }.padding(.horizontal, 20).padding(.vertical, 12).frame(width: width, height: cellHeight).contentShape(Rectangle())
                    .modifier(GlassSurface(radius: 30))
                }.buttonStyle(.plain) }
            }.accessibilityIdentifier("shortcut-\(shortcut.id)")
                .disabled(shortcut.kind == .scene && (home.sceneBusy || !shortcutBelongsToCurrentHome(shortcut) || !home.scenes.contains(shortcut.target ?? "")))
                .contextMenu {
                    Button("Show navigation".tr) { withAnimation(navigationAnimation) { navigationVisible = true } }.accessibilityIdentifier("contextShowNavigation")
                    Button("Edit".tr) { editShortcut(shortcut) }.accessibilityIdentifier("editShortcut-\(shortcut.id)")
                    Button("Add shortcut".tr) { editShortcut(nil) }.accessibilityIdentifier("addShortcut")
                    Button("Remove".tr, role: .destructive) { saveShortcuts(shortcuts.filter { $0.id != shortcut.id }) }.accessibilityIdentifier("removeShortcut-\(shortcut.id)")
                }
        }
        if shortcuts.isEmpty {
            Button { editShortcut(nil) } label: { boardTile("plus", "Add shortcut", "", width: width, height: cellHeight) }
                .buttonStyle(.plain).accessibilityIdentifier("addShortcut")
                .contextMenu {
                    Button("Show navigation".tr) { withAnimation(navigationAnimation) { navigationVisible = true } }.accessibilityIdentifier("contextShowNavigation")
                }
        }
    }
    private func shortcutBelongsToCurrentHome(_ shortcut: HomeShortcut) -> Bool {
        shortcut.belongs(to: home.demo ? "demo" : home.selectedHomeID?.uuidString)
    }
    private func camera(for shortcut: HomeShortcut) -> HMAccessory? {
        guard shortcutBelongsToCurrentHome(shortcut), let target = shortcut.target else { return nil }
        if target == "first-available" { return home.cameras.first }
        return home.cameras.first { $0.uniqueIdentifier.uuidString == target }
    }
    private func shortcutDetail(_ shortcut: HomeShortcut) -> String {
        if !shortcutBelongsToCurrentHome(shortcut) { return "Choose again for this home".tr }
        switch shortcut.kind {
        case .camera:
            if home.demo { return "Demo · no live feed".tr }
            if shortcut.target != nil { return camera(for: shortcut)?.name ?? "Camera unavailable".tr }
            return "Choose a camera".tr
        case .scene: return shortcut.target.map { home.demo ? $0.tr : $0 } ?? "Choose a scene".tr
        case .agenda: return showPersonal ? (agendaStore.eventLines.first ?? agendaStore.statusTitle) : "Calendar is hidden".tr
        case .music: return "Apple Music and AirPlay".tr
        case .controls: return "All accessories".tr
        }
    }
    private func runShortcut(_ shortcut: HomeShortcut) {
        display.noteInteraction()
        switch shortcut.kind {
        case .camera:
            guard shortcutBelongsToCurrentHome(shortcut) else { editShortcut(shortcut); return }
            guard shortcut.target != nil else { editShortcut(shortcut); return }
            selectedCamera = camera(for: shortcut); panel = .camera
        case .scene:
            if shortcutBelongsToCurrentHome(shortcut), let target = shortcut.target, home.scenes.contains(target) { sceneToRun = target }
        case .agenda: panel = .agenda
        case .music: musicNavigation.show(.player); selectPage(.music)
        case .controls: panel = .controls
        }
    }
    private func editShortcut(_ shortcut: HomeShortcut?) {
        editingShortcutID = shortcut?.id
        shortcutKind = shortcut?.kind ?? .camera
        shortcutTarget = shortcut?.target ?? ""
        shortcutName = shortcut?.name ?? ""
        panel = .shortcut
    }
    private var shortcutEditor: some View {
        Form {
            Section("Customize shortcut".tr) {
                TextField("Name (optional)".tr, text: $shortcutName).accessibilityIdentifier("shortcutName")
                Picker("Function".tr, selection: $shortcutKind) {
                    ForEach(HomeShortcutKind.allCases) { kind in Text(kind.title).tag(kind).accessibilityIdentifier("shortcutKind-\(kind.rawValue)") }
                }.accessibilityIdentifier("shortcutKind")
                if shortcutKind == .camera {
                    Picker("Camera".tr, selection: $shortcutTarget) {
                        Text("Choose a camera".tr).tag("")
                        Text("First available camera".tr).tag("first-available")
                        ForEach(home.cameras, id: \.uniqueIdentifier) { camera in Text(camera.name).tag(camera.uniqueIdentifier.uuidString) }
                    }.accessibilityIdentifier("shortcutCameraPicker")
                    if home.cameras.isEmpty { Text((home.demo ? "Demo mode has no camera stream. Connect Apple Home to choose a camera." : "No compatible HomeKit cameras in this home.").tr).font(.footnote).foregroundStyle(.secondary) }
                }
                if shortcutKind == .scene {
                    Picker("Scene".tr, selection: $shortcutTarget) {
                        Text("Choose a scene".tr).tag("")
                        ForEach(home.scenes, id: \.self) { scene in Text(home.demo ? scene.tr : scene).tag(scene) }
                    }.accessibilityIdentifier("shortcutScenePicker")
                    Text("Scenes always ask for confirmation before running.".tr).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Button("Save shortcut".tr) {
                    let shortcut = HomeShortcut(id: editingShortcutID ?? UUID().uuidString, kind: shortcutKind,
                        target: shortcutKind == .camera || shortcutKind == .scene ? (shortcutTarget.isEmpty ? nil : shortcutTarget) : nil,
                        name: String(shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60)),
                        homeID: shortcutKind == .scene || shortcutKind == .camera ? (home.demo ? "demo" : home.selectedHomeID?.uuidString) : nil)
                    var saved = shortcuts
                    if let index = saved.firstIndex(where: { $0.id == shortcut.id }) { saved[index] = shortcut } else { saved.append(shortcut) }
                    saveShortcuts(saved); panel = nil
                }.disabled((shortcutKind == .scene && !home.scenes.contains(shortcutTarget)) ||
                           (shortcutKind == .camera && !shortcutTarget.isEmpty && shortcutTarget != "first-available" && !home.cameras.contains { $0.uniqueIdentifier.uuidString == shortcutTarget }))
                    .accessibilityIdentifier("saveShortcut")
                Button("Cancel".tr, role: .cancel) { panel = nil }.accessibilityIdentifier("cancelShortcut")
            }
        }.onChange(of: shortcutKind) { _, _ in shortcutTarget = "" }
    }
    private func options(for slot: Int) -> [DashboardWidget] {
        DashboardWidget.options(for: slot, tiles: visibleTiles, scenes: home.scenes).filter { $0 != .photo }
    }
    private func widgetSlot(_ slot: Int, width: CGFloat, height: CGFloat) -> some View {
        return WidgetCarousel(items: options(for: slot), selection: $widgetOffsets[slot], size: width, height: height, allowsVerticalSwipe: false,
                       radius: 30, slot: slot,
                       showNavigation: { withAnimation(navigationAnimation) { navigationVisible = true } }) { widget in
            widgetContent(widget, width: width, height: height)
        }
    }
    @ViewBuilder private func widgetContent(_ widget: DashboardWidget, width: CGFloat, height: CGFloat) -> some View {
        switch widget {
        case .climate(let id):
            if let tile = visibleTiles.first(where: { $0.id == id }) { climateTile(tile, width: width, height: height) }
        case .clock:
            AnalogHomeClock(date: home.demo ? demoDate : nil, numbered: false)
                .padding(24).frame(width: width, height: height)
                .modifier(GlassSurface(radius: 30))
                .accessibilityIdentifier("clockWidget")
        case .photo: EmptyView()
        case .scene(let name):
            Button { sceneToRun = name } label: {
                boardTile("sun.max.fill", name, home.notice?.contains(name) == true ? "Done".tr : "Scene".tr, width: width, height: height, localizeTitle: home.demo)
            }.disabled(home.sceneBusy).accessibilityIdentifier("scene-\(name)")
        case .accessory(let id):
            if let tile = home.tiles.first(where: { $0.id == id }), !tile.rightColumnOnly { accessoryWidget(tile, width: width, height: height) }
        case .camera:
            Button { selectedCamera = home.cameras.first; panel = .camera } label: {
                boardTile("video.fill", "Camera", home.demo ? "Demo · no live feed".tr : (home.cameras.first?.name ?? "No camera".tr), width: width, height: height)
            }.accessibilityIdentifier("cameraWidget")
        case .agenda:
            Button { panel = .agenda } label: { boardTile("calendar", "Today", agendaStore.eventLines.first ?? agendaStore.statusTitle, width: width, height: height) }.accessibilityIdentifier("agendaWidget")
        case .empty(let slot) where slot == 2:
            Button { panel = .widget } label: { boardTile("plus", "Add favorite", "", width: width, height: height) }
                .buttonStyle(.plain).accessibilityIdentifier("addHomeFavorite")
        case .empty(let slot):
            let title = slot == 0 ? "Climate" : slot == 3 ? "Scenes" : slot == 5 ? "Lights" : "Devices"
            boardTile(slot == 0 ? "thermometer.medium" : slot == 3 ? "sun.max.fill" : slot == 5 ? "lightbulb.fill" : "switch.2",
                      title, "Add your favorite devices".tr, width: width, height: height)

        }
    }
    private func accessoryWidget(_ tile: HomeTile, width: CGFloat, height: CGFloat) -> some View {
        let power = HomePowerState.resolve(value: tile.value, reachable: tile.reachable)
        let state = tile.kind == .power ? power.title : (tile.reachable ? tile.value.tr : "Offline".tr)
        let toggle = home.quickToggle(for: tile)
        let active = tile.hasActiveState || tile.needsAttention
        let size = min(width, height)
        return VStack(spacing: 0) {
            Button { activate(tile) } label: {
                Image(systemName: tile.displaySymbol).font(.system(size: min(64, max(48, size * 0.22)), weight: .regular))
                    .foregroundStyle(tile.needsAttention ? Color.orange : active ? Color.yellow : Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
                    .overlay { if home.busy.contains(tile.id) { ProgressView().tint(.white) } }
            }.buttonStyle(.plain)
                .disabled(toggle.map { !home.canToggle($0) } ?? false)
                .accessibilityLabel("\(home.demo ? tile.name.tr : tile.name), \(home.demo ? tile.room.tr : tile.room), \(home.busy.contains(tile.id) ? "Updating…".tr : state)")
                .accessibilityValue(home.busy.contains(tile.id) ? "Updating…".tr : state)
                .accessibilityHint((toggle != nil ? "Tap to switch. Tap the name for more controls." : "Open accessory controls").tr)
                .accessibilityIdentifier("accessory-\(tile.name)")
            Button { selectedAccessoryID = tile.id; panel = .accessory } label: {
                VStack(spacing: 8) {
                    Text(home.demo ? tile.name.tr : tile.name).font(widgetLabelFont(size, weight: .semibold)).lineLimit(2)
                    Text(home.demo ? tile.room.tr : tile.room).font(widgetLabelFont(size)).opacity(0.9).lineLimit(2)
                    if power == .offline || power == .unavailable || tile.kind != .power { Text(state).font(.caption).opacity(0.7) }
                }.multilineTextAlignment(.center).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 64).padding(.horizontal, 12).padding(.bottom, 20).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(home.demo ? tile.name.tr : tile.name), \("More controls".tr)")
                .accessibilityIdentifier("accessoryDetails-\(tile.name)")
        }.frame(width: width, height: height).modifier(GlassSurface(radius: 30, active: active))
    }
    private func climateTile(_ tile: HomeTile, width: CGFloat, height: CGFloat) -> some View {
        let size = min(width, height)
        return VStack(spacing: 0) {
            Spacer(minLength: 12)
            Text(tile.number.map { String(format: "%.1f", $0) } ?? "—")
                .font(.system(size: min(220, max(120, size * 0.42)), weight: .regular))
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity).contentTransition(.numericText())
                .accessibilityIdentifier("temperatureValue")
            Spacer(minLength: 12)
            HStack(spacing: 12) {
                temperatureArrow(tile, increase: false, size: 44)
                Button { selectedAccessoryID = tile.id; panel = .accessory } label: {
                    VStack(spacing: 8) {
                        Text(tile.kind == .targetTemperature ? "Thermostat".tr : (home.demo ? tile.name.tr : tile.name))
                            .font(widgetLabelFont(size, weight: .semibold))
                        Text("\(home.demo ? tile.room.tr : tile.room) · \(tile.value.tr)")
                            .font(widgetLabelFont(size)).opacity(0.9)
                    }.multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 64).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("climateDetails")
                temperatureArrow(tile, increase: true, size: 44)
            }.padding(.bottom, 12)
        }.padding(24).frame(width: width, height: height).modifier(GlassSurface(radius: 30))
            .accessibilityElement(children: .contain).accessibilityIdentifier("climateWidget")
    }
    private func temperatureArrow(_ tile: HomeTile, increase: Bool, size: CGFloat) -> some View {
        let next = tile.temperatureStep(increase: increase)
        return Button { if let next { home.adjust(tile.id, to: next) } } label: {
            Image(systemName: increase ? "chevron.up" : "chevron.down").font(.system(size: 28, weight: .semibold))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(next == nil || home.busy.contains(tile.id))
            .opacity(next == nil || home.busy.contains(tile.id) ? 0.28 : 1)
            .accessibilityLabel((increase ? "Increase temperature" : "Decrease temperature").tr)
            .accessibilityValue(tile.value)
            .accessibilityHint((tile.kind == .targetTemperature ? "Adjust target temperature" : "Read-only sensor").tr)
            .accessibilityIdentifier(increase ? "temperatureUp" : "temperatureDown")
    }
    private func widgetLabelFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        dynamicTypeSize.isAccessibilitySize ? .system(.title2, weight: weight) : .system(size: min(26, max(20, size * 0.08)), weight: weight)
    }
    private func boardTile(_ symbol: String, _ title: String, _ subtitle: String, width: CGFloat, height: CGFloat, active: Bool = false, localizeTitle: Bool = true) -> some View {
        let size = min(width, height)
        return VStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: symbol).font(.system(size: min(64, max(48, size * 0.22)), weight: .regular))
                .frame(height: max(68, size * 0.32))
            Spacer(minLength: 0)
            Text(localizeTitle ? title.tr : title).font(widgetLabelFont(size, weight: .semibold)).lineLimit(2)
            Text(subtitle).font(widgetLabelFont(size)).opacity(0.9).lineLimit(2)
        }.multilineTextAlignment(.center).minimumScaleFactor(0.8).padding(20)
            .frame(width: width, height: height).modifier(GlassSurface(radius: 30, active: active))
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "house.and.flag.fill").font(.system(size: 72)).foregroundStyle(Color.purple.opacity(0.6))
            Text(HomeStatus.welcome.title).font(.system(size: 42, weight: .medium, design: .rounded))
            Text(HomeStatus.welcome.detail).font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Connect Apple Home".tr) { home.connect() }.buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("connectHome")
            Button("Explore demo".tr) { home.startDemo() }.buttonStyle(.bordered).controlSize(.large).accessibilityIdentifier("exploreDemo")
            Text("HomePad is a foreground iPad dashboard. Your HomePod mini remains your home hub and Siri speaker.".tr).font(.callout).foregroundStyle(.secondary)
        }.padding(32).frame(maxWidth: .infinity, alignment: .leading).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32)).foregroundStyle(Color.primary)
    }
    private var stateCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: home.status == .denied ? "hand.raised.fill" : "house.circle").font(.largeTitle)
            Text(home.status.title).font(.largeTitle.bold()).accessibilityIdentifier("homeStateTitle")
            Text(home.status.detail).font(.title3)
            if home.status == .loading { ProgressView() }
            Button("Retry connection".tr) { home.demo ? home.startDemo() : home.connect() }.buttonStyle(.borderedProminent)
            Button("Explore demo".tr) { home.startDemo() }.buttonStyle(.bordered)
            if home.status == .denied { Button("Open Settings".tr) { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) } }
        }.padding(32).frame(maxWidth: .infinity, alignment: .leading).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30)).foregroundStyle(Color.primary)
    }
    @ViewBuilder private func panelContent(_ selected: Panel) -> some View {
        switch selected {
        case .layout: homeLayoutEditor
        case .widget: widgetPicker
        case .shortcut: shortcutEditor
        case .camera:
            VStack {
                CameraConnectionView(home: home, selection: $selectedCamera)
                if let camera = selectedCamera ?? home.cameras.first,
                   let value = home.tiles.first(where: { $0.accessoryID == camera.uniqueIdentifier && $0.control != .readOnly }) {
                    Button("Camera controls".tr) { selectedAccessoryID = value.id; panel = .accessory }
                        .buttonStyle(.bordered).padding(.bottom).accessibilityIdentifier("cameraAccessoryControls")
                }
            }
        case .photos: PhotosPanel(photos: photos)
        case .weather: WeatherPanel(weather: weather, location: weatherLocation)
        case .accessory:
            if let id = selectedAccessoryID { AccessoryAdjustmentView(home: home, id: id) }
        case .settings: settings
        case .controls:
            List {
                if !home.demo {
                    Section(home.homeName) {
                        Text(L10n.format("Live Apple Home · %lld supported values", home.tiles.count))
                        Button("Refresh home status".tr) { home.refresh() }
                        if let error = home.error { Text(error).foregroundStyle(.red) }
                    }
                }
                Section("Accessories".tr) {
                    ForEach(visibleTiles) { tile in
                        HStack(spacing: 16) {
                            Button { activate(tile) } label: { Image(systemName: tile.displaySymbol).frame(width: 52, height: 52).contentShape(Rectangle()) }
                                .disabled(home.quickToggle(for: tile).map { !home.canToggle($0) } ?? false)
                                .accessibilityLabel("\(home.demo ? tile.name.tr : tile.name), \(tile.value.tr)")
                                .accessibilityValue(tile.value.tr).accessibilityIdentifier("accessory-\(tile.name)")
                            Button { selectedAccessoryID = tile.id; panel = .accessory } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(home.demo ? tile.name.tr : tile.name)
                                    Text(tile.value.tr).font(.subheadline).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).contentShape(Rectangle())
                            }.accessibilityIdentifier("accessoryDetails-\(tile.name)")
                        }.buttonStyle(.plain)
                    }
                }
                Section("Scenes".tr) {
                    ForEach(home.scenes, id: \.self) { scene in Button(home.demo ? scene.tr : scene) { sceneToRun = scene }.disabled(home.sceneBusy).accessibilityIdentifier("scene-\(scene)") }
                    if let notice = home.notice { Text(notice).accessibilityIdentifier("sceneNotice") }
                }
            }.foregroundStyle(Color.primary)
        case .agenda: agenda
        case .music: MusicPage(store: music, audio: audio, demo: musicDemo, navigation: $musicNavigation, showPageNavigation: showMusicPageNavigation, changePage: moveMusicPage, presentationChanged: { musicPickerPresented = $0 }, airPlayPresentationChanged: { airPlayPresented = $0 })

        }
    }
    private var settings: some View {
        SettingsHubView(home: home, display: display, wallpaper: wallpaper, aerial: aerial, photos: photos,
                        weather: weather, location: weatherLocation,
                        appLanguage: $appLanguage, tealWallpaper: $tealWallpaper,
                        showPersonal: $showPersonal, wallpaperPickerPresented: $wallpaperPickerPresented,
                        connectHome: { home.connect(); panel = nil; selectPage(.home) },
                        exploreDemo: { home.startDemo(); panel = nil; selectPage(.home) },
                        disconnectHome: { home.disconnect(); panel = nil; selectPage(.home) },
                        simulateState: { state in home.startDemo(state: state); panel = nil; selectPage(.home) },
                        openPhotos: { panel = .photos }, openWeather: { panel = .weather },
                        openMusic: { panel = nil; selectPage(.music) }, openAgenda: { panel = .agenda },
                        openCameras: { selectedCamera = home.cameras.first; panel = .camera },
                        musicConnectionStatus: music.statusTitle, calendarConnectionStatus: agendaStore.statusTitle,
                        showPageNavigation: toggleNavigation)
    }
    private func settingsButtonLabel(_ title: String) -> some View {
        Text(title).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
    }
    private var agenda: some View {
        AgendaView(store: agendaStore, demo: home.demo, enabled: $showPersonal,
                   canAddToHome: !shortcuts.contains(where: { $0.kind == .agenda && shortcutBelongsToCurrentHome($0) }),
                   addToHome: {
                       var items = shortcuts
                       guard !items.contains(where: { $0.kind == .agenda && shortcutBelongsToCurrentHome($0) }) else { return }
                       items.append(HomeShortcut(id: UUID().uuidString, kind: .agenda))
                       saveShortcuts(items); panel = nil; selectPage(.home)
                   })
    }

}

/// Original vector clock drawn with system typography; no promotional assets.
struct AnalogHomeClock: View {
    var date: Date?
    var numbered = true
    var monochrome = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Canvas { graphics, size in
                let d = min(size.width, size.height)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = d * 0.47
                let accent = monochrome ? Color(red: 1, green: 0.77, blue: 0.16) : Color(red: 0.50, green: 0.46, blue: 0.66)
                for tick in 0..<60 {
                    if !numbered && tick % 5 != 0 { continue }
                    let angle = Double(tick) * .pi / 30 - .pi / 2
                    let outer = radius
                    let inner = radius - (tick % 5 == 0 ? (numbered ? d * 0.038 : d * 0.075) : d * 0.017)
                    var path = Path(); path.move(to: CGPoint(x: center.x + cos(angle)*inner, y: center.y + sin(angle)*inner)); path.addLine(to: CGPoint(x: center.x + cos(angle)*outer, y: center.y + sin(angle)*outer))
                    graphics.stroke(path, with: .color(monochrome ? .white.opacity(tick % 5 == 0 ? 0.95 : 0.5) : numbered ? accent.opacity(0.6) : .white), style: StrokeStyle(lineWidth: tick % 5 == 0 ? d * 0.009 : d * 0.004, lineCap: .round))
                }
                if numbered { for n in 1...12 {
                    let a = Double(n) * .pi / 6 - .pi / 2
                    graphics.draw(Text(String(n)).font(.system(size: d * 0.075, weight: .medium)).foregroundColor(monochrome ? .white : accent), at: CGPoint(x: center.x + cos(a)*d*0.365, y: center.y + sin(a)*d*0.365))
                } }
                let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date ?? context.date)
                let minute = date == nil ? Double(components.minute ?? 0) : 9, second = date == nil ? Double(components.second ?? 0) : 30
                let hour = (date == nil ? Double((components.hour ?? 0) % 12) : 10) + minute / 60
                for (angle, length, thickness, color) in [(hour * .pi/6, d*0.25, d*0.018, numbered && !monochrome ? Color.black : .white), (minute * .pi/30, d*0.39, d*0.014, numbered && !monochrome ? Color.black : .white), (second * .pi/30, d*0.42, d*0.006, numbered ? accent : .white.opacity(0.65))] {
                    var hand = Path(); hand.move(to: CGPoint(x: center.x - sin(angle)*d*0.045, y: center.y + cos(angle)*d*0.045)); hand.addLine(to: CGPoint(x: center.x + sin(angle)*length, y: center.y - cos(angle)*length))
                    graphics.stroke(hand, with: .color(color), style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                }
                graphics.fill(Path(ellipseIn: CGRect(x: center.x-d*0.018, y: center.y-d*0.018, width: d*0.036, height: d*0.036)), with: .color(numbered ? accent : .white))
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel("Analog clock".tr).accessibilityValue(date == nil ? Date.now.formatted(date: .omitted, time: .shortened) : "10:09 demo time".tr)
    }
}

/// Original, resolution-independent wallpaper shared behind every translucent widget.
struct AmbientWallpaper: View {
    let teal: Bool
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width, h = geometry.size.height
            ZStack {
                LinearGradient(colors: teal
                    ? [Color(red: 0.12, green: 0.40, blue: 0.38), Color(red: 0.05, green: 0.23, blue: 0.23)]
                    : [Color(red: 0.65, green: 0.62, blue: 0.57), Color(red: 0.36, green: 0.34, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Ellipse().fill(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.02)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: w * 0.65, height: h * 1.5).rotationEffect(.degrees(-28)).offset(x: -w * 0.22, y: -h * 0.22).blur(radius: 18)
                Ellipse().fill(.black.opacity(0.18)).frame(width: w * 0.75, height: h * 0.55)
                    .rotationEffect(.degrees(-35)).offset(x: w * 0.3, y: h * 0.28).blur(radius: 32)
                Ellipse().stroke(.white.opacity(0.13), lineWidth: w * 0.07).frame(width: w, height: h * 0.8)
                    .rotationEffect(.degrees(-30)).offset(x: w * 0.3, y: -h * 0.22).blur(radius: 24)
            }.frame(width: w, height: h).clipped()
        }.accessibilityHidden(true)
    }
}

struct GlassSurface: ViewModifier {
    let radius: CGFloat
    var enabled = true
    var active = false
    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            if #available(iOS 26.0, *) {
                content.contentShape(shape).background(Color.black.opacity(0.48), in: shape).glassEffect(active ? .clear.tint(.green.opacity(0.12)) : .clear, in: shape).environment(\.colorScheme, .dark)
            } else {
                content.contentShape(shape).background(.regularMaterial, in: shape)
            }
        } else { content }
    }
}


/// Present confirmations in the same presentation context as the tapped scene.
private struct SceneConfirmation: ViewModifier {
    @Binding var name: String?
    let enabled: Bool
    var demo = false
    let run: (String) -> Void
    func body(content: Content) -> some View {
        content.alert(L10n.format("Run %@?", name.map { demo ? $0.tr : $0 } ?? "Scene".tr), isPresented: Binding(
            get: { enabled && name != nil },
            set: { if enabled && !$0 { name = nil } }
        )) {
            if let selected = name { Button("Run scene".tr) { run(selected); name = nil } }
            Button("Cancel".tr, role: .cancel) { name = nil }
        } message: {
            Text("Scenes can change multiple accessories, including locks or doors. Review the scene in Apple Home before running it.".tr)
        }
    }
}
