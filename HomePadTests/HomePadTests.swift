import XCTest
import HomeKit
import Photos
@testable import HomePad

/// Snapshot tests model adapter completion/time only. They never construct
/// unsupported HomeKit snapshot objects or render synthetic camera pictures.
@MainActor private final class TestCameraSnapshotClient: HomePadCameraSnapshotClient {
    var requests = 0
    var cancellations = 0
    var reportsFailureOnCancel = false
    private var completions: [Int: (Result<CameraSnapshotFrame, Error>) -> Void] = [:]
    func takeSnapshot(_ completion: @escaping (Result<CameraSnapshotFrame, Error>) -> Void) {
        completions[requests] = completion; requests += 1
    }
    func cancel() {
        cancellations += 1
        if reportsFailureOnCancel {
            for completion in Array(completions.values) { completion(.failure(URLError(.cancelled))) }
        }
    }
    func complete(_ request: Int, at date: Date) {
        completions.removeValue(forKey: request)?(.success(CameraSnapshotFrame(snapshot: nil, capturedAt: date)))
    }
    func fail(_ request: Int) { completions.removeValue(forKey: request)?(.failure(URLError(.notConnectedToInternet))) }
    func failWithoutDiscardingCallback(_ request: Int) { completions[request]?(.failure(URLError(.notConnectedToInternet))) }
}

extension HomePadTests {
    @MainActor func testQueuedSnapshotCallbackCannotConsumeReplacementRequestCompletion() async {
        var oldCompletions = 0
        var replacementDates: [Date] = []
        let earlier = Date(timeIntervalSince1970: 1_000)
        let latest = Date(timeIntervalSince1970: 2_000)
        let old = CameraSnapshotRequestDelivery { _ in oldCompletions += 1 }
        // The delegate has entered the app, but its main-actor hop is still
        // queued. Cancel and replace without yielding to that queued task.
        old.enqueue(.success(CameraSnapshotFrame(snapshot: nil, capturedAt: earlier)))
        old.cancel()
        let replacement = CameraSnapshotRequestDelivery { result in
            if case .success(let frame) = result { replacementDates.append(frame.capturedAt) }
        }
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(oldCompletions, 0)
        XCTAssertTrue(replacementDates.isEmpty, "An old callback cannot finish a newer request")
        replacement.enqueue(.success(CameraSnapshotFrame(snapshot: nil, capturedAt: latest)))
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(oldCompletions, 0)
        XCTAssertEqual(replacementDates, [latest])
    }

    @MainActor func testSnapshotRequestDeliveryClearsCompletionBeforeReentrantCancellation() async {
        var completions = 0
        var delivery: CameraSnapshotRequestDelivery?
        delivery = CameraSnapshotRequestDelivery { _ in
            completions += 1
            delivery?.cancel()
            delivery?.enqueue(.failure(URLError(.cancelled)))
        }
        delivery?.enqueue(.success(CameraSnapshotFrame(snapshot: nil, capturedAt: Date(timeIntervalSince1970: 1_000))))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(completions, 1)
        delivery?.cancel(); delivery = nil
    }

    @MainActor func testCameraSnapshotsRequireForegroundAccessAndExplicitVisibleCamera() {
        let client = TestCameraSnapshotClient()
        let store = CameraSnapshotStore(automaticRefresh: false, makeClient: { _ in client })
        let cameraID = UUID(), consumer = UUID()
        store.setAccess(allowed: true); store.refreshVisibleCameras()
        XCTAssertEqual(client.requests, 0, "Access alone must not select or photograph a camera")
        store.setAccess(allowed: false)
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: consumer, visible: true)
        store.refreshVisibleCameras()
        XCTAssertEqual(client.requests, 0)
        store.setAccess(allowed: true)
        XCTAssertEqual(client.requests, 1)
    }

    @MainActor func testCameraSnapshotsRefreshAtTenSecondsWithoutOverlappingRequests() {
        var date = Date(timeIntervalSince1970: 1_000)
        let client = TestCameraSnapshotClient()
        let store = CameraSnapshotStore(now: { date }, automaticRefresh: false, makeClient: { _ in client })
        let cameraID = UUID(), consumer = UUID()
        store.setAccess(allowed: true)
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: consumer, visible: true)
        XCTAssertEqual(client.requests, 1)
        date.addTimeInterval(9); store.refreshVisibleCameras()
        XCTAssertEqual(client.requests, 1)
        date.addTimeInterval(1); store.refreshVisibleCameras()
        XCTAssertEqual(client.requests, 1, "Ten seconds cannot start a second request while the first is pending")
        client.complete(0, at: date)
        store.refreshVisibleCameras()
        XCTAssertEqual(client.requests, 2)
        client.complete(1, at: date)
        date.addTimeInterval(9); store.refreshVisibleCameras()
        XCTAssertEqual(client.requests, 2)
        date.addTimeInterval(1); store.refreshVisibleCameras()
        XCTAssertEqual(client.requests, 3)
        store.setAccess(allowed: false)
    }

    @MainActor func testReenteringCameraCardKeepsSnapshotAndOriginalRefreshDeadline() {
        var date = Date(timeIntervalSince1970: 1_000)
        let client = TestCameraSnapshotClient()
        let store = CameraSnapshotStore(now: { date }, automaticRefresh: false, makeClient: { _ in client })
        let cameraID = UUID(), consumer = UUID()
        store.setAccess(allowed: true)
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: consumer, visible: true)
        client.complete(0, at: date)
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: consumer, visible: false)
        date.addTimeInterval(5); store.refreshVisibleCameras()
        XCTAssertEqual(client.requests, 1)
        XCTAssertEqual(store.lastUpdated(for: cameraID), Date(timeIntervalSince1970: 1_000))
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: consumer, visible: true)
        XCTAssertEqual(client.requests, 1, "A page switch must not replace a recent cached frame or reconnect immediately")
        date.addTimeInterval(5); store.refreshVisibleCameras()
        XCTAssertEqual(client.requests, 2)
        store.setAccess(allowed: false)
    }

    @MainActor func testDuplicateCameraCardsShareRequestAndLastConsumerStopsPolling() {
        var date = Date(timeIntervalSince1970: 1_000)
        let client = TestCameraSnapshotClient()
        var created = 0
        let store = CameraSnapshotStore(now: { date }, automaticRefresh: false, makeClient: { _ in created += 1; return client })
        let cameraID = UUID(), first = UUID(), second = UUID()
        store.setAccess(allowed: true)
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: first, visible: true)
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: second, visible: true)
        XCTAssertEqual(created, 1); XCTAssertEqual(client.requests, 1)
        client.complete(0, at: date)
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: first, visible: false)
        date.addTimeInterval(10); store.refreshVisibleCameras()
        XCTAssertEqual(client.requests, 2)
        client.complete(1, at: date)
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: second, visible: false)
        date.addTimeInterval(10); store.refreshVisibleCameras()
        XCTAssertEqual(client.requests, 2)
        XCTAssertNotNil(store.lastUpdated(for: cameraID))
        store.setAccess(allowed: false)
    }

    @MainActor func testFailedCameraSnapshotRetainsPreviousFrameWithExplicitStaleStatusAndCanRecover() {
        var date = Date(timeIntervalSince1970: 1_000)
        let client = TestCameraSnapshotClient()
        let store = CameraSnapshotStore(now: { date }, automaticRefresh: false, makeClient: { _ in client })
        let cameraID = UUID()
        store.setAccess(allowed: true)
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: UUID(), visible: true)
        client.complete(0, at: date)
        XCTAssertFalse(store.isStale(for: cameraID))
        date.addTimeInterval(10); store.refreshVisibleCameras(); client.fail(1)
        XCTAssertEqual(store.lastUpdated(for: cameraID), Date(timeIntervalSince1970: 1_000))
        XCTAssertTrue(store.isStale(for: cameraID))
        XCTAssertEqual(store.message(for: cameraID), "Snapshot update failed · showing earlier image")
        date.addTimeInterval(10); store.refreshVisibleCameras(); client.complete(2, at: date)
        XCTAssertEqual(store.lastUpdated(for: cameraID), date)
        XCTAssertFalse(store.isStale(for: cameraID))
        XCTAssertEqual(store.message(for: cameraID), "Snapshot · updates every 10 seconds")
        store.setAccess(allowed: false)
    }

    @MainActor func testClearingHouseholdDropsCameraRegistrationsAndRejectsLateSnapshot() {
        let date = Date(timeIntervalSince1970: 1_000)
        let client = TestCameraSnapshotClient()
        let store = CameraSnapshotStore(now: { date }, automaticRefresh: false, makeClient: { _ in client })
        let cameraID = UUID(), consumer = UUID()
        store.setAccess(allowed: true)
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: consumer, visible: true)
        store.clear(); client.complete(0, at: date)
        XCTAssertNil(store.lastUpdated(for: cameraID))
        store.refreshVisibleCameras()
        XCTAssertEqual(client.requests, 1, "Another home must not inherit a camera registration")
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: consumer, visible: true)
        XCTAssertEqual(client.requests, 2)
        client.complete(1, at: date)
        XCTAssertEqual(store.lastUpdated(for: cameraID), date)
        store.setAccess(allowed: false)
    }

    @MainActor func testCameraBackgroundOrRevocationClearsCachedFrameAndRejectsPendingResult() {
        var date = Date(timeIntervalSince1970: 1_000)
        let client = TestCameraSnapshotClient()
        let store = CameraSnapshotStore(now: { date }, automaticRefresh: false, makeClient: { _ in client })
        let cameraID = UUID()
        store.setAccess(allowed: true)
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: UUID(), visible: true)
        client.complete(0, at: date)
        date.addTimeInterval(10); store.refreshVisibleCameras()
        store.setAccess(allowed: false)
        XCTAssertNil(store.lastUpdated(for: cameraID))
        client.complete(1, at: date)
        XCTAssertNil(store.lastUpdated(for: cameraID))
        store.refreshVisibleCameras()
        XCTAssertEqual(client.requests, 2)
        store.setAccess(allowed: true)
        XCTAssertEqual(client.requests, 3)
        client.complete(2, at: date)
        XCTAssertEqual(store.lastUpdated(for: cameraID), date)
        store.setAccess(allowed: false)
    }

    @MainActor func testSnapshotCleanupRejectsSynchronousCancellationCallbackWithoutReentry() {
        let client = TestCameraSnapshotClient(); client.reportsFailureOnCancel = true
        let store = CameraSnapshotStore(automaticRefresh: false, makeClient: { _ in client })
        let cameraID = UUID()
        store.setAccess(allowed: true)
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: UUID(), visible: true)
        client.failWithoutDiscardingCallback(0)
        XCTAssertEqual(client.cancellations, 1)
        XCTAssertEqual(store.message(for: cameraID), "Snapshot unavailable. Tap to open the camera.")
        store.setAccess(allowed: false)
        XCTAssertNil(store.lastUpdated(for: cameraID))
        XCTAssertEqual(client.cancellations, 2)
    }

    @MainActor func testHomeKitEarlierSnapshotIsRetainedAndMarkedWithActualCaptureTime() {
        let now = Date(timeIntervalSince1970: 1_000)
        let captured = now.addingTimeInterval(-60)
        let client = TestCameraSnapshotClient()
        let store = CameraSnapshotStore(now: { now }, automaticRefresh: false, makeClient: { _ in client })
        let cameraID = UUID()
        store.setAccess(allowed: true)
        store.setVisible(cameraID: cameraID, profile: nil, consumerID: UUID(), visible: true)
        client.complete(0, at: captured)
        XCTAssertEqual(store.lastUpdated(for: cameraID), captured)
        XCTAssertTrue(store.isStale(for: cameraID))
        XCTAssertEqual(store.message(for: cameraID), "Earlier snapshot")
        store.setAccess(allowed: false)
    }
}

final class HomePadTests: XCTestCase {
    private var previousLanguage: String?
    override func setUpWithError() throws {
        previousLanguage = UserDefaults.standard.string(forKey: "appLanguage")
        UserDefaults.standard.set("en", forKey: "appLanguage")
    }
    override func tearDownWithError() throws {
        if let previousLanguage { UserDefaults.standard.set(previousLanguage, forKey: "appLanguage") }
        else { UserDefaults.standard.removeObject(forKey: "appLanguage") }
    }
    @MainActor func testDemoToggleScenesAndIsolation() {
        let home = HomeStore(); home.startDemo()
        XCTAssertEqual(home.tiles.count, 5)
        let lamp = home.tiles[0]; home.toggle(lamp); XCTAssertFalse(home.tiles[0].isOn)
        home.toggle(home.tiles[0]); XCTAssertTrue(home.tiles[0].isOn)
        home.runScene("Good night"); XCTAssertTrue(home.tiles.filter(\.writable).allSatisfy { !$0.isOn })
        home.startDemo(state: .denied); XCTAssertTrue(home.tiles.isEmpty); XCTAssertTrue(home.scenes.isEmpty)
        home.disconnect(); XCTAssertFalse(home.demo); XCTAssertEqual(home.status, .welcome); XCTAssertTrue(home.tiles.isEmpty)
    }
    @MainActor func testReadOnlySensorCannotToggle() {
        let home = HomeStore(); home.startDemo(); let sensor = home.tiles[3]
        home.toggle(sensor); XCTAssertEqual(home.tiles[3].value, "21.5 °C")
    }
    @MainActor func testEveryFailureFixtureIsClearlyDemo() {
        let home = HomeStore()
        for state in [HomeStatus.denied, .empty, .loading, .offline] {
            home.startDemo(state: state); XCTAssertTrue(home.demo); XCTAssertEqual(home.status, state); XCTAssertTrue(home.tiles.isEmpty)
        }
    }
}

extension HomePadTests {
    func testHomeKitCharacteristicsAreTypedAndUnknownControlsExcluded() {
        XCTAssertEqual(HomeValueKind(characteristicType: HMCharacteristicTypePowerState), .power)
        XCTAssertEqual(HomeValueKind(characteristicType: HMCharacteristicTypeCurrentTemperature), .temperature)
        XCTAssertEqual(HomeValueKind(characteristicType: HMCharacteristicTypeCurrentRelativeHumidity), .humidity)
        XCTAssertEqual(HomeValueKind(characteristicType: HMCharacteristicTypeBrightness), .brightness)
        XCTAssertEqual(HomeValueKind(characteristicType: HMCharacteristicTypeTargetTemperature), .targetTemperature)
        XCTAssertEqual(HomeValueKind(characteristicType: HMCharacteristicTypeRotationSpeed), .fanSpeed)
        XCTAssertEqual(HomeValueKind(characteristicType: HMCharacteristicTypeTargetLockMechanismState), .state)
        XCTAssertEqual(HomeValueKind.temperature.formatted(21.5), "21.5 °C")
        XCTAssertEqual(HomeValueKind.humidity.formatted(45), "45 %")
        XCTAssertEqual(HomeValueKind.temperature.formatted(.nan), "Unavailable")
    }
    func testAccessoryWritesRequireDeviceBoundsAndStep() {
        let bounds = HomeAdjustment(minimum: 10, maximum: 30, step: 0.5)!
        XCTAssertTrue(bounds.accepts(10)); XCTAssertTrue(bounds.accepts(30)); XCTAssertTrue(bounds.accepts(21.5))
        XCTAssertFalse(bounds.accepts(9.5)); XCTAssertFalse(bounds.accepts(30.5)); XCTAssertFalse(bounds.accepts(21.25))
        XCTAssertFalse(bounds.accepts(.infinity)); XCTAssertFalse(bounds.accepts(.nan))
        XCTAssertNil(HomeAdjustment(minimum: nil, maximum: 100, step: 1))
        XCTAssertNil(HomeAdjustment(minimum: 0, maximum: 100, step: 0))
        XCTAssertNil(HomeAdjustment(minimum: 100, maximum: 0, step: 1))
    }
    @MainActor func testUnreadablePowerCannotBecomeClimateOrAcceptNumericWrite() {
        let home = HomeStore(); home.startDemo()
        var power = home.tiles[0]; power.writable = false
        XCTAssertFalse(power.isClimate)
        XCTAssertTrue(home.tiles[3].isClimate)
        home.adjust(home.tiles[0].id, to: 50)
        XCTAssertEqual(home.tiles[0].value, "On")
        home.toggle(home.tiles[3]); XCTAssertEqual(home.tiles[3].value, "21.5 °C")
    }
    @MainActor func testPhotoAuthorizationAndSlideshowBoundaries() {
        XCTAssertTrue(PhotoLibraryStore.canRead(.authorized)); XCTAssertTrue(PhotoLibraryStore.canRead(.limited))
        for state in [PHAuthorizationStatus.notDetermined, .denied, .restricted] { XCTAssertFalse(PhotoLibraryStore.canRead(state)) }
        XCTAssertEqual(PhotoLibraryStore.nextPosition(0, count: 0), 0)
        XCTAssertEqual(PhotoLibraryStore.nextPosition(0, count: 1), 0)
        XCTAssertEqual(PhotoLibraryStore.nextPosition(1, count: 2), 0)
        XCTAssertEqual(PhotoLibraryStore.nextPosition(0, count: 2), 1)
    }
    @MainActor func testSinglePhotoRestoreDownsamplesAndClearRemovesOnlyAppCopy() throws {
        let suite = "HomePadPhotoTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "ambient-photo.jpg")
        let original = directory.appending(path: "original.jpg")
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1500), format: format).image { context in
            UIColor.systemTeal.setFill(); context.fill(CGRect(x: 0, y: 0, width: 3000, height: 1500))
        }
        let data = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        try data.write(to: file); try data.write(to: original)
        let store = PhotoLibraryStore(defaults: defaults, fileURL: file); store.restore()
        XCTAssertEqual(store.image?.size.width, 2048); XCTAssertEqual(store.image?.size.height, 1024)
        XCTAssertNil(store.selectedAlbumID)
        store.clear(); XCTAssertNil(store.image); XCTAssertEqual(store.photoCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertNil(PhotoLibraryStore.downsample(Data("not an image".utf8)))
    }
}


extension HomePadTests {
    @MainActor func testUnavailableHomeClearsCachedControlsAndPendingActions() {
        let home = HomeStore(); home.startDemo()
        home.busy.insert(home.tiles[0].id); home.sceneBusy = true; home.notice = "Earlier scene"
        home.clearUnavailableHome(.denied)
        XCTAssertTrue(home.tiles.isEmpty); XCTAssertTrue(home.scenes.isEmpty)
        XCTAssertTrue(home.cameras.isEmpty); XCTAssertTrue(home.homes.isEmpty)
        XCTAssertTrue(home.busy.isEmpty); XCTAssertFalse(home.sceneBusy)
        XCTAssertNil(home.notice); XCTAssertEqual(home.homeName, "HomePad")
        XCTAssertEqual(home.status, .denied)
    }
    @MainActor func testStoppingAudioClearsPersonalFileMetadata() {
        let audio = AudioStore(); audio.title = "Private recording"; audio.message = "Playing"
        audio.stop()
        XCTAssertEqual(audio.title, "Your room. Your soundtrack.")
        XCTAssertFalse(audio.playing); XCTAssertNil(audio.player.currentItem)
    }
}

extension HomePadTests {
    func testSwipeDirectionLocksAndRejectsAmbiguousDrags() {
        XCTAssertNil(DashboardSwipe.classify(x: 20, y: 20))
        XCTAssertNil(DashboardSwipe.classify(x: 100, y: 95))
        XCTAssertEqual(DashboardSwipe.classify(x: -120, y: 20), .left)
        XCTAssertEqual(DashboardSwipe.classify(x: 120, y: -20), .right)
        XCTAssertEqual(DashboardSwipe.classify(x: 15, y: -100), .up)
        XCTAssertEqual(DashboardSwipe.classify(x: -15, y: 100), .down)
    }
    func testPageEdgesDoNotWrapUnexpectedly() {
        XCTAssertEqual(DashboardPage.overview.adjacent(forward: false), .overview)
        XCTAssertEqual(DashboardPage.settings.adjacent(forward: true), .settings)
        XCTAssertEqual(DashboardPage.home.adjacent(forward: false), .overview)
        XCTAssertEqual(DashboardPage.overview.adjacent(forward: true), .home)
        XCTAssertEqual(DashboardPage.clock.adjacent(forward: false), .home)
        XCTAssertEqual(DashboardPage.settings.adjacent(forward: false), .music)
        XCTAssertEqual(DashboardPage.music.adjacent(forward: false), .photos)
        XCTAssertEqual(DashboardPage.photos.adjacent(forward: true), .music)
        XCTAssertEqual(DashboardPage(rawValue: 3), .photos)
    }
    func testCarouselWindowIncludesSelectionWithoutOverflowingTile() {
        XCTAssertEqual(CarouselPosition.visibleIndices(selection: 0, count: 0), [])
        XCTAssertEqual(CarouselPosition.visibleIndices(selection: 0, count: 3), [0, 1, 2])
        XCTAssertEqual(CarouselPosition.visibleIndices(selection: 0, count: 20), [0, 1, 2, 3, 4])
        XCTAssertEqual(CarouselPosition.visibleIndices(selection: 10, count: 20), [8, 9, 10, 11, 12])
        XCTAssertEqual(CarouselPosition.visibleIndices(selection: 19, count: 20), [15, 16, 17, 18, 19])
        XCTAssertEqual(CarouselPosition.visibleIndices(selection: 30, count: 20), [15, 16, 17, 18, 19])
    }
}

extension HomePadTests {
    @MainActor func testWidgetStacksNeverShareContentAndKeepReferenceCategories() {
        let home = HomeStore(); home.startDemo()
        let stacks = (0..<6).map { DashboardWidget.options(for: $0, tiles: home.tiles, scenes: home.scenes) }
        let all = stacks.flatMap { $0 }
        XCTAssertEqual(Set(all).count, all.count)
        XCTAssertEqual(stacks[1], [.clock]); XCTAssertEqual(stacks[2], [.empty(2)])
        XCTAssertFalse(all.contains(.photo)) // Photos belong only to Overview and the Photos page.
        XCTAssertEqual(stacks[4], [.accessory(home.tiles[2].id)])
        XCTAssertEqual(stacks[5], [.accessory(home.tiles[0].id), .accessory(home.tiles[1].id)])
        XCTAssertEqual(stacks[0].first, .climate(home.tiles[4].id))
        let empty = (0..<6).flatMap { DashboardWidget.options(for: $0, tiles: [], scenes: []) }
        XCTAssertEqual(Set(empty).count, empty.count)
        let kitchen = home.tiles.filter { $0.room == "Kitchen" }
        XCTAssertEqual(DashboardWidget.options(for: 4, tiles: kitchen, scenes: []), [.empty(4)])
        XCTAssertEqual(DashboardWidget.options(for: 5, tiles: kitchen, scenes: []), [.accessory(home.tiles[0].id)])
    }
    @MainActor func testThermostatStepsRespectBoundsReachabilityAndReadOnlySensors() {
        let home = HomeStore(); home.startDemo()
        var target = home.tiles[4]
        XCTAssertEqual(target.temperatureStep(increase: true), 22.5)
        XCTAssertEqual(target.temperatureStep(increase: false), 21.5)
        target.number = 30; XCTAssertNil(target.temperatureStep(increase: true))
        target.number = 10; XCTAssertNil(target.temperatureStep(increase: false))
        target.number = 22.25
        XCTAssertEqual(target.temperatureStep(increase: true), 22.5)
        XCTAssertEqual(target.temperatureStep(increase: false), 22)
        target.reachable = false; XCTAssertNil(target.temperatureStep(increase: true))
        target.reachable = true; target.writable = false; XCTAssertNil(target.temperatureStep(increase: true))
        XCTAssertNil(home.tiles[3].temperatureStep(increase: true))
        let id = home.tiles[4].id
        home.adjust(id, to: 22.5); XCTAssertEqual(home.tiles[4].number, 22.5)
        home.adjust(id, to: 30.5); XCTAssertEqual(home.tiles[4].number, 22.5)
        home.busy.insert(id); home.adjust(id, to: 23); XCTAssertEqual(home.tiles[4].number, 22.5)
        home.busy.remove(id); home.runScene("Good night")
        XCTAssertEqual(home.tiles[4].value, "22.5 °C")
        home.startDemo(); XCTAssertEqual(home.tiles[4].number, 22)
    }
    func testPlayingArtworkDecoratesOnlyHomeAndClock() {
        for page in DashboardPage.allCases {
            XCTAssertEqual(MusicArtworkBackdropPolicy.shows(on: page, enabled: true, playing: true, hasArtwork: true, localFileSelected: false),
                           page == .home || page == .clock,
                           "The independent Photos page and opaque Overview must keep their own composition")
        }
    }

    func testPlayingArtworkRestoresChosenBackgroundWhenUnavailableOrPaused() {
        for page in [DashboardPage.home, .clock] {
            XCTAssertFalse(MusicArtworkBackdropPolicy.shows(on: page, enabled: false, playing: true, hasArtwork: true, localFileSelected: false))
            XCTAssertFalse(MusicArtworkBackdropPolicy.shows(on: page, enabled: true, playing: false, hasArtwork: true, localFileSelected: false))
            XCTAssertFalse(MusicArtworkBackdropPolicy.shows(on: page, enabled: true, playing: true, hasArtwork: false, localFileSelected: false))
            XCTAssertFalse(MusicArtworkBackdropPolicy.shows(on: page, enabled: true, playing: true, hasArtwork: true, localFileSelected: true))
        }
    }

}
