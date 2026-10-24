import XCTest
import UIKit
final class HomePadUITests: XCTestCase {
    func testPerformanceLaunchToResponsiveHome() {
        app.terminate()
        let options = XCTMeasureOptions(); options.iterationCount = 3
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            app.launch()
            app.terminate()
        }
    }
    func testPerformanceInteractionRecording() throws {
        // Same deterministic account data and 0.5-second readback cadence for
        // before/after recordings; no MusicKit, HomeKit or audible playback.
        app.terminate()
        app.launchArguments += ["--music-fixture", "--performance-audit", "-music.connected", "YES",
                                "-display.screenBehaviorV1", "followSystem", "-display.motionWake", "NO",
                                "-display.faceWake", "NO", "-photoSlideshow", "NO", "-musicArtworkBackground", "YES"]
        launchHome()
        XCTAssertTrue(app.staticTexts["musicValidationData"].waitForExistence(timeout: 8))
        app.buttons["homeMusicPlayback"].tap()
        XCTAssertEqual(app.buttons["homeMusicPlayback"].label, "Pause")
        // Keep input and XCTest synchronization identical between candidates.
        for _ in 0..<2 {
            tab(4)
            XCTAssertTrue(app.descendants(matching: .any)["settingsIndex"].waitForExistence(timeout: 5))
            settingsCategory("settingsDisplay")
            app.swipeUp(); app.swipeDown()
            tab(1)
            XCTAssertTrue(app.buttons["homeMusicOpen"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.buttons["homeMusicPlayback"].label, "Pause", "Returning to Home must retain the playing source")
            app.buttons["homeMusicOpen"].tap()
            waitForFixtureMusicPlayerEntry()
            tapReadyMusicButton("musicLibrary")
            XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5))
            let covers = app.descendants(matching: .any)["musicCoverFlow"]
            covers.swipeLeft(); covers.swipeRight()
            tab(1)
        }
        shot("Performance Home unchanged")
        tab(4)
        shot("Performance settings unchanged")
    }
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication(); app.launchArguments = ["--demo", "--uitesting", "-homeWidgetLayouts", "", "-homeShortcuts", "", "-appLanguage", "en", "-display.nightMode", "off", "-background.aerialSelectionV1", ""]; launchHome()
        XCTAssertTrue(app.staticTexts["demoBadge"].waitForExistence(timeout: 10))
    }
    func dismissLocationPrompt() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Don")).firstMatch
        if deny.waitForExistence(timeout: 2) { deny.tap() }
    }
    func launchHome() {
        app.launch()
        if !app.launchArguments.contains("--demo") { dismissLocationPrompt() }
        XCTAssertTrue(app.descendants(matching: .any)["homePage"].waitForExistence(timeout: 8))
        waitForLandscape()
    }
    func openPhotoSettings() {
        tab(3)
        XCTAssertTrue(app.descendants(matching: .any)["photoWall"].waitForExistence(timeout: 5))
        panel("wallAlbums")
    }
    func expandWakeStatus() {
        let disclosure = app.buttons.matching(NSPredicate(format: "label IN %@", ["Detection status", "查看检测状态"])).firstMatch
        reveal(disclosure)
        XCTAssertTrue(disclosure.exists)
        // Native Form disclosure rows activate at their trailing chevron;
        // tapping the center of the full-width AX frame hits empty space.
        disclosure.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
    }
    func waitForLandscape() {
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil)
        waitForExpectations(timeout: 8)
    }
    func waitForFixtureMusicPlayerEntry() {
        XCTAssertTrue(app.staticTexts["musicNowPlayingTitle"].waitForExistence(timeout: 5))
        let library = app.buttons["musicLibrary"]
        var lastFrame: CGRect?
        let stable = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard library.exists else { lastFrame = nil; return false }
            let frame = library.frame
            guard frame.width > 0, frame.height > 0,
                  !frame.isNull, !frame.isInfinite, self.app.frame.contains(frame) else {
                lastFrame = nil; return false
            }
            let unchanged = lastFrame == frame
            lastFrame = frame
            // Do not query an activation point while the page is still moving.
            return unchanged && library.isHittable
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [stable], timeout: 5), .completed,
                       "Wait for the actual header button to settle after Dashboard's page transition")
    }
    func openFixtureMusicLibrary() {
        app.buttons["homeMusicOpen"].tap()
        waitForFixtureMusicPlayerEntry()
        tapReadyMusicButton("musicLibrary")
        XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5),
                      "One back action must reach selectable album covers, including an unknown restored source")
        XCTAssertTrue(app.buttons["musicAlbumsTab"].isSelected)
        XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
    }
    func openFixtureMusicPlayer() {
        tapReadyMusicButton("musicMiniPlayer")
        waitForFixtureMusicPlayerEntry()
    }
    func waitForMusicMiniTitle(_ title: String, playing: Bool? = nil) {
        let mini = app.buttons["musicMiniPlayer"]
        XCTAssertTrue(mini.waitForExistence(timeout: 5))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard (mini.value as? String)?.contains(title) == true else { return false }
            guard let playing else { return true }
            let playback = self.app.buttons["musicMiniPlayback"]
            return playback.isEnabled && playback.label == (playing ? "Pause" : "Play")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    }
    func waitForFocusedMusicCover(_ identifier: String, prefix: String = "Open") {
        let cover = app.buttons[identifier]
        XCTAssertTrue(cover.waitForExistence(timeout: 5))
        var lastFrame: CGRect?
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard cover.label.hasPrefix(prefix), cover.isHittable else { lastFrame = nil; return false }
            let frame = cover.frame
            let stable = frame == lastFrame
            lastFrame = frame
            return stable
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [focused], timeout: 5), .completed)
    }
    func closeMusicSettings() {
        let done = app.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", ["Done", "完成"])).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: done)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        done.tap()
        XCTAssertTrue(app.descendants(matching: .any)["musicSettingsForm"].waitForNonExistence(timeout: 5))
    }
    func launchMusicFixtureHome() {
        app.terminate()
        app.launchArguments = ["--demo", "--uitesting", "--music-fixture", "-music.connected", "YES",
                               "-homeWidgetLayouts", "", "-homeShortcuts", "", "-appLanguage", "en",
                               "-display.nightMode", "off", "-display.screenBehaviorV1", "followSystem",
                               "-display.faceWake", "NO",
                               "-display.motionWake", "NO", "-display.proximityWake", "NO",
                               "-musicArtworkBackground", "YES", "-photoSlideshow", "NO", "-showPersonal", "NO"]
        launchHome()
        XCTAssertTrue(app.staticTexts["musicValidationData"].waitForExistence(timeout: 8))
        XCTAssertTrue((app.buttons["homeMusicOpen"].value as? String)?.contains("Synthetic song 1.1") == true)
        XCTAssertEqual(app.buttons["homeMusicPlayback"].label, "Play", "Each synthetic playback journey starts paused")
    }
    func launchMusicBoundaryFixture(extraArguments: [String], initialTitle: String, hasPlayback: Bool) {
        app.terminate()
        app.launchArguments = ["--demo", "--uitesting", "--music-fixture", "-music.connected", "YES",
                               "-homeWidgetLayouts", "", "-homeShortcuts", "", "-appLanguage", "en",
                               "-display.nightMode", "off", "-display.screenBehaviorV1", "followSystem",
                               "-display.faceWake", "NO", "-display.motionWake", "NO", "-display.proximityWake", "NO",
                               "-musicArtworkBackground", "YES", "-photoSlideshow", "NO", "-showPersonal", "NO"] + extraArguments
        launchHome()
        XCTAssertTrue(app.staticTexts["musicValidationData"].waitForExistence(timeout: 8))
        let open = app.buttons["homeMusicOpen"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let value = open.value as? String, value.contains(initialTitle) else { return false }
            // An empty queue has no observation title; wait for the connected
            // status before opening Music so readiness cannot race navigation.
            return hasPlayback || value.contains("Apple Music connected")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
        XCTAssertEqual(app.buttons["homeMusicPlayback"].isEnabled, hasPlayback)
        XCTAssertEqual(app.buttons["homeMusicPlayback"].label, "Play", "Boundary fixtures start paused and never start real playback")
    }
    func waitForMusicTitle(_ title: String) {
        let current = app.staticTexts["musicNowPlayingTitle"]
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", title), object: current)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    }
    func tapReadyMusicButton(_ identifier: String) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        button.tap()
    }
    func assertFillsViewport(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        expectation(for: NSPredicate { _, _ in
            element.frame.width >= self.app.frame.width * 0.95 && element.frame.height >= self.app.frame.height * 0.95
        }, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        XCTAssertGreaterThanOrEqual(element.frame.width, app.frame.width * 0.95, file: file, line: line)
        XCTAssertGreaterThanOrEqual(element.frame.height, app.frame.height * 0.95, file: file, line: line)
    }
    func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func showNavigation() {
        if app.descendants(matching: .any)["sideNavigation"].exists || app.descendants(matching: .any)["bottomNavigation"].exists { return }
        let toggle = app.buttons["showNavigationButton"]
        if toggle.exists {
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: toggle)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
            toggle.tap()
        }
        else {
            let column = app.descendants(matching: .any)["shortcutColumn"]
            let shortcutBounds = column.exists ? column.frame.intersection(app.frame) : .zero
            let shortcuts = [app.buttons["shortcut-controls"], app.buttons["shortcut-agenda"]]
                + app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "shortcut-")).allElementsBoundByIndex
            let shortcut = shortcuts.first { element in
                guard element.exists else { return false }
                let frame = element.frame
                return frame.width > 0 && frame.height > 0 && shortcutBounds.contains(CGPoint(x: frame.midX, y: frame.midY))
            }
            if let shortcut { shortcut.press(forDuration: 1.2) }
            else if app.descendants(matching: .any)["homeWidget-slot-0"].exists {
                let widget = app.descendants(matching: .any)["homeWidget-slot-0"]
                let grid = app.descendants(matching: .any)["homeControlGrid"]
                for _ in 0..<6 {
                    let frame = widget.frame
                    if grid.frame.intersection(app.frame).contains(CGPoint(x: frame.midX, y: frame.midY)) { break }
                    grid.swipeDown()
                }
                let frame = widget.frame
                XCTAssertTrue(grid.frame.intersection(app.frame).contains(CGPoint(x: frame.midX, y: frame.midY)))
                widget.press(forDuration: 1.2)
            } else {
                let point = app.frame.width > app.frame.height ? CGVector(dx: 0.04, dy: 0.5) : CGVector(dx: 0.5, dy: 0.04)
                app.coordinate(withNormalizedOffset: point).tap()
                XCTAssertTrue(app.buttons["tab-0"].waitForExistence(timeout: 3))
                return
            }
            let menu = app.buttons["contextShowNavigation"]
            XCTAssertTrue(menu.waitForExistence(timeout: 3)); menu.tap()
        }
        XCTAssertTrue(app.buttons["tab-0"].waitForExistence(timeout: 3))
    }
    func revealNavigation(_ element: XCUIElement, towardTop: Bool = false) {
        for _ in 0..<6 {
            if element.isHittable { return }
            let rail = app.descendants(matching: .any)["sideNavigation"]
            guard rail.exists else { return }
            if towardTop { rail.swipeDown() } else { rail.swipeUp() }
        }
    }
    func tab(_ index: Int) {
        showNavigation()
        let button = app.buttons["tab-\(index)"]
        revealNavigation(button, towardTop: true); XCTAssertTrue(button.isHittable); button.tap()
        let marker = ["overviewBoard", "homePage", "fullClock", "photoWall", "settingsPage", "musicPage"][index]
        let destination = app.descendants(matching: .any)[marker]
        let navigationFinished = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            destination.exists && !self.app.descendants(matching: .any)["sideNavigation"].exists
                && !self.app.descendants(matching: .any)["bottomNavigation"].exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [navigationFinished], timeout: 5), .completed,
                       "Tapping tab-\(index) must show \(marker) and close navigation")
    }
    func navigationAction(_ identifier: String) {
        showNavigation()
        let button = app.buttons[identifier]
        revealNavigation(button); XCTAssertTrue(button.isHittable); button.tap()
    }
    func panel(_ identifier: String) {
        navigationAction(identifier)
        XCTAssertTrue(app.buttons["dismissPanel"].waitForExistence(timeout: 3))
    }
    func cycleWidget(_ slot: Int, forward: Bool = true) {
        let widget = app.descendants(matching: .any)["homeWidget-slot-\(slot)"]
        let grid = app.descendants(matching: .any)["homeControlGrid"]
        for _ in 0..<6 {
            if widget.isHittable { break }
            if slot == 0 { grid.swipeDown() } else { grid.swipeUp() }
        }
        XCTAssertTrue(widget.isHittable); widget.press(forDuration: 1.2)
        let action = app.buttons["context\(forward ? "Next" : "Previous")Widget-slot-\(slot)"]
        XCTAssertTrue(action.waitForExistence(timeout: 3)); action.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: action)
        waitForExpectations(timeout: 5)
    }
    func closePanel() {
        let done = app.buttons["dismissPanel"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: done)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "Done must actually dismiss the panel before navigation continues")
    }
    func reveal(_ element: XCUIElement, towardTop: Bool = false) {
        for _ in 0..<8 {
            if element.isHittable { return }
            let gallery = app.descendants(matching: .any)["wallpaperGalleryScroll"]
            if gallery.exists {
                if towardTop { gallery.swipeDown() } else { gallery.swipeUp() }
            } else if let form = app.collectionViews.allElementsBoundByIndex.last {
                if towardTop { form.swipeDown() } else { form.swipeUp() }
            } else if towardTop { app.swipeDown() } else { app.swipeUp() }
        }
    }
    func swipePage(forward: Bool) {
        let viewport = app.buttons["navigationBackdrop"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 3))
        let start = viewport.coordinate(withNormalizedOffset: CGVector(dx: forward ? 0.85 : 0.15, dy: 0.5))
        let end = viewport.coordinate(withNormalizedOffset: CGVector(dx: forward ? 0.15 : 0.85, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
    func settingsCategory(_ identifier: String) {
        let index = app.descendants(matching: .any)["settingsIndex"]
        for _ in 0..<6 {
            if index.exists { break }
            // Pages is also a navigation-bar button now. Only a native back
            // button may unwind the settings stack.
            let back = app.navigationBars.buttons.matching(NSPredicate(format: "identifier != %@", "showNavigationButton")).firstMatch
            if back.exists { back.tap() } else { break }
        }
        XCTAssertTrue(index.waitForExistence(timeout: 5))
        let home = app.buttons["settingsHome"]
        reveal(home, towardTop: true); XCTAssertTrue(home.isHittable)
        let entry = app.buttons[identifier]
        reveal(entry)
        XCTAssertTrue(entry.waitForExistence(timeout: 5)); XCTAssertTrue(entry.isHittable); entry.tap()
    }
    func openWakeSettings() {
        settingsCategory("settingsDisplay")
        let wake = app.buttons["settingsWake"]
        reveal(wake); XCTAssertTrue(wake.isHittable); wake.tap()
    }
    func openLanguageMenu() {
        settingsCategory("settingsGeneral")
        let picker = app.buttons["appLanguagePicker"]
        reveal(picker)
        // A Form exposes the whole row as its AX frame, while the native menu
        // opens from the visible trailing current-value label.
        let currentValue = picker.staticTexts.firstMatch
        if currentValue.isHittable { currentValue.tap() }
        else { picker.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap() }
    }
    // A reproducible capture journey using only demo accessories and seeded simulator photos.
    // scripts/record_demo.py records between the READY and DONE markers.
    func testReadmeDemoJourney() {
        // This journey observes two real 30-second photo transitions. Isolate
        // its paging assertions from another test's persisted idle-dim mode;
        // the separate idle journey verifies wake-before-control behavior.
        app.terminate()
        app.launchArguments += ["-display.screenBehaviorV1", "followSystem"]
        app.resetAuthorizationStatus(for: .photos); launchHome()
        openPhotoSettings()
        reveal(app.buttons["connectPhotos"])
        XCTAssertTrue(app.buttons["connectPhotos"].waitForExistence(timeout: 5)); app.buttons["connectPhotos"].tap()
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons.matching(NSPredicate(format: "label IN %@", ["Allow Full Access", "允许完全访问"])).firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 5)); allow.tap()
        reveal(app.buttons["album-all"])
        XCTAssertTrue(app.buttons["album-all"].waitForExistence(timeout: 8)); app.buttons["album-all"].tap()
        reveal(app.images["photoPreview"], towardTop: true)
        XCTAssertTrue(app.images["photoPreview"].waitForExistence(timeout: 10)); closePanel()
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil)
        waitForExpectations(timeout: 8)
        tab(0)
        print("HOMEVIEWPAD_DEMO_READY")
        Thread.sleep(forTimeInterval: 3)
        swipePage(forward: true)
        XCTAssertTrue(app.buttons["temperatureUp"].waitForExistence(timeout: 3))
        app.buttons["temperatureUp"].tap()
        XCTAssertEqual(app.staticTexts["temperatureValue"].label, "22.5")
        Thread.sleep(forTimeInterval: 1)
        app.buttons["temperatureDown"].tap()
        app.buttons["accessory-Pendant lights"].tap()
        Thread.sleep(forTimeInterval: 1)
        app.buttons["accessory-Pendant lights"].tap()
        cycleWidget(5)
        XCTAssertTrue(app.buttons["accessory-Reading lamp"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1)
        cycleWidget(5)
        app.descendants(matching: .any)["homeWidget-slot-0"].swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["fullClock"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 2)
        print("HOMEVIEWPAD_DEMO_PHOTOS")
        swipePage(forward: true)
        XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 3))
        let wall = app.descendants(matching: .any)["photoWall"]
        shot("README photo wall 1")
        // Capture two real 30-second album transitions without changing app timing.
        for index in 2...3 {
            let previousPhoto = wall.value as? String
            expectation(for: NSPredicate { _, _ in wall.value as? String != previousPhoto }, evaluatedWith: nil)
            waitForExpectations(timeout: 36)
            print("HOMEVIEWPAD_DEMO_PHOTO_\(index)")
            shot("README photo wall \(index)")
        }
        Thread.sleep(forTimeInterval: 2)
        print("HOMEVIEWPAD_DEMO_RETURN")
        swipePage(forward: false); swipePage(forward: false); swipePage(forward: false)
        XCTAssertTrue(app.descendants(matching: .any)["overviewBoard"].waitForExistence(timeout: 3))
        showNavigation(); Thread.sleep(forTimeInterval: 2)
        navigationAction("hideNavigation")
        Thread.sleep(forTimeInterval: 2)
        print("HOMEVIEWPAD_DEMO_DONE")
        shot("README demo dashboard")
    }
    func testDashboardRepeatedControlsAndSceneCancellation() {
        shot("Landscape dashboard")
        let lamp = app.buttons["accessory-Pendant lights"]
        XCTAssertEqual(lamp.value as? String, "On")
        lamp.tap(); XCTAssertTrue(lamp.label.contains("Off")); XCTAssertEqual(lamp.value as? String, "Off")
        lamp.tap(); XCTAssertTrue(lamp.label.contains("On")); XCTAssertEqual(lamp.value as? String, "On")
        panel("allControls")
        reveal(app.buttons["scene-Good night"])
        app.buttons["scene-Good night"].tap(); app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "accessory-Pendant lights").firstMatch.label.contains("On"))
        app.buttons["scene-Good night"].tap(); app.buttons["Run scene"].tap()
        XCTAssertTrue(app.staticTexts["sceneNotice"].waitForExistence(timeout: 3))
        closePanel()
        XCTAssertTrue(lamp.label.contains("Off"))
    }
    func testFullscreenHomeReferenceGeometryAndHiddenNavigation() {
        var firstSide: CGFloat?
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation; waitForLandscape()
            let homePage = app.descendants(matching: .any)["homePage"]
            XCTAssertTrue(homePage.waitForExistence(timeout: 5))
            // A contain group's AX bounds may follow its children. The existing
            // wallpaper navigation target represents the actual full viewport.
            let viewport = app.buttons["navigationBackdrop"]
            assertFillsViewport(viewport)
            print("Home geometry: app=\(app.frame), content container=\(homePage.frame), viewport=\(viewport.frame)")
            let widgets = (0..<6).map { app.descendants(matching: .any)["homeWidget-slot-\($0)"] }
            let hero = widgets[0], clock = widgets[1], camera = widgets[2]
            let scene = widgets[3], fan = widgets[4], lights = widgets[5]
            let agenda = app.buttons["shortcut-camera"], music = app.descendants(matching: .any)["shortcut-music"], controls = app.buttons["shortcut-controls"]
            expectation(for: NSPredicate { _, _ in
                (widgets + [agenda, music, controls]).allSatisfy { $0.exists && $0.frame.width > 0 && $0.frame.height > 0 }
            }, evaluatedWith: nil)
            waitForExpectations(timeout: 5)
            let expectedSide = min((app.frame.width - 60) / 4.2, (app.frame.height - 48) / 3)
            XCTAssertEqual(clock.frame.width, expectedSide, accuracy: 2)
            XCTAssertEqual(clock.frame.height, expectedSide, accuracy: 2)
            if let firstSide { XCTAssertEqual(clock.frame.width, firstSide, accuracy: 2) }
            else { firstSide = clock.frame.width }
            XCTAssertEqual(hero.frame.width, clock.frame.width * 2 + 12, accuracy: 2)
            XCTAssertEqual(hero.frame.height, clock.frame.height * 2 + 12, accuracy: 2)
            XCTAssertEqual(hero.frame.width, hero.frame.height, accuracy: 2)
            XCTAssertEqual(hero.frame.minY, clock.frame.minY, accuracy: 2)
            XCTAssertEqual(hero.frame.minX, scene.frame.minX, accuracy: 2)
            XCTAssertEqual(clock.frame.minX, camera.frame.minX, accuracy: 2)
            XCTAssertEqual(clock.frame.minX, lights.frame.minX, accuracy: 2)
            XCTAssertEqual(hero.frame.maxY, camera.frame.maxY, accuracy: 2)
            XCTAssertEqual(scene.frame.minY, fan.frame.minY, accuracy: 2)
            XCTAssertEqual(scene.frame.minY, lights.frame.minY, accuracy: 2)
            XCTAssertEqual(agenda.frame.minY, clock.frame.minY, accuracy: 2)
            XCTAssertEqual(music.frame.minY, camera.frame.minY, accuracy: 2)
            XCTAssertEqual(controls.frame.minY, lights.frame.minY, accuracy: 2)
            XCTAssertEqual(clock.frame.maxX + 12, agenda.frame.minX, accuracy: 2)
            for widget in [camera, scene, fan, lights] {
                XCTAssertEqual(widget.frame.width, clock.frame.width, accuracy: 2)
                XCTAssertEqual(widget.frame.height, clock.frame.height, accuracy: 2)
            }
            for sidebar in [agenda, music, controls] {
                XCTAssertEqual(sidebar.frame.height, expectedSide, accuracy: 2)
                XCTAssertGreaterThan(sidebar.frame.width, expectedSide)
                XCTAssertEqual(sidebar.frame.width, app.frame.width - 24 - (expectedSide * 3 + 24) - 12, accuracy: 2)
            }
            XCTAssertEqual(hero.frame.minX, app.frame.minX + 12, accuracy: 2)
            XCTAssertEqual(controls.frame.maxX, app.frame.maxX - 12, accuracy: 2)
            XCTAssertEqual(controls.frame.maxX - hero.frame.minX, app.frame.width - 24, accuracy: 2)
            XCTAssertEqual(controls.frame.maxY - hero.frame.minY, expectedSide * 3 + 24, accuracy: 2)
            XCTAssertEqual((hero.frame.minX + controls.frame.maxX) / 2, app.frame.midX, accuracy: 2)
            XCTAssertEqual(hero.frame.minY, app.frame.minY + 12, accuracy: 2)
            XCTAssertLessThanOrEqual(controls.frame.maxY, app.frame.maxY - 10)
            XCTAssertFalse(app.buttons["photoWidget"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["dashboardHeader"].exists)
            XCTAssertFalse(app.buttons["homeRoomPicker"].exists)
            XCTAssertFalse(app.buttons["addHomeWidget"].exists)
            XCTAssertFalse(app.buttons["addShortcut"].exists)
            XCTAssertFalse(app.buttons["tab-0"].exists)
            XCTAssertFalse(app.navigationBars.firstMatch.exists)
            shot(orientation == .landscapeLeft ? "Square Home landscape left" : "Square Home landscape right")
        }
        showNavigation()
        XCTAssertGreaterThan(app.buttons["tab-0"].frame.minX, app.frame.width * 0.8)
        shot("Right navigation over fullscreen Home")
        navigationAction("hideNavigation")
        XCTAssertFalse(app.buttons["tab-0"].exists)
        XCTAssertTrue(app.buttons["accessory-Pendant lights"].label.contains("On"))
    }
    func testFullscreenClockAndSettingsInBothLandscapeDirections() {
        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation; waitForLandscape()
            tab(2)
            let dial = app.descendants(matching: .any)["fullClockDial"]
            let information = app.descendants(matching: .any)["fullClockInformation"]
            XCTAssertTrue(dial.waitForExistence(timeout: 5)); XCTAssertTrue(information.exists)
            let dialFrame = dial.frame, informationFrame = information.frame
            XCTAssertEqual(dialFrame.width, dialFrame.height, accuracy: 2)
            XCTAssertGreaterThanOrEqual(dialFrame.width, min(app.frame.width, app.frame.height) * 0.75)
            for frame in [dialFrame, informationFrame] {
                XCTAssertGreaterThanOrEqual(frame.minX, app.frame.minX - 2)
                XCTAssertGreaterThanOrEqual(frame.minY, app.frame.minY - 2)
                XCTAssertLessThanOrEqual(frame.maxX, app.frame.maxX + 2)
                XCTAssertLessThanOrEqual(frame.maxY, app.frame.maxY + 2)
            }
            XCTAssertLessThanOrEqual(dialFrame.maxX, informationFrame.minX)
            XCTAssertTrue((dial.value as? String ?? "").contains("10:09"))
            XCTAssertTrue(information.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "10:09")).firstMatch.exists)
            XCTAssertTrue(app.staticTexts["demoBadge"].exists)
            shot(orientation == .landscapeLeft ? "Fullscreen Clock landscape left" : "Fullscreen Clock landscape right")
            tab(4)
            assertFillsViewport(app.descendants(matching: .any)["settingsPage"])
            for entry in ["settingsHome", "settingsDisplay", "settingsContentPrivacy", "settingsGeneral", "settingsCalendar", "settingsWeather", "settingsPermissions"] {
                reveal(app.buttons[entry]); XCTAssertTrue(app.buttons[entry].isHittable)
            }
            reveal(app.buttons["settingsHome"], towardTop: true)
            shot(orientation == .landscapeLeft ? "Fullscreen Settings landscape left" : "Fullscreen Settings landscape right")
        }
    }
    func testLandscapeControlsAndNavigationSurviveDeviceRotation() {
        let originalSize = app.frame.size
        let lamp = app.buttons["accessory-Pendant lights"]
        for orientation in [UIDeviceOrientation.portrait, .portraitUpsideDown, .landscapeRight, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation; waitForLandscape()
            XCTAssertEqual(app.frame.width, originalSize.width, accuracy: 2)
            XCTAssertEqual(app.frame.height, originalSize.height, accuracy: 2)
            XCTAssertTrue(app.descendants(matching: .any)["homePage"].exists)
            XCTAssertEqual(lamp.value as? String, "On")
            lamp.tap(); XCTAssertEqual(lamp.value as? String, "Off")
            lamp.tap(); XCTAssertEqual(lamp.value as? String, "On")
            showNavigation()
            XCTAssertTrue(app.descendants(matching: .any)["sideNavigation"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["bottomNavigation"].exists)
            // iPadOS compatibility mode scales descendant AX coordinates when
            // held upright, while app.frame remains the unscaled scene size.
            // Compare the navigation with the viewport in the same coordinates.
            let viewport = app.buttons["navigationBackdrop"].frame
            print("Rotation \(orientation.rawValue): app=\(app.frame), viewport=\(viewport), rail=\(app.descendants(matching: .any)["sideNavigation"].frame), tab=\(app.buttons["tab-0"].frame)")
            XCTAssertGreaterThan(viewport.width, viewport.height)
            XCTAssertEqual(viewport.width / viewport.height, originalSize.width / originalSize.height, accuracy: 0.01)
            XCTAssertGreaterThan(app.buttons["tab-0"].frame.minX, viewport.minX + viewport.width * 0.8)
            revealNavigation(app.buttons["tab-4"], towardTop: true)
            XCTAssertEqual(app.buttons["tab-0"].frame.midX, app.buttons["tab-4"].frame.midX, accuracy: 2)
            navigationAction("hideNavigation")
            XCTAssertFalse(app.buttons["tab-0"].exists)
        }
        shot("Landscape Home after device rotations")
    }
    func testBlackOverviewLayoutAndLiveWeatherDisclosure() {
        tab(0)
        let date = app.descendants(matching: .any)["overviewDate"]
        let clock = app.descendants(matching: .any)["overviewClock"]
        let album = app.buttons["overviewAlbum"]
        let weather = app.descendants(matching: .any)["overviewWeather"]
        func assertGrid() {
            // SwiftUI can expose intermediate accessibility frames during a page transition.
            expectation(for: NSPredicate { _, _ in
                [date, clock, album, weather].allSatisfy { widget in
                    guard widget.exists else { return false }
                    let frame = widget.frame
                    return frame.width > 0 && abs(frame.width - frame.height) < 2
                }
            }, evaluatedWith: nil)
            waitForExpectations(timeout: 5)
            for widget in [date, clock, album, weather] {
                XCTAssertTrue(widget.exists)
                let frame = widget.frame
                XCTAssertEqual(frame.width, frame.height, accuracy: 2)
            }
            XCTAssertEqual(date.frame.minY, clock.frame.minY, accuracy: 2)
            XCTAssertEqual(date.frame.minX, album.frame.minX, accuracy: 2)
            XCTAssertEqual(clock.frame.minX, weather.frame.minX, accuracy: 2)
            XCTAssertEqual(album.frame.minY, weather.frame.minY, accuracy: 2)
            XCTAssertLessThan(date.frame.maxY, album.frame.minY)
            XCTAssertFalse(app.buttons["tab-0"].exists)
            XCTAssertFalse(app.navigationBars.firstMatch.exists)
        }
        assertGrid(); XCTAssertTrue(weather.label.contains("54°"))
        XCTAssertTrue(app.staticTexts["demoBadge"].exists)
        shot("Black overview landscape left")
        album.tap(); XCTAssertTrue(app.buttons["singlePhotoPicker"].waitForExistence(timeout: 3)); closePanel()
        XCUIDevice.shared.orientation = .landscapeRight
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil)
        waitForExpectations(timeout: 8)
        assertGrid(); shot("Black overview landscape right")
        showNavigation(); XCTAssertTrue(app.descendants(matching: .any)["sideNavigation"].exists)
        navigationAction("hideNavigation")
        swipePage(forward: false); XCTAssertTrue(album.exists)
        swipePage(forward: true); XCTAssertTrue(app.descendants(matching: .any)["shortcut-camera"].waitForExistence(timeout: 3))
        swipePage(forward: true); XCTAssertTrue(app.descendants(matching: .any)["fullClock"].waitForExistence(timeout: 3))
        tab(0); assertGrid()
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: weather); waitForExpectations(timeout: 5)
        weather.tap()
        XCTAssertTrue(app.staticTexts["weatherDemoNotice"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.textFields["weatherCitySearch"].exists)
        closePanel()
        app.terminate(); app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["homePage"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["shortcut-camera"].exists)
        XCTAssertFalse(app.buttons["photoWidget"].exists)
    }
    func testHorizontalPagingAndIndependentWidgetSwitching() {
        let camera = app.descendants(matching: .any)["shortcut-camera"]
        XCTAssertTrue(camera.exists); XCTAssertFalse(app.buttons["photoWidget"].exists)
        XCTAssertFalse(app.buttons["nextWidget-2"].exists)
        XCTAssertTrue(camera.exists) // Single camera category never borrows another stack's content.
        XCTAssertTrue(app.descendants(matching: .any)["homeWidget-slot-0"].exists)
        XCTAssertEqual(app.staticTexts["temperatureValue"].label, "22.0")
        XCTAssertTrue(app.buttons["temperatureUp"].isEnabled)
        XCTAssertFalse(app.buttons["dismissPanel"].exists)
        let lamp = app.buttons["accessory-Pendant lights"]
        cycleWidget(5)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: lamp); waitForExpectations(timeout: 3)
        XCTAssertEqual(app.buttons.matching(identifier: "accessory-Reading lamp").count, 1)
        XCTAssertTrue(app.buttons["accessory-Ceiling fan"].exists)
        XCTAssertTrue(camera.exists)
        cycleWidget(5)
        XCTAssertTrue(lamp.waitForExistence(timeout: 3)); XCTAssertTrue(lamp.label.contains("On"))
        app.descendants(matching: .any)["homeWidget-slot-0"].swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["fullClock"].waitForExistence(timeout: 3))
        shot("Clock page")
        swipePage(forward: true); XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 3))
        // Photo configuration remains on the separate Photos page.
        panel("wallAlbums")
        let clear = app.buttons["clearPhotos"]; reveal(clear); clear.tap(); closePanel()
        XCTAssertTrue(app.buttons["chooseWallAlbum"].exists)
        swipePage(forward: true); XCTAssertTrue(app.descendants(matching: .any)["musicPage"].waitForExistence(timeout: 3))
        swipePage(forward: true); XCTAssertTrue(app.buttons["settingsHome"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Start timer"].exists)
        swipePage(forward: false); XCTAssertTrue(app.descendants(matching: .any)["musicPage"].waitForExistence(timeout: 3))
        swipePage(forward: false); XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 3))
        tab(1); XCTAssertTrue(camera.exists); XCTAssertTrue(lamp.label.contains("On"))
        XCTAssertFalse(app.buttons["photoWidget"].exists)
        XCTAssertFalse(app.buttons["tab-0"].exists)
    }
    func testThermostatArrowsAndTransientIndicators() {
        let value = app.staticTexts["temperatureValue"]
        let up = app.buttons["temperatureUp"], down = app.buttons["temperatureDown"]
        XCTAssertEqual(value.label, "22.0")
        up.tap(); XCTAssertEqual(value.label, "22.5")
        down.tap(); XCTAssertEqual(value.label, "22.0")
        let hero = app.descendants(matching: .any)["homeWidget-slot-0"]
        XCTAssertTrue(hero.frame.contains(value.frame))
        XCTAssertTrue(hero.frame.contains(up.frame)); XCTAssertTrue(hero.frame.contains(down.frame))
        shot("Thermostat complete digits and arrows")
        let position = app.descendants(matching: .any)["widgetPosition-0"]
        XCTAssertFalse(position.exists)
        cycleWidget(0)
        XCTAssertEqual(value.label, "21.5")
        XCTAssertFalse(up.isEnabled); XCTAssertFalse(down.isEnabled)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: position)
        waitForExpectations(timeout: 4)
        XCTAssertTrue(app.descendants(matching: .any)["shortcut-camera"].exists); XCTAssertFalse(app.buttons["photoWidget"].exists)
        let clock = app.descendants(matching: .any)["homeWidget-slot-1"]
        XCTAssertTrue(clock.exists)
        XCTAssertTrue(clock.descendants(matching: .any).matching(NSPredicate(format: "label == %@ AND value CONTAINS %@", "Analog clock", "10:09")).firstMatch.exists)
        cycleWidget(0); XCTAssertTrue(up.isEnabled)
        XCTAssertEqual(value.label, "22.0")
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(up.waitForExistence(timeout: 5))
        tab(4); XCTAssertTrue(app.buttons["settingsHome"].waitForExistence(timeout: 3))
        showNavigation(); revealNavigation(app.buttons["tab-5"]); XCTAssertTrue(app.buttons["tab-5"].exists)
        XCTAssertFalse(app.buttons["Start timer"].exists)
    }
    func testLandscapeCameraAndAgenda() {
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil); waitForExpectations(timeout: 8)
        panel("agendaCard"); XCTAssertTrue(app.staticTexts["DEMO · No calendar is connected"].exists); XCTAssertFalse(app.staticTexts["17:30 · Water the plants"].exists); closePanel()
        panel("cameraCard"); XCTAssertTrue(app.staticTexts["Demo camera"].waitForExistence(timeout: 5)); shot("Camera placeholder"); closePanel()
        tab(2); shot("Clock landscape")
    }
    func testFailureStatesAndReturnToRealOnboarding() {
        for state in ["denied", "empty", "offline", "loading"] {
            tab(4); settingsCategory("settingsGeneral"); app.buttons["advancedDiagnostics"].tap(); reveal(app.buttons["simulate-\(state)"]); app.buttons["simulate-\(state)"].tap()
            XCTAssertTrue(app.staticTexts["homeStateTitle"].waitForExistence(timeout: 3)); XCTAssertTrue(app.staticTexts["demoBadge"].exists); shot("State \(state)")
        }
        tab(4); settingsCategory("settingsHome"); app.buttons["disconnectHome"].tap()
        XCTAssertTrue(app.buttons["connectHome"].exists); XCTAssertFalse(app.staticTexts["demoBadge"].exists); shot("Real onboarding")
        tab(4); settingsCategory("settingsHome")
        XCTAssertFalse(app.buttons["disconnectHome"].exists)
        XCTAssertTrue(app.buttons["connectHome"].exists)
        tab(1); app.buttons["exploreDemo"].tap(); XCTAssertTrue(app.staticTexts["demoBadge"].exists)
    }
    func testLiveWeatherCityChoiceSearchAndRestore() {
        app.terminate(); app.launchArguments = ["--fresh", "--uitesting", "-homeWidgetLayouts", "", "-homeShortcuts", "", "-appLanguage", "en", "-display.nightMode", "off"]; app.launch(); tab(0)
        let weather = app.buttons["overviewWeather"]
        XCTAssertTrue(weather.waitForExistence(timeout: 5)); weather.tap()
        let remove = app.buttons["removeWeatherCity"]
        if remove.exists { reveal(remove); remove.tap() }
        let unconfigured = app.staticTexts["weatherCityUnconfigured"]
        reveal(unconfigured, towardTop: true); XCTAssertTrue(unconfigured.exists)
        XCTAssertFalse(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists)
        let units = app.segmentedControls["weatherTemperatureUnit"]
        reveal(units); units.buttons["System"].tap(); XCTAssertTrue(units.buttons["System"].isSelected)
        let search = app.textFields["weatherCitySearch"]
        reveal(search, towardTop: true); search.tap(); search.typeText("New York\n")
        let result = app.buttons["weatherCity-5128581"]
        XCTAssertTrue(result.waitForExistence(timeout: 20)); reveal(result); result.tap()
        let selected = app.staticTexts["weatherSelectedCity"]
        reveal(selected, towardTop: true); XCTAssertTrue(selected.label.contains("New York"))
        XCTAssertTrue(app.staticTexts["weatherLiveReading"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["demoBadge"].exists)
        shot("Explicit city and regional weather units")
        closePanel(); shot("Live weather overview")
        app.terminate(); app.launch(); tab(0)
        XCTAssertTrue(weather.waitForExistence(timeout: 5)); weather.tap()
        reveal(selected, towardTop: true); XCTAssertTrue(selected.label.contains("New York"))
        reveal(units); XCTAssertTrue(units.buttons["System"].isSelected)
        reveal(remove, towardTop: true); remove.tap()
        reveal(unconfigured, towardTop: true); XCTAssertTrue(unconfigured.exists)
        closePanel(); app.terminate(); app.launch(); tab(0); weather.tap()
        XCTAssertTrue(unconfigured.waitForExistence(timeout: 5))
        XCTAssertFalse(selected.exists)
        closePanel()
    }
    func testOneShotLocationPermissionIsExplicitAndDenialDoesNotAutomaticallyRetry() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        // A failed prior run can leave this app's native location alert over SpringBoard.
        // Dismiss only that specific leftover before resetting consent for the new test.
        let previousAlert = springboard.alerts.firstMatch
        if previousAlert.exists, previousAlert.label.contains("HomePad"),
           previousAlert.label.contains("位置") || previousAlert.label.localizedCaseInsensitiveContains("location") {
            let previousDeny = previousAlert.buttons.matching(NSPredicate(format: "label IN %@", ["Don’t Allow", "Don't Allow", "不允许"])).firstMatch
            XCTAssertTrue(previousDeny.exists, "The leftover HomePad location prompt must offer the observed denial action")
            previousDeny.tap()
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: previousAlert)
            waitForExpectations(timeout: 5)
        }
        app.terminate(); app.resetAuthorizationStatus(for: .location)
        app.launchArguments = ["--fresh", "--uitesting", "-homeWidgetLayouts", "", "-homeShortcuts", "", "-appLanguage", "en", "-display.nightMode", "off"]
        app.launch(); tab(0)
        XCTAssertFalse(springboard.alerts.firstMatch.waitForExistence(timeout: 2), "Passive weather display cannot request location")
        let weather = app.buttons["overviewWeather"]
        XCTAssertTrue(weather.waitForExistence(timeout: 5)); weather.tap()
        let locate = app.buttons["useWeatherLocation"]
        reveal(locate); XCTAssertTrue(locate.label.contains("Locate once"))
        XCTAssertFalse(springboard.alerts.firstMatch.exists, "Opening city selection never asks for location")
        locate.tap()
        let allow = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Allow While Using App", "使用App时允许"])).firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 8), "An explicit tap must reach Apple's permission dialog")
        let deny = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Don’t Allow", "Don't Allow", "不允许"])).firstMatch
        XCTAssertTrue(deny.exists); deny.tap()
        let status = app.staticTexts["weatherLocationStatus"]
        reveal(status)
        expectation(for: NSPredicate { _, _ in status.label.contains("Location is off. Choose a city manually.") }, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.descendants(matching: .any)["weatherLocationProgress"].exists)
        XCTAssertFalse(app.staticTexts["weatherSelectedCity"].exists)
        XCTAssertTrue(locate.isEnabled)
        shot("Explicit one-shot location permission denial with manual city fallback")
        closePanel(); weather.tap(); reveal(locate)
        XCTAssertFalse(springboard.alerts.firstMatch.waitForExistence(timeout: 2), "Reopening weather cannot request permission or retry a fix")
        XCTAssertTrue(locate.isEnabled)
        XCTAssertFalse(app.staticTexts["demoBadge"].exists)
        closePanel()
        // Real Apple reverse-geocoding success remains a separate device/network acceptance item.
    }
    func testRealConnectionGracefulWithoutDevices() {
        app.terminate(); app.launchArguments = ["--fresh", "--uitesting", "-homeWidgetLayouts", "", "-homeShortcuts", "", "-appLanguage", "en", "-display.nightMode", "off"]; launchHome()
        XCTAssertTrue(app.buttons["connectHome"].waitForExistence(timeout: 5)); app.buttons["connectHome"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["Don’t Allow"].waitForExistence(timeout: 3) { springboard.buttons["Don’t Allow"].tap() }
        else if springboard.buttons["Don't Allow"].exists { springboard.buttons["Don't Allow"].tap() }
        expectation(for: NSPredicate { _, _ in
            ["Home access is off", "Your home starts here", "Home is taking a moment"].contains(self.app.staticTexts["homeStateTitle"].label)
        }, evaluatedWith: nil)
        waitForExpectations(timeout: 25); XCTAssertFalse(app.staticTexts["demoBadge"].exists); shot("Real connection without devices")
    }
    func testSystemPickerDismissal() {
        openPhotoSettings()
        XCTAssertTrue(app.buttons["singlePhotoPicker"].waitForExistence(timeout: 3))
        app.buttons["singlePhotoPicker"].tap()
        let cancel = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label IN %@", "Cancel", ["Cancel", "取消"])).firstMatch
        if cancel.waitForExistence(timeout: 3) { cancel.tap() } else { app.swipeDown() }
        closePanel()
        app.terminate()
        app.launchArguments = ["--fresh", "--uitesting", "-appLanguage", "en", "-display.nightMode", "off"]
        launchHome(); tab(5)
        let audioFile = app.buttons["chooseAudioFile"]
        reveal(audioFile); XCTAssertTrue(audioFile.isEnabled); audioFile.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier == %@ OR label IN %@", "Cancel", ["Cancel", "取消"])).firstMatch.waitForExistence(timeout: 5)); shot("Audio file picker"); app.buttons.matching(NSPredicate(format: "identifier == %@ OR label IN %@", "Cancel", ["Cancel", "取消"])).firstMatch.tap()
        XCTAssertTrue(app.buttons["Choose audio file"].waitForExistence(timeout: 5))
        tab(1)
        XCTAssertTrue(app.buttons["connectHome"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["exploreDemo"].exists)
        XCTAssertFalse(app.staticTexts["demoBadge"].exists)
        XCTAssertFalse(app.buttons["photoWidget"].exists)
    }
    func testPhotoLibraryDenialKeepsSinglePhotoAvailable() {
        app.resetAuthorizationStatus(for: .photos)
        launchHome() // Resetting an existing Photos grant terminates the app.
        openPhotoSettings()
        reveal(app.buttons["connectPhotos"])
        XCTAssertTrue(app.buttons["connectPhotos"].waitForExistence(timeout: 5)); app.buttons["connectPhotos"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons.matching(NSPredicate(format: "(label CONTAINS[c] %@ AND label BEGINSWITH[c] %@) OR label == %@", "Allow", "Don", "不允许")).firstMatch
        XCTAssertTrue(deny.waitForExistence(timeout: 5)); deny.tap()
        XCTAssertTrue(app.staticTexts["photosDenied"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["singlePhotoPicker"].exists); shot("Photo permission denied")
        closePanel(); XCTAssertTrue(app.descendants(matching: .any)["photoWall"].exists)
    }
    func testPhotoLibraryAlbumDisplayRotationRestoreAndRemoval() {
        app.launchArguments += ["-photoSlideshow", "YES"]
        app.resetAuthorizationStatus(for: .photos)
        launchHome()
        openPhotoSettings()
        reveal(app.buttons["connectPhotos"])
        XCTAssertTrue(app.buttons["connectPhotos"].waitForExistence(timeout: 5)); app.buttons["connectPhotos"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Allow Full Access", "允许完全访问"])).firstMatch
        XCTAssertTrue(allow.waitForExistence(timeout: 5)); allow.tap()
        let album = app.buttons["album-all"]
        reveal(album)
        XCTAssertTrue(album.waitForExistence(timeout: 8)); album.tap()
        reveal(app.images["photoPreview"], towardTop: true)
        XCTAssertTrue(app.images["photoPreview"].waitForExistence(timeout: 10))
        shot("Photo album selection")
        let position = app.staticTexts["photoPosition"]
        reveal(position); let initial = position.label
        XCTAssertTrue(app.buttons["nextPhoto"].isEnabled); app.buttons["nextPhoto"].tap()
        expectation(for: NSPredicate { _, _ in position.label != initial }, evaluatedWith: nil); waitForExpectations(timeout: 5)
        closePanel(); shot("Dashboard with library photo")
        tab(0)
        let overviewAlbum = app.buttons["overviewAlbum"]
        XCTAssertFalse((overviewAlbum.value as? String ?? "").contains("No photo"))
        let overviewPosition = overviewAlbum.value as? String
        expectation(for: NSPredicate { _, _ in overviewAlbum.value as? String != overviewPosition }, evaluatedWith: nil)
        waitForExpectations(timeout: 36)
        shot("Black overview with album")
        overviewAlbum.tap()
        XCTAssertTrue(app.images["photoPreview"].waitForExistence(timeout: 5)); closePanel()
        tab(3)
        let wall = app.descendants(matching: .any)["photoWall"]
        XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["chooseWallAlbum"].exists)
        XCTAssertEqual(wall.frame.width, app.frame.width, accuracy: 2)
        XCTAssertEqual(wall.frame.height, app.frame.height, accuracy: 2)
        shot("Photo wall landscape left")
        let firstPhoto = wall.value as? String
        expectation(for: NSPredicate { _, _ in wall.value as? String != firstPhoto }, evaluatedWith: nil)
        waitForExpectations(timeout: 36) // Actual 30-second slideshow, no shortened test timer.
        XCUIDevice.shared.orientation = .landscapeRight
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil); waitForExpectations(timeout: 8)
        XCTAssertEqual(wall.frame.width, app.frame.width, accuracy: 2)
        XCTAssertEqual(wall.frame.height, app.frame.height, accuracy: 2)
        shot("Photo wall landscape right")
        showNavigation(); XCTAssertTrue(app.descendants(matching: .any)["sideNavigation"].exists)
        navigationAction("hideNavigation")
        swipePage(forward: true); XCTAssertTrue(app.descendants(matching: .any)["musicPage"].waitForExistence(timeout: 3))
        swipePage(forward: true); XCTAssertTrue(app.buttons["settingsHome"].waitForExistence(timeout: 3))
        swipePage(forward: false); XCTAssertTrue(app.descendants(matching: .any)["musicPage"].waitForExistence(timeout: 3))
        swipePage(forward: false); XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 3))
        app.terminate(); launchHome()
        openPhotoSettings()
        XCTAssertTrue(app.images["photoPreview"].waitForExistence(timeout: 10))
        // Revoking permission must not restore the cached album image on relaunch.
        app.resetAuthorizationStatus(for: .photos); launchHome()
        openPhotoSettings()
        XCTAssertTrue(app.buttons["connectPhotos"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["photoPreview"].exists)
        XCTAssertTrue(app.staticTexts["photoMessage"].exists)
        let clear = app.buttons["clearPhotos"]; reveal(clear); clear.tap()
        XCTAssertFalse(app.images["photoPreview"].exists); XCTAssertFalse(app.staticTexts["photoPosition"].exists)
        closePanel(); XCTAssertTrue(app.descendants(matching: .any)["photoWall"].exists)
    }
    func testAllControlsHaveNoRoomFilterAndDoNotChangeFavorites() {
        let before = app.buttons["accessory-Ceiling fan"]
        XCTAssertTrue(before.exists)
        for _ in 0..<2 {
            panel("allControls")
            XCTAssertFalse(app.buttons["room-Kitchen"].exists)
            XCTAssertTrue(app.buttons.matching(identifier: "accessory-Pendant lights").firstMatch.exists)
            XCTAssertTrue(app.buttons.matching(identifier: "accessory-Reading lamp").firstMatch.exists)
            closePanel()
            XCTAssertTrue(before.exists)
            XCTAssertEqual(app.staticTexts["temperatureValue"].label, "22.0")
        }
    }
    func testLargeTextLayout() {
        app.terminate(); app.launchArguments = ["--demo", "--uitesting", "-homeWidgetLayouts", "", "-homeShortcuts", "", "-appLanguage", "en", "-display.nightMode", "off", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]; launchHome()
        XCTAssertTrue(app.staticTexts["demoBadge"].waitForExistence(timeout: 5)); shot("Accessibility large text")
        reveal(app.descendants(matching: .any)["shortcut-camera"]); XCTAssertTrue(app.descendants(matching: .any)["shortcut-camera"].isHittable); XCTAssertFalse(app.buttons["photoWidget"].exists)
        tab(4)
        for entry in ["settingsHome", "settingsDisplay", "settingsContentPrivacy", "settingsGeneral", "settingsCalendar", "settingsWeather", "settingsPermissions", "settingsHelp", "settingsAbout"] {
            reveal(app.buttons[entry]); XCTAssertTrue(app.buttons[entry].isHittable)
        }
        shot("Accessibility large text Settings")
    }
    func testChineseLanguageSwitchAndPersistence() {
        // Remove the English launch override so this journey exercises stored preference.
        app.terminate(); app.launchArguments = ["--demo", "--uitesting", "-homeWidgetLayouts", "", "-homeShortcuts", "", "-display.nightMode", "off"]; launchHome()
        tab(4)
        openLanguageMenu(); app.buttons["English"].tap()
        openLanguageMenu(); app.buttons["简体中文"].tap()
        XCTAssertTrue(app.buttons["appLanguagePicker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["通用"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["showNavigationButton"].label, "切换页面")
        showNavigation()
        XCTAssertEqual(app.buttons["tab-1"].label, "家庭")
        XCTAssertEqual(app.buttons["tab-2"].label, "时钟")
        app.buttons["tab-1"].tap()
        XCTAssertFalse(app.buttons["photoWidget"].exists)
        XCTAssertTrue(app.staticTexts["demoBadge"].exists)
        shot("Chinese Home landscape")
        app.terminate(); launchHome()
        showNavigation(); XCTAssertEqual(app.buttons["tab-4"].label, "设置")
        app.buttons["tab-4"].tap()
        XCTAssertTrue(app.buttons["settingsHome"].exists)
        shot("Chinese Settings restored after relaunch")
        // Restore English via the same user control, without writing test-only defaults.
        openLanguageMenu(); app.buttons["English"].tap()
        XCTAssertTrue(app.buttons["appLanguagePicker"].waitForExistence(timeout: 5))
    }
    func testLegacyFaceWakeRequiresSeparateForegroundConsentInBothLanguages() {
        func verify(language: String, consentLabel: String, fragments: [String], standbyFragment: String, unavailable: String, screenshot: String) {
            app.terminate()
            // Model a saved legacy wake preference without the new scope consent.
            // Launch overrides isolate this fixture from any saved simulator preferences.
            app.launchArguments = ["--demo", "--uitesting", "-homeWidgetLayouts", "", "-homeShortcuts", "", "-appLanguage", language,
                                   "-display.nightMode", "off", "-display.faceWake", "YES", "-display.faceForegroundConsentVersion", "0"]
            launchHome(); tab(4); openWakeSettings()
            expandWakeStatus()
            let status = app.staticTexts["faceStatus"]
            reveal(status)
            XCTAssertEqual(status.label, unavailable)
            let legacyWake = app.switches["faceWake"]
            reveal(legacyWake, towardTop: true)
            XCTAssertTrue(legacyWake.exists)
            XCTAssertEqual(legacyWake.value as? String, "1", "The legacy wake preference must remain enabled in this migration fixture")
            XCTAssertTrue(legacyWake.isEnabled, "An old enabled preference must remain possible to turn off, even on unavailable hardware")
            let continuous = app.switches["faceForegroundConsent"]
            reveal(continuous)
            XCTAssertTrue(continuous.waitForExistence(timeout: 3))
            XCTAssertEqual(continuous.label, consentLabel)
            XCTAssertEqual(continuous.value as? String, "0", "Legacy wake consent must not enable non-standby camera use")
            XCTAssertFalse(continuous.isEnabled)
            let consentDisclosure = app.staticTexts["faceForegroundConsentDisclosure"]
            reveal(consentDisclosure, towardTop: true)
            XCTAssertTrue(consentDisclosure.exists)
            for fragment in fragments { XCTAssertTrue(consentDisclosure.label.contains(fragment), "Missing privacy disclosure: \(fragment)") }
            let standbyOnly = app.staticTexts["faceStandbyOnlyDisclosure"]
            reveal(standbyOnly)
            XCTAssertTrue(standbyOnly.label.contains(standbyFragment))
            // Reading a legacy setting must not request permission or represent user consent.
            // Capture-policy authorization and actual camera operation are tested separately.
            XCTAssertFalse(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.waitForExistence(timeout: 2))
            XCTAssertFalse(app.alerts.firstMatch.exists)
            shot(screenshot)
        }
        verify(language: "en", consentLabel: "Also detect faces on other pages",
               fragments: ["other HomePad pages", "delays standby", "Auto-Lock", "No identity recognition", "recordings, saved images or uploads", "camera indicator stays visible", "background pause detection", "Turn this off at any time"],
               standbyFragment: "camera runs only in standby", unavailable: "Front camera detection is unavailable on this device.",
               screenshot: "Legacy face wake privacy English")
        verify(language: "zh-Hans", consentLabel: "在其他页面也检测人脸",
               fragments: ["其他页面", "延后待机", "自动锁定", "不识别身份", "不录制", "不保存或上传图像", "相机指示灯", "进入后台时暂停", "随时关闭"],
               standbyFragment: "相机仅在待机期间工作", unavailable: "此设备无法使用前置相机检测。",
               screenshot: "Legacy face wake privacy Chinese")
    }
    func testCustomCameraShortcutPersistsAndRemainsDemo() {
        app.terminate(); app.launchArguments = ["--demo", "--uitesting", "-homeWidgetLayouts", "", "-appLanguage", "en", "-display.nightMode", "off"]; launchHome()
        XCUIDevice.shared.orientation = .landscapeLeft; waitForLandscape()
        let column = app.scrollViews["shortcutColumn"]
        func prepareVisibleShortcut(_ identifier: String, stage: String) {
            let target = app.buttons[identifier]
            XCTAssertTrue(column.waitForExistence(timeout: 5))
            XCTAssertTrue(target.waitForExistence(timeout: 5))
            func fullyVisible() -> Bool {
                let visible = column.frame.intersection(app.frame)
                let frame = target.frame
                return !visible.isNull && !visible.isEmpty && !frame.isNull && !frame.isInfinite &&
                    frame.width > 0 && frame.height > 0 && visible.contains(frame) && target.isHittable
            }
            for _ in 0..<8 {
                if fullyVisible() { break }
                if target.frame.minY < column.frame.minY { column.swipeDown() }
                else { column.swipeUp() }
            }
            var lastFrame: CGRect?
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard fullyVisible() else { lastFrame = nil; return false }
                let frame = target.frame
                let stable = lastFrame == frame
                lastFrame = frame
                return stable
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed,
                           "The exact new shortcut must be fully inside the sidebar's visible scroll viewport")
            let geometry = XCTAttachment(string: "stage=\(stage)\nidentifier=\(identifier)\napp=\(app.frame)\nsidebar=\(column.frame)\ntarget=\(target.frame)\nhittable=\(target.isHittable)\n" + app.debugDescription)
            geometry.name = "Custom camera shortcut geometry and AX \(stage)"
            geometry.lifetime = .keepAlways; add(geometry)
            shot("Custom camera shortcut fully visible \(stage)")
            XCTAssertTrue(fullyVisible(), "Visibility must still hold immediately before the input")
            XCTAssertFalse(app.buttons["dismissPanel"].exists, "The previous camera panel must be dismissed before shortcut input")
        }
        let shortcutQuery = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "shortcut-"))
        let previousIDs = Set(shortcutQuery.allElementsBoundByIndex.map(\.identifier))
        panel("addShortcut")
        let name = app.textFields["shortcutName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Entry camera QA")
        // Explicitly choose the first-available policy; an unconfigured card does not capture.
        app.buttons["shortcutCameraPicker"].coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        app.buttons["First available camera"].tap()

        XCTAssertTrue(app.buttons["saveShortcut"].isEnabled); app.buttons["saveShortcut"].tap()
        expectation(for: NSPredicate { _, _ in shortcutQuery.count == previousIDs.count + 1 }, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        let created = shortcutQuery.allElementsBoundByIndex.filter { !previousIDs.contains($0.identifier) }
        XCTAssertEqual(created.count, 1)
        let shortcut = created[0]
        XCTAssertTrue(shortcut.label.contains("Entry camera QA"))
        let shortcutID = shortcut.identifier
        prepareVisibleShortcut(shortcutID, stage: "before first open")
        shortcut.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["Demo camera"].waitForExistence(timeout: 5)); closePanel()
        XCTAssertFalse(app.buttons["photoWidget"].exists)
        app.terminate(); launchHome()
        XCTAssertTrue(app.buttons[shortcutID].waitForExistence(timeout: 5))
        prepareVisibleShortcut(shortcutID, stage: "before restored open")
        app.buttons[shortcutID].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["Demo camera"].waitForExistence(timeout: 5)); closePanel()
        shot("Custom camera shortcut restored")
        prepareVisibleShortcut(shortcutID, stage: "before remove menu")
        app.buttons[shortcutID].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.2)
        let remove = app.buttons["removeShortcut-" + String(shortcutID.dropFirst("shortcut-".count))]
        XCTAssertTrue(remove.waitForExistence(timeout: 3)); remove.tap()
        XCTAssertFalse(app.buttons[shortcutID].exists)
    }
    func testManualStandbyWakeNightModeAndSimulatorLimitations() {
        app.terminate(); app.launchArguments = ["--demo", "--uitesting", "-homeWidgetLayouts", "", "-homeShortcuts", "", "-appLanguage", "en"]; launchHome()
        tab(4); settingsCategory("settingsDisplay")
        let night = app.segmentedControls["nightMode"]
        reveal(night); XCTAssertTrue(night.exists); night.buttons["On"].tap()
        XCTAssertTrue(night.buttons["On"].isSelected)
        let preview = app.buttons["standbyPreview"]
        reveal(preview, towardTop: true); preview.tap()
        let standby = app.descendants(matching: .any)["standbyDisplay"]
        assertFillsViewport(standby)
        XCTAssertTrue((app.buttons["standbyWake"].value as? String ?? "").contains("DEMO"))
        shot("Night standby preview")
        app.buttons["standbyWake"].tap()
        XCTAssertFalse(standby.exists)
        XCTAssertTrue(app.descendants(matching: .any)["settingsPage"].exists)
        reveal(night); XCTAssertTrue(night.buttons["On"].isSelected)
        app.terminate(); launchHome(); tab(4); settingsCategory("settingsDisplay")
        reveal(night); XCTAssertTrue(night.buttons["On"].isSelected)
        shot("Night mode preference restored")
        night.buttons["Scheduled"].tap()
        openWakeSettings()
        expandWakeStatus()
        let motionStatus = app.staticTexts["motionStatus"]
        reveal(motionStatus, towardTop: true)
        XCTAssertTrue(motionStatus.label.contains("unavailable"))
        // Simulator capability reporting is evidence of fallback UI, not sensor validation.
    }
    func testStandbyDragWakesWithoutChangingDashboardPage() {
        app.terminate()
        app.launchArguments = ["--demo", "--uitesting", "-homeWidgetLayouts", "", "-homeShortcuts", "", "-appLanguage", "en", "-display.nightMode", "off"]
        launchHome()
        tab(4); settingsCategory("settingsDisplay")
        let preview = app.buttons["standbyPreview"]
        reveal(preview, towardTop: true); preview.tap()
        let standby = app.descendants(matching: .any)["standbyDisplay"]
        XCTAssertTrue(standby.waitForExistence(timeout: 5))
        assertFillsViewport(standby)
        standby.swipeLeft()
        XCTAssertFalse(standby.exists)
        XCTAssertTrue(app.descendants(matching: .any)["settingsDisplayPage"].exists, "A standby drag wakes without paging away from the original page")
        shot("Standby drag wakes the original page without navigating")
    }
    func testWallpaperSelectionCancelReplacementRestoreAndRemoval() throws {
        let originalFrames = (0..<6).map { app.descendants(matching: .any)["homeWidget-slot-\($0)"].frame }
        tab(4); settingsCategory("settingsDisplay")
        chooseBackgroundSource("photo")
        let choose = app.buttons["chooseWallpaper"]
        let remove = app.buttons["removeWallpaper"]
        let preview = app.buttons["wallpaperPhotoSaved"]
        let background = app.images["customWallpaper"]
        let status = app.staticTexts["wallpaperStatus"]
        reveal(choose)
        XCTAssertTrue(choose.waitForExistence(timeout: 5))
        // Clean up only this app's wallpaper through its user control.
        if remove.exists { reveal(remove); remove.tap() }
        reveal(status)
        XCTAssertEqual(status.label, "Using a default background color")
        XCTAssertFalse(preview.exists)
        XCTAssertFalse(background.exists)

        func chooseSeedPhoto(at index: Int) {
            reveal(choose, towardTop: true); choose.tap()
            XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 8), "The system photo picker must be presented")
            // These are the system PhotosPicker's real synthetic photo assets,
            // independent of the app's PhotoKit album authorization and slideshow.
            let photos = app.images.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Photo,", "照片,"))
            let photo = photos.element(boundBy: index)
            if !photo.waitForExistence(timeout: 8) {
                let tree = XCTAttachment(string: app.debugDescription)
                tree.name = "System wallpaper picker accessibility"; tree.lifetime = .keepAlways; add(tree)
            }
            XCTAssertTrue(photo.waitForExistence(timeout: 8), "The isolated simulator must contain two synthetic PhotosPicker assets")
            // The system picker exposes remote image cells as non-hittable on
            // this runtime even while visible. Use their actual on-screen frame;
            // the saved image identity and fullscreen result remain mandatory.
            let frame = photo.frame
            XCTAssertGreaterThan(frame.width, 60); XCTAssertGreaterThan(frame.height, 60)
            XCTAssertTrue(app.frame.contains(CGPoint(x: frame.midX, y: frame.midY)))
            photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        func selectedWallpaperID() throws -> String {
            XCTAssertTrue(preview.waitForExistence(timeout: 20))
            let identifier = try XCTUnwrap(preview.value as? String)
            XCTAssertNotNil(identifier.range(of: "^[a-fA-F0-9]{64}$", options: .regularExpression))
            XCTAssertEqual(status.label, "Using your background photo")
            XCTAssertFalse(app.staticTexts["wallpaperError"].exists)
            return identifier
        }
        func assertFullscreenWallpaper(_ identifier: String) {
            XCTAssertTrue(background.waitForExistence(timeout: 5))
            XCTAssertEqual(background.value as? String, identifier)
            XCTAssertLessThanOrEqual(background.frame.minX, app.frame.minX + 2)
            XCTAssertLessThanOrEqual(background.frame.minY, app.frame.minY + 2)
            XCTAssertGreaterThanOrEqual(background.frame.maxX, app.frame.maxX - 2)
            XCTAssertGreaterThanOrEqual(background.frame.maxY, app.frame.maxY - 2)
        }
        chooseSeedPhoto(at: 0)
        let firstID = try selectedWallpaperID()
        shot("Wallpaper selected in Settings")

        reveal(choose, towardTop: true); choose.tap()
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5)); cancel.tap()
        XCTAssertEqual(try selectedWallpaperID(), firstID, "Cancelling the system picker must retain the existing wallpaper")
        tab(1); assertFullscreenWallpaper(firstID)
        for index in 0..<6 {
            let frame = app.descendants(matching: .any)["homeWidget-slot-\(index)"].frame
            XCTAssertEqual(frame.minX, originalFrames[index].minX, accuracy: 2)
            XCTAssertEqual(frame.minY, originalFrames[index].minY, accuracy: 2)
            XCTAssertEqual(frame.width, originalFrames[index].width, accuracy: 2)
            XCTAssertEqual(frame.height, originalFrames[index].height, accuracy: 2)
        }
        XCTAssertTrue(app.descendants(matching: .any)["shortcut-camera"].exists)
        XCTAssertFalse(app.buttons["photoWidget"].exists)
        shot("Fullscreen custom wallpaper Home")

        app.terminate(); launchHome()
        assertFullscreenWallpaper(firstID)
        tab(4); settingsCategory("settingsDisplay"); chooseBackgroundSource("photo"); reveal(preview)
        XCTAssertEqual(try selectedWallpaperID(), firstID, "Relaunch must restore the same saved image")
        chooseSeedPhoto(at: 1)
        expectation(for: NSPredicate { _, _ in preview.value as? String != firstID }, evaluatedWith: nil)
        waitForExpectations(timeout: 20)
        let replacementID = try selectedWallpaperID()
        XCTAssertNotEqual(replacementID, firstID, "Selecting a different seeded photo must replace the wallpaper")
        tab(2); assertFullscreenWallpaper(replacementID)
        XCTAssertTrue(app.descendants(matching: .any)["fullClockDial"].exists)
        shot("Replacement wallpaper fullscreen Clock")

        tab(4); settingsCategory("settingsDisplay"); chooseBackgroundSource("photo"); reveal(remove); XCTAssertTrue(remove.isHittable); remove.tap()
        reveal(status, towardTop: true)
        XCTAssertEqual(status.label, "Using a default background color")
        XCTAssertFalse(preview.exists)
        XCTAssertFalse(app.staticTexts["wallpaperError"].exists)
        tab(1); XCTAssertFalse(background.exists)
        app.terminate(); launchHome()
        XCTAssertFalse(background.exists)
        tab(4); settingsCategory("settingsDisplay"); chooseBackgroundSource("photo"); reveal(status)
        XCTAssertEqual(status.label, "Using a default background color")
        XCTAssertFalse(preview.exists)
        XCTAssertFalse(remove.exists)
        shot("Wallpaper removed and default restored")
    }
    func testOverviewPagingKeepsFullViewportBlack() throws {
        tab(0)
        func swipeOnBackground(forward: Bool) {
            XCTAssertFalse(app.buttons["dismissPanel"].exists, "Paging must start without an unrelated panel")
            let viewport = app.frame
            let start: CGPoint
            let end: CGPoint
            if forward {
                // Both points are in the observed left black gutter, outside
                // the four Overview widgets and their tap targets.
                start = CGPoint(x: viewport.minX + viewport.width * 0.12, y: viewport.midY)
                end = CGPoint(x: viewport.minX + viewport.width * 0.02, y: viewport.midY)
                for identifier in ["overviewDate", "overviewClock", "overviewAlbum", "overviewWeather"] {
                    let widget = app.descendants(matching: .any)[identifier]
                    XCTAssertTrue(widget.exists)
                    XCTAssertFalse(widget.frame.contains(start))
                    XCTAssertFalse(widget.frame.contains(end))
                }
            } else {
                let grid = app.scrollViews["homeControlGrid"]
                let sidebar = app.scrollViews["shortcutColumn"]
                XCTAssertTrue(grid.waitForExistence(timeout: 5))
                XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
                var lastGrid: CGRect?, lastSidebar: CGRect?
                let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    let first = grid.frame, second = sidebar.frame
                    guard viewport.contains(first), viewport.contains(second) else {
                        lastGrid = nil; lastSidebar = nil; return false
                    }
                    let stable = lastGrid == first && lastSidebar == second
                    lastGrid = first; lastSidebar = second
                    return stable
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
                XCTAssertGreaterThan(sidebar.frame.minX, grid.frame.maxX)
                start = CGPoint(x: (grid.frame.maxX + sidebar.frame.minX) / 2, y: viewport.midY)
                end = CGPoint(x: viewport.maxX - 24, y: viewport.midY)
                XCTAssertFalse(grid.frame.contains(start))
                XCTAssertFalse(sidebar.frame.contains(start))
            }
            XCTAssertTrue(viewport.contains(start)); XCTAssertTrue(viewport.contains(end))
            let geometry = XCTAttachment(string: "app=\(viewport)\nforward=\(forward)\nstart=\(start)\nend=\(end)")
            geometry.name = "Overview paging background input geometry"
            geometry.lifetime = .keepAlways; add(geometry)
            let anchor = app.coordinate(withNormalizedOffset: .zero)
            anchor.withOffset(CGVector(dx: start.x - viewport.minX, dy: start.y - viewport.minY))
                .press(forDuration: 0.05,
                       thenDragTo: anchor.withOffset(CGVector(dx: end.x - viewport.minX, dy: end.y - viewport.minY)))
        }
        for cycle in 0..<4 {
            assertFillsViewport(app.descendants(matching: .any)["overviewBoard"])
            assertOverviewMarginsAreBlack()
            if cycle == 3 { break }
            swipeOnBackground(forward: true)
            XCTAssertTrue(app.descendants(matching: .any)["homePage"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["dismissPanel"].exists, "An Overview swipe must not open Weather or Photos")
            swipeOnBackground(forward: false)
            XCTAssertTrue(app.descendants(matching: .any)["overviewBoard"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["dismissPanel"].exists)
        }
        shot("Overview repeated paging full black landscape left")
        XCUIDevice.shared.orientation = .landscapeRight
        waitForLandscape()
        assertFillsViewport(app.descendants(matching: .any)["overviewBoard"])
        assertOverviewMarginsAreBlack()
        shot("Overview full black landscape right")
    }

    func assertOverviewMarginsAreBlack(file: StaticString = #filePath, line: UInt = #line) {
        // Check rendered gutters, not just a view's declared frame/background.
        guard let image = UIImage(data: app.screenshot().pngRepresentation)?.cgImage else {
            XCTFail("Screenshot must decode", file: file, line: line); return
        }
        let width = image.width, height = image.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &rgba, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            XCTFail("Screenshot must render into RGBA", file: file, line: line); return
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        for xFraction in [0.025, 0.975] {
            for yFraction in [0.35, 0.65] {
                let i = (Int(Double(height) * yFraction) * width + Int(Double(width) * xFraction)) * 4
                XCTAssertLessThanOrEqual(rgba[i], 8, "Red gutter pixel", file: file, line: line)
                XCTAssertLessThanOrEqual(rgba[i + 1], 8, "Green gutter pixel", file: file, line: line)
                XCTAssertLessThanOrEqual(rgba[i + 2], 8, "Blue gutter pixel", file: file, line: line)
                XCTAssertGreaterThanOrEqual(rgba[i + 3], 247, "Opaque gutter pixel", file: file, line: line)
            }
        }
    }

    func testHomeLongPressPreviewFitsViewportAndPreservesControls() {
        let widget = app.descendants(matching: .any)["homeWidget-slot-0"]
        let originalFrame = widget.frame
        widget.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["contextShowNavigation"].waitForExistence(timeout: 4))
        // UIKit hosts SwiftUI previews under its own "Preview" AX node and
        // strips the supplied identifier; use that actual native container.
        let preview = app.otherElements.matching(NSPredicate(format: "label IN %@", ["Preview", "预览"])).firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 4))
        XCTAssertTrue(app.frame.insetBy(dx: 2, dy: 2).contains(preview.frame), "The entire lifted climate preview must fit")
        let temperature = preview.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "22.0")).firstMatch
        XCTAssertTrue(temperature.exists)
        XCTAssertTrue(preview.frame.insetBy(dx: -1, dy: -1).contains(temperature.frame), "The complete temperature glyphs must remain inside the preview")
        XCTAssertGreaterThan(preview.frame.width, 200)
        XCTAssertLessThanOrEqual(max(preview.frame.width, preview.frame.height), 350)
        shot("Home full climate long press preview")
        app.buttons["contextShowNavigation"].tap()
        app.buttons["hideNavigation"].tap()
        XCTAssertEqual(widget.frame.width, originalFrame.width, accuracy: 1)
        XCTAssertEqual(widget.frame.height, originalFrame.height, accuracy: 1)
        let edgeWidget = app.descendants(matching: .any)["homeWidget-slot-5"]
        let grid = app.descendants(matching: .any)["homeControlGrid"]
        for _ in 0..<4 {
            if grid.frame.intersection(app.frame).contains(edgeWidget.frame) { break }
            grid.swipeUp()
        }
        edgeWidget.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["contextShowNavigation"].waitForExistence(timeout: 4))
        let edgePreview = app.otherElements.matching(NSPredicate(format: "label IN %@", ["Preview", "预览"])).firstMatch
        XCTAssertTrue(edgePreview.waitForExistence(timeout: 4))
        XCTAssertTrue(app.frame.insetBy(dx: 2, dy: 2).contains(edgePreview.frame))
        let edgeName = edgePreview.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Pendant lights")).firstMatch
        XCTAssertTrue(edgeName.exists)
        XCTAssertTrue(edgePreview.frame.insetBy(dx: -1, dy: -1).contains(edgeName.frame))
        shot("Home edge control complete long press preview")
        app.terminate()
        app.launchArguments = ["--demo", "--uitesting", "-homeWidgetLayouts", "", "-homeShortcuts", "", "-appLanguage", "zh-Hans", "-display.nightMode", "off", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchHome()
        app.descendants(matching: .any)["homeWidget-slot-0"].press(forDuration: 1.2)
        let accessiblePreview = app.otherElements.matching(NSPredicate(format: "label IN %@", ["Preview", "预览"])).firstMatch
        XCTAssertTrue(accessiblePreview.waitForExistence(timeout: 4))
        XCTAssertTrue(app.frame.insetBy(dx: 2, dy: 2).contains(accessiblePreview.frame))
        let accessibleTemperature = accessiblePreview.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "22.0")).firstMatch
        XCTAssertTrue(accessibleTemperature.exists)
        XCTAssertTrue(accessiblePreview.frame.insetBy(dx: -1, dy: -1).contains(accessibleTemperature.frame))
        shot("Home Chinese maximum text complete climate preview")
    }

    func testWidgetRemoveAddResizeAndPersistence() throws {
        // Exercise real saved layout, while ordinary test launches use the default fixture override.
        app.terminate(); app.launchArguments = ["--demo", "--uitesting", "-homeShortcuts", "", "-appLanguage", "en", "-display.nightMode", "off"]; launchHome()
        XCUIDevice.shared.orientation = .landscapeLeft; waitForLandscape()
        func restoreDefaults() {
            navigationAction("restoreHomeWidgets"); app.buttons["confirmRestoreWidgets"].firstMatch.tap()
            XCTAssertTrue(app.descendants(matching: .any)["homeWidget-slot-2"].waitForExistence(timeout: 5))
        }
        restoreDefaults()
        let lamp = app.buttons["accessory-Pendant lights"]
        XCTAssertTrue(lamp.label.contains("On"))
        let camera = app.descendants(matching: .any)["homeWidget-slot-2"]
        camera.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["removeWidget-slot-2"].waitForExistence(timeout: 3))
        app.buttons["removeWidget-slot-2"].tap()
        XCTAssertFalse(camera.exists)
        XCTAssertTrue(lamp.label.contains("On")) // Editing layout must not issue accessory commands.
        app.terminate(); launchHome()
        XCTAssertFalse(camera.exists)
        XCTAssertTrue(app.descendants(matching: .any)["shortcut-camera"].exists)
        let widgetQuery = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "homeWidget-"))
        let existing = Set(widgetQuery.allElementsBoundByIndex.map(\.identifier))
        panel("addHomeWidget")
        XCTAssertTrue(app.buttons["widgetOption-clock"].waitForExistence(timeout: 3)); app.buttons["widgetOption-clock"].tap()
        expectation(for: NSPredicate { _, _ in
            !Set(widgetQuery.allElementsBoundByIndex.map(\.identifier)).subtracting(existing).isEmpty
        }, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        let created = widgetQuery.allElementsBoundByIndex.filter { !existing.contains($0.identifier) }
        let ids = Set(created.map(\.identifier))
        XCTAssertEqual(ids.count, 1)
        let identifier = try XCTUnwrap(ids.first)
        let id = String(identifier.dropFirst("homeWidget-".count))
        let widget = app.descendants(matching: .any)[identifier]
        let board = app.descendants(matching: .any)["homeControlGrid"]
        for _ in 0..<6 { if widget.isHittable { break }; board.swipeUp() }
        XCTAssertTrue(widget.isHittable)
        XCTAssertEqual(widget.value as? String, "Small")
        let smallHeight = widget.frame.height
        widget.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["widgetSize-" + id + "-large"].waitForExistence(timeout: 3))
        let largeOption = app.buttons["widgetSize-" + id + "-large"]
        largeOption.tap()
        expectation(for: NSPredicate { _, _ in
            !largeOption.exists && widget.value as? String == "Large"
        }, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(widget.value as? String, "Large")
        XCTAssertGreaterThan(widget.frame.height, smallHeight * 1.8)
        for _ in 0..<6 { if widget.isHittable { break }; board.swipeUp() }
        XCTAssertTrue(widget.isHittable)
        shot("Large clock widget after context resize")
        app.terminate(); launchHome()
        XCTAssertEqual(widget.value as? String, "Large")
        XCTAssertGreaterThan(widget.frame.height, smallHeight * 1.8)
        // Oversized contents must be reachable by vertical canvas scrolling.
        for _ in 0..<6 { if widget.isHittable { break }; board.swipeUp() }
        XCTAssertTrue(widget.isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["homePage"].exists)
        XCTAssertFalse(app.buttons["photoWidget"].exists)
        XCTAssertEqual(widget.frame.width, widget.frame.height, accuracy: 2)
        XCUIDevice.shared.orientation = .landscapeRight; waitForLandscape()
        for _ in 0..<6 { if widget.isHittable { break }; board.swipeUp() }
        XCTAssertTrue(widget.isHittable)
        XCTAssertEqual(widget.value as? String, "Large")
        let controls = app.buttons["shortcut-controls"]
        let shortcutColumn = app.descendants(matching: .any)["shortcutColumn"]
        for _ in 0..<6 { if controls.isHittable { break }; shortcutColumn.swipeUp() }
        XCTAssertTrue(controls.isHittable)
        XCTAssertGreaterThanOrEqual(controls.frame.minX, board.frame.maxX + 10)
        XCTAssertLessThanOrEqual(controls.frame.maxX, app.frame.maxX)
        shot("Landscape widget overflow and right shortcuts")
        restoreDefaults()
        XCTAssertFalse(app.descendants(matching: .any)[identifier].exists)
    }
    func testSettingsHubNavigationContentCancellationAndScreenBehaviorPersistence() {
        tab(4)
        for entry in ["settingsHome", "settingsDisplay", "settingsContentPrivacy", "settingsGeneral", "settingsCalendar", "settingsWeather", "settingsPermissions", "settingsHelp", "settingsAbout"] {
            reveal(app.buttons[entry]); XCTAssertTrue(app.buttons[entry].isHittable)
        }
        reveal(app.buttons["settingsHome"], towardTop: true)
        shot("Settings native title and direct feature entrances")
        settingsCategory("settingsDisplay")
        let system = app.buttons["screenBehavior-followSystem"]
        let keep = app.buttons["screenBehavior-keepDisplay"]
        let clock = app.buttons["screenBehavior-idleClock"]
        reveal(system); system.tap(); XCTAssertTrue(system.isSelected)
        XCTAssertFalse(app.buttons["standbyDelay"].exists)
        reveal(keep); keep.tap(); XCTAssertTrue(keep.isSelected)
        XCTAssertTrue(app.buttons["standbyDelay"].exists, "Keep current page also has a real idle timer")
        reveal(clock); clock.tap(); XCTAssertTrue(clock.isSelected)
        reveal(app.buttons["standbyDelay"])
        XCTAssertTrue(app.buttons["standbyDelay"].exists)
        shot("Screen behavior explicit selection")
        XCUIDevice.shared.press(.home); app.activate()
        reveal(clock, towardTop: true); XCTAssertTrue(clock.isSelected)
        app.terminate(); launchHome(); tab(4); settingsCategory("settingsDisplay")
        reveal(clock); XCTAssertTrue(clock.isSelected)
        settingsCategory("settingsContentPrivacy")
        XCTAssertTrue(app.switches["showPersonal"].exists)
        let photos = app.buttons["photoSettings"]
        reveal(photos); photos.tap()
        XCTAssertTrue(app.buttons["singlePhotoPicker"].waitForExistence(timeout: 5)); closePanel()
        let weather = app.buttons["weatherSettings"]
        reveal(weather); weather.tap()
        XCTAssertTrue(app.staticTexts["weatherDemoNotice"].waitForExistence(timeout: 5)); closePanel()
        XCTAssertTrue(app.buttons["weatherSettings"].exists)
        shot("Content and privacy settings")
        settingsCategory("settingsHelp")
        app.buttons["guidedAccessTutorial"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["guidedAccessStatus"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["guidedAccessHelp"].isHittable)
        settingsCategory("settingsAbout")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Independent open-source")).firstMatch.exists)
    }
    func testGlassThemePersistsAfterNavigation() {
        tab(4); settingsCategory("settingsDisplay")
        chooseBackgroundSource("colors")
        let teal = app.buttons["wallpaperDefault-teal"]
        reveal(teal)
        XCTAssertTrue(teal.isHittable); teal.tap()
        XCTAssertTrue(teal.isSelected)
        XCTAssertFalse(app.buttons["wallpaperDefault-warmGray"].isSelected)
        tab(1); shot("Teal dashboard")
        tab(4); settingsCategory("settingsDisplay"); chooseBackgroundSource("colors"); reveal(teal); XCTAssertTrue(teal.isSelected)
        tab(1); XCTAssertTrue(app.descendants(matching: .any)["homeWidget-slot-0"].exists)
    }
    func testAccessoryIconTogglesAndNameOpensDetailsWithoutChangingPower() {
        let icon = app.buttons["accessory-Pendant lights"]
        let name = app.buttons["accessoryDetails-Pendant lights"]
        XCTAssertEqual(icon.value as? String, "On")
        name.tap()
        XCTAssertTrue(app.descendants(matching: .any)["accessoryDetails"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["accessoryDetailState"].label, "On")
        closePanel()
        XCTAssertEqual(icon.value as? String, "On", "Opening details must not send a power command")
        icon.tap(); XCTAssertEqual(icon.value as? String, "Off")
        XCTAssertFalse(app.staticTexts["powerState-Pendant lights"].exists)
        XCTAssertFalse(app.staticTexts["Off"].exists, "A normal power card uses icon appearance instead of a redundant Off line")
        shot("Home same-height rectangular right column and split control actions")
        panel("allControls")
        app.collectionViews.buttons["accessoryDetails-Pendant lights"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["accessoryDetails"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["accessoryDetailState"].label, "Off")
        closePanel(); XCTAssertEqual(icon.value as? String, "Off")
    }

    func testMusicAlbumsAndPlaylistsPlayContinuouslyAndShuffleWholeQueue() {
        launchMusicFixtureHome()
        func assertQueue(_ titles: [String]) {
            XCTAssertTrue(app.descendants(matching: .any)["musicQueueList"].waitForExistence(timeout: 5))
            let entries = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "musicQueueEntry-"))
            let complete = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in entries.count == titles.count }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [complete], timeout: 5), .completed,
                           "The visible queue must contain the complete selected collection")
            XCTAssertEqual(entries.count, titles.count)
            for (index, title) in titles.enumerated() {
                XCTAssertTrue(entries.element(boundBy: index).label.contains(title), "Queue position \(index + 1) must retain \(title)")
            }
        }
        func openPlaylistsFromPlayer() {
            tapReadyMusicButton("musicLibrary")
            XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["musicAlbumsTab"].isSelected)
            XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
            tapReadyMusicButton("musicPlaylistsTab")
            XCTAssertTrue(app.buttons["musicPlaylist-validation-playlist-0"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["musicPlaylistsTab"].isSelected)
        }

        openFixtureMusicLibrary()
        tapReadyMusicButton("musicAlbum-validation-album-0")
        tapReadyMusicButton("musicAlbumPlayAll")
        waitForMusicMiniTitle("Synthetic song 1.1", playing: true)
        XCTAssertTrue(app.descendants(matching: .any)["musicAlbumTracks"].exists, "Play all must leave the album visible")
        XCTAssertFalse(app.staticTexts["musicNowPlayingTitle"].exists)
        openFixtureMusicPlayer()
        waitForMusicTitle("Synthetic song 1.1")
        XCTAssertEqual(app.buttons["musicPlayback"].label, "Pause")
        tapReadyMusicButton("musicQueue")
        let album = ["Synthetic song 1.1", "Synthetic song 1.2", "Synthetic song 1.3"]
        assertQueue(album)
        openFixtureMusicPlayer()
        tapReadyMusicButton("musicNext")
        waitForMusicTitle("Synthetic song 1.2")
        XCTAssertEqual(app.buttons["musicPlayback"].label, "Pause", "Advancing through an album must continue playback")
        tapReadyMusicButton("musicQueue")
        assertQueue(album)
        tapReadyMusicButton("musicQueueShuffle")
        waitForMusicMiniTitle("Synthetic song 1.3", playing: true)
        XCTAssertTrue(app.descendants(matching: .any)["musicQueueList"].exists, "Shuffling must not steal navigation from the queue")
        assertQueue(Array(album.reversed()))
        shot("Complete synthetic album queue after shuffle")
        openFixtureMusicPlayer()

        openPlaylistsFromPlayer()
        tapReadyMusicButton("musicPlaylist-validation-playlist-0")
        tapReadyMusicButton("musicPlaylistPlayAll")
        waitForMusicMiniTitle("Synthetic song 1.1", playing: true)
        XCTAssertTrue(app.descendants(matching: .any)["musicPlaylistTracks"].exists, "Play all must leave the playlist visible")
        openFixtureMusicPlayer()
        waitForMusicTitle("Synthetic song 1.1")
        let playlist = album + ["Synthetic song 2.1", "Synthetic song 2.2", "Synthetic song 2.3"]
        tapReadyMusicButton("musicQueue")
        assertQueue(playlist)
        openFixtureMusicPlayer()
        tapReadyMusicButton("musicNext")
        waitForMusicTitle("Synthetic song 1.2")
        XCTAssertEqual(app.buttons["musicPlayback"].label, "Pause", "A playlist must keep the remaining songs queued")
        tapReadyMusicButton("musicQueue")
        assertQueue(playlist)
        tapReadyMusicButton("musicQueueShuffle")
        waitForMusicMiniTitle("Synthetic song 2.3", playing: true)
        XCTAssertTrue(app.descendants(matching: .any)["musicQueueList"].exists)
        assertQueue(Array(playlist.reversed()))
        shot("Complete synthetic playlist queue after shuffle")
        openFixtureMusicPlayer()

        openPlaylistsFromPlayer()
        tapReadyMusicButton("musicPlaylist-validation-playlist-0")
        XCTAssertTrue(app.buttons["musicPlaylistSong-0"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["musicLibrary"].label, "Playlists")
        tapReadyMusicButton("musicLibrary")
        XCTAssertTrue(app.descendants(matching: .any)["musicPlaylists"].waitForExistence(timeout: 5), "Back must return to the playlist source")
        tapReadyMusicButton("musicPlaylist-validation-playlist-0")
        XCTAssertTrue(app.buttons["musicPlaylistSong-0"].waitForExistence(timeout: 5))
        tab(1); tab(5)
        XCTAssertTrue(app.buttons["musicPlaylistSong-0"].waitForExistence(timeout: 5), "Page navigation must restore the browsed playlist")
        XCTAssertTrue(app.staticTexts["Validation playlist 1"].exists)
        XCTAssertEqual(app.buttons["musicLibrary"].label, "Playlists")
        tapReadyMusicButton("musicLibrary")

        tapReadyMusicButton("musicPlaylist-validation-playlist-1")
        let duplicate = app.buttons["musicPlaylistSong-6"]
        for _ in 0..<6 {
            if duplicate.exists && duplicate.isHittable { break }
            app.scrollViews.allElementsBoundByIndex.last?.swipeUp()
        }
        XCTAssertTrue(duplicate.waitForExistence(timeout: 5)); XCTAssertTrue(duplicate.isHittable)
        XCTAssertTrue(duplicate.label.contains("Synthetic song 2.1"))
        duplicate.tap()
        waitForMusicMiniTitle("Synthetic song 2.1", playing: true)
        XCTAssertTrue(app.descendants(matching: .any)["musicPlaylistTracks"].exists, "Selecting a duplicate must preserve the playlist page")
        XCTAssertFalse(app.buttons["musicMiniNext"].isEnabled, "The final duplicate must remain the last occurrence")
        openFixtureMusicPlayer()
        waitForMusicTitle("Synthetic song 2.1")
        XCTAssertFalse(app.buttons["musicNext"].isEnabled, "Choosing the final duplicate must start at its last queue position")
        tapReadyMusicButton("musicQueue")
        assertQueue(["Synthetic song 2.1", "Synthetic song 2.2", "Synthetic song 2.3", "Synthetic song 3.1", "Synthetic song 3.2", "Synthetic song 3.3", "Synthetic song 2.1"])
        shot("Final duplicate selected from the complete synthetic playlist")
    }

    func testPlayingMusicArtworkExtendsAcrossHomeAndClockAndRestoresOnPause() {
        launchMusicFixtureHome()
        let open = app.buttons["homeMusicOpen"], playback = app.buttons["homeMusicPlayback"]
        XCTAssertEqual(playback.label, "Play")
        shot("Paused Home original background before synthetic artwork")
        // Select the isolated simulator's existing synthetic assets through
        // PhotosPicker. This grants no full-library permission or real account.
        openPhotoSettings()
        tapReadyMusicButton("singlePhotoPicker")
        XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 8))
        let seeded = app.images.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Photo,", "照片,"))
        XCTAssertTrue(seeded.element(boundBy: 1).waitForExistence(timeout: 8))
        for index in 0..<2 {
            let photo = seeded.element(boundBy: index)
            XCTAssertGreaterThan(photo.frame.width, 60)
            XCTAssertTrue(app.frame.contains(CGPoint(x: photo.frame.midX, y: photo.frame.midY)))
            photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        let add = app.buttons.matching(NSPredicate(format: "(identifier == %@ OR label IN %@) AND identifier != %@", "Add", ["Add", "Done", "添加", "完成"], "dismissPanel")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 8)); XCTAssertTrue(add.isEnabled); add.tap()
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "2 photos"), object: app.staticTexts["selectedPhotoCount"])
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 20), .completed)
        closePanel()
        let composition = app.descendants(matching: .any)["photoWallComposition"]
        XCTAssertTrue(composition.waitForExistence(timeout: 5))
        let photoSelection = composition.value as? String
        let photoState = app.descendants(matching: .any)["photoWall"].value as? String
        XCTAssertEqual(photoSelection, "2 photos")
        XCTAssertNotNil(photoState)
        tab(1)
        tapReadyMusicButton("homeMusicPlayback")
        XCTAssertEqual(playback.label, "Pause")
        XCTAssertTrue((open.value as? String)?.contains("Synthetic song 1.1") == true)
        shot("Playing synthetic artwork behind Home and music card")
        tab(2)
        XCTAssertTrue(app.descendants(matching: .any)["fullClockDial"].waitForExistence(timeout: 5))
        shot("Playing synthetic artwork behind full Clock")
        tab(3)
        XCTAssertTrue(composition.waitForExistence(timeout: 5))
        XCTAssertEqual(composition.value as? String, photoSelection, "Playback must not replace the independent photo-wall selection")
        XCTAssertEqual(app.descendants(matching: .any)["photoWall"].value as? String, photoState)
        XCTAssertTrue(app.staticTexts["photoWallClock"].exists)
        shot("Independent Photos page while synthetic music keeps playing")
        tab(1)
        XCTAssertEqual(playback.label, "Pause", "Switching between Home, Clock and Photos must not pause music")
        tapReadyMusicButton("homeMusicPlayback")
        XCTAssertEqual(playback.label, "Play")
        XCTAssertTrue((open.value as? String)?.contains("Synthetic song 1.1") == true)
        shot("Paused Home restores the original background after synthetic artwork")
    }

    func testIdleDimmingKeepsPlayingHomeAndConsumesFirstTouch() {
        launchMusicFixtureHome()
        tab(4); settingsCategory("settingsDisplay")
        let keep = app.buttons["screenBehavior-keepDisplay"]
        reveal(keep); XCTAssertTrue(keep.isHittable); keep.tap(); XCTAssertTrue(keep.isSelected)
        let delay = app.buttons["standbyDelay"]
        reveal(delay); XCTAssertTrue(delay.isHittable); delay.tap()
        let thirty = app.buttons["30 seconds"]
        XCTAssertTrue(thirty.waitForExistence(timeout: 5)); thirty.tap()
        let selectedDelay = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (delay.value as? String) == "30 seconds" || delay.label.contains("30 seconds")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [selectedDelay], timeout: 5), .completed,
                       "Choose and verify the actual production Picker value before timing inactivity")
        tab(1)
        let playback = app.buttons["homeMusicPlayback"]
        tapReadyMusicButton("homeMusicPlayback")
        XCTAssertEqual(playback.label, "Pause")
        let lastTouch = Date()
        let frame = playback.frame
        XCTAssertTrue(app.frame.contains(frame))
        // Resolve an app coordinate now. After dimming the actual underlying
        // button is deliberately absent from the accessibility hierarchy.
        let savedPlaybackPoint = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX - app.frame.minX, dy: frame.midY - app.frame.minY))
        let wake = app.buttons["standbyCurrentPageWake"]
        XCTAssertTrue(wake.waitForExistence(timeout: 40), "The real 30-second idle timer must dim a page even while music is playing")
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(lastTouch), 29, "This journey must not use a shortened production timer")
        assertFillsViewport(wake)
        XCTAssertFalse(playback.exists, "The dimmed page must hide actionable controls from accessibility")
        XCTAssertFalse(app.buttons["homeMusicOpen"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["standbyDisplay"].exists, "Keep current page must retain Home rather than switch to the clock")
        shot("Real thirty-second idle dims the playing Home page without changing its content")
        savedPlaybackPoint.tap()
        XCTAssertTrue(wake.waitForNonExistence(timeout: 5))
        XCTAssertTrue(playback.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["homePage"].exists)
        XCTAssertEqual(playback.label, "Pause", "The first touch at the playback control's position must only restore brightness")
        shot("First touch restores Home while synthetic music is still playing")
        savedPlaybackPoint.tap()
        let paused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Play"), object: playback)
        XCTAssertEqual(XCTWaiter.wait(for: [paused], timeout: 5), .completed,
                       "Only the second ordinary touch may pause playback")
        XCTAssertFalse(wake.exists)
    }

    func testChineseAccessibleSettingsNavigationAndContentPermissionsEntrypoints() {
        app.terminate()
        app.launchArguments = ["--demo", "--uitesting", "-homeWidgetLayouts", "", "-homeShortcuts", "", "-appLanguage", "zh-Hans",
                               "-display.nightMode", "off", "-display.screenBehaviorV1", "followSystem", "-showPersonal", "NO",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchHome(); tab(4)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        func assertHeader(_ title: String) {
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            let pages = app.buttons["showNavigationButton"]
            var lastFrame: CGRect?
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard self.app.navigationBars.count == 1,
                      self.app.buttons.matching(identifier: "showNavigationButton").count == 1 else { lastFrame = nil; return false }
                let frame = pages.frame
                guard frame.width > 0, frame.height > 0, !frame.isNull, !frame.isInfinite,
                      self.app.frame.contains(frame) else { lastFrame = nil; return false }
                let unchanged = frame == lastFrame
                lastFrame = frame
                return unchanged && pages.isHittable
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed,
                           "The single native title and page-exit button must settle before use")
            XCTAssertEqual(app.navigationBars.count, 1, "Settings has one native navigation/title hierarchy")
            XCTAssertFalse(app.descendants(matching: .any)["dashboardHeader"].exists)
            XCTAssertEqual(app.buttons.matching(identifier: "showNavigationButton").count, 1)
            XCTAssertEqual(pages.label, "切换页面")
            XCTAssertTrue(pages.isHittable)
            XCTAssertTrue(app.frame.contains(pages.frame), "The page exit must remain visible at the largest text size")
            XCTAssertFalse(springboard.alerts.firstMatch.exists, "Viewing settings must not automatically request a permission")
        }
        assertHeader("设置")
        shot("Chinese largest-text unified Settings native title")
        for identifier in ["settingsHome", "settingsDisplay", "settingsContentPrivacy", "settingsGeneral", "settingsCalendar", "settingsWeather", "settingsPermissions", "settingsHelp", "settingsAbout"] {
            let entry = app.buttons[identifier]
            reveal(entry); XCTAssertTrue(entry.waitForExistence(timeout: 5)); XCTAssertTrue(entry.isHittable)
        }
        shot("Chinese largest-text Settings calendar weather and permission entrances")

        settingsCategory("settingsCalendar")
        XCTAssertTrue(app.descendants(matching: .any)["agendaPage"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["演示 · 未连接日历"].exists)
        XCTAssertFalse(springboard.alerts.firstMatch.exists)
        closePanel()
        settingsCategory("settingsWeather")
        XCTAssertTrue(app.staticTexts["weatherDemoNotice"].waitForExistence(timeout: 5))
        XCTAssertFalse(springboard.alerts.firstMatch.exists)
        closePanel()
        settingsCategory("settingsPermissions")
        assertHeader("权限")
        for identifier in ["permissionPhotos", "permissionMusic", "permissionCalendar", "permissionCamera", "appPermissionSettings"] {
            let entry = app.descendants(matching: .any)[identifier]
            reveal(entry); XCTAssertTrue(entry.waitForExistence(timeout: 5)); XCTAssertTrue(entry.isHittable)
        }
        XCTAssertFalse(springboard.alerts.firstMatch.exists)
        shot("Chinese largest-text system permissions without requesting access")

        settingsCategory("settingsDisplay")
        assertHeader("显示与待机")
        for identifier in ["screenBehavior-followSystem", "screenBehavior-keepDisplay", "screenBehavior-idleClock"] {
            let mode = app.buttons[identifier]
            reveal(mode); XCTAssertTrue(mode.isHittable)
        }
        let keep = app.buttons["screenBehavior-keepDisplay"]
        reveal(keep, towardTop: true); keep.tap(); XCTAssertTrue(keep.isSelected)
        let delay = app.buttons["standbyDelay"]
        reveal(delay); XCTAssertTrue(delay.isHittable)
        let preview = app.buttons["standbyPreview"]
        reveal(preview); XCTAssertTrue(preview.isHittable); XCTAssertEqual(preview.label, "预览时钟或照片")
        let photo = app.buttons["chooseWallpaper"]
        chooseBackgroundSource("photo")
        reveal(photo); XCTAssertTrue(photo.isHittable); XCTAssertEqual(photo.label, "选择背景照片")
        XCTAssertTrue(app.navigationBars.matching(NSPredicate(format: "identifier IN %@", ["墙纸", "壁纸"])).firstMatch.exists)
        let warm = app.buttons["wallpaperDefault-warmGray"], teal = app.buttons["wallpaperDefault-teal"]
        chooseBackgroundSource("colors", towardTop: true)
        reveal(warm); XCTAssertTrue(warm.isHittable); XCTAssertTrue(teal.isHittable)
        warm.tap(); XCTAssertTrue(warm.isSelected); XCTAssertFalse(teal.isSelected)
        leaveWallpaperGallery()
        let artwork = app.switches["musicArtworkBackground"]
        reveal(artwork); XCTAssertTrue(artwork.isHittable)
        assertHeader("显示与待机")
        shot("Chinese largest-text idle mode and separate Home Clock background settings")

        settingsCategory("settingsContentPrivacy")
        assertHeader("内容与权限")
        let photos = app.buttons["photoSettings"]
        reveal(photos); XCTAssertTrue(photos.isHittable); photos.tap()
        XCTAssertTrue(app.buttons["singlePhotoPicker"].waitForExistence(timeout: 5), "The independent photo-wall chooser remains a separate entry")
        XCTAssertFalse(springboard.alerts.firstMatch.exists)
        closePanel()
        assertHeader("内容与权限")
        tab(1)
        XCTAssertTrue(app.descendants(matching: .any)["homePage"].exists, "The native Settings page exit remains usable after deep navigation")
    }

    func testMusicPlayerPageSwipeLeavesAndReturnsWithoutChangingPlayback() {
        launchMusicFixtureHome()
        app.buttons["homeMusicOpen"].tap()
        waitForFixtureMusicPlayerEntry()
        let seek = app.sliders["musicSeek"]
        XCTAssertTrue(seek.isHittable)
        seek.adjust(toNormalizedSliderPosition: 0.6)
        XCTAssertTrue(app.staticTexts["musicNowPlayingTitle"].exists, "Timeline dragging belongs to music, not page navigation")
        XCTAssertEqual(app.staticTexts["musicNowPlayingTitle"].label, "Synthetic song 1.1")
        let artwork = app.buttons["musicHeroArtwork"]
        XCTAssertTrue(artwork.isHittable)
        artwork.swipeLeft()
        XCTAssertTrue(app.buttons["settingsHome"].waitForExistence(timeout: 5), "A single horizontal swipe on the player must leave Music for Settings")
        XCTAssertFalse(app.descendants(matching: .any)["dashboardHeader"].exists, "Settings now owns one native title hierarchy")
        tab(5)
        waitForFixtureMusicPlayerEntry()
        XCTAssertEqual(app.staticTexts["musicNowPlayingTitle"].label, "Synthetic song 1.1")
        XCTAssertEqual(app.buttons["musicPlayback"].label, "Play", "Page changes must not change playback")
        artwork.swipeRight()
        XCTAssertTrue(app.descendants(matching: .any)["photoWall"].waitForExistence(timeout: 5), "A right swipe must leave Music for Photos")
        swipePage(forward: true)
        waitForFixtureMusicPlayerEntry()
        artwork.tap()
        XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5), "A tap must open selectable album covers while a drag only changes pages")
        XCTAssertTrue(app.buttons["musicAlbumsTab"].isSelected)
        XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
        openFixtureMusicPlayer()
        shot("Music player single finger page navigation and explicit page entry test data")
    }

    func testMusicPageEntryLeavesEveryBrowsingScreenAndRestoresItsSource() {
        launchMusicFixtureHome()
        app.buttons["homeMusicOpen"].tap()
        waitForFixtureMusicPlayerEntry()
        func settledPageEntry() {
            let pages = app.buttons["showNavigationButton"]
            var lastFrame: CGRect?
            let stable = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard pages.exists else { lastFrame = nil; return false }
                let frame = pages.frame
                guard frame.width > 0, frame.height > 0, !frame.isNull, !frame.isInfinite,
                      self.app.frame.contains(frame) else { lastFrame = nil; return false }
                let unchanged = lastFrame == frame
                lastFrame = frame
                return unchanged && pages.isHittable
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [stable], timeout: 5), .completed)
        }
        func leaveAndReturn(_ marker: XCUIElement) {
            XCTAssertTrue(marker.waitForExistence(timeout: 5))
            settledPageEntry()
            let pages = app.buttons["showNavigationButton"]
            XCTAssertEqual(pages.label, "Switch page")
            XCTAssertTrue(pages.isHittable)
            XCTAssertTrue(app.frame.contains(pages.frame), "Explicit page entry must remain on screen")
            pages.tap()
            XCTAssertTrue(app.buttons["tab-1"].waitForExistence(timeout: 5))
            tab(1)
            XCTAssertTrue(app.descendants(matching: .any)["homePage"].exists)
            tab(5)
            XCTAssertTrue(marker.waitForExistence(timeout: 5), "Page switching must restore the music subpage")
            settledPageEntry()
        }
        leaveAndReturn(app.staticTexts["musicNowPlayingTitle"])
        app.buttons["musicQueue"].tap()
        leaveAndReturn(app.descendants(matching: .any)["musicQueueList"])
        tapReadyMusicButton("musicLibrary")
        waitForFixtureMusicPlayerEntry()
        tapReadyMusicButton("musicLibrary")
        XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5))
        let firstAlbum = app.buttons["musicAlbum-validation-album-0"]
        XCTAssertTrue(firstAlbum.waitForExistence(timeout: 5))
        firstAlbum.swipeLeft()
        let secondAlbum = app.buttons["musicAlbum-validation-album-1"]
        XCTAssertTrue(secondAlbum.label.hasPrefix("Open"), "Cover Flow must keep its horizontal gesture")
        leaveAndReturn(app.descendants(matching: .any)["musicCoverFlow"])
        XCTAssertTrue(secondAlbum.label.hasPrefix("Open"), "Focused album must survive switching pages")
        let outsideCover = app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.5))
        outsideCover.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)))
        XCTAssertTrue(app.descendants(matching: .any)["photoWall"].waitForExistence(timeout: 5), "A single finger outside the cover carousel must still change pages")
        swipePage(forward: true)
        XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5))
        settledPageEntry()
        XCTAssertTrue(secondAlbum.label.hasPrefix("Open"))
        shot("Music Cover Flow with explicit page entry and outside swipe test data")
        tapReadyMusicButton("musicAlbum-validation-album-1")
        leaveAndReturn(app.buttons["musicSong-validation-song-1-0"])
        tapReadyMusicButton("musicLibrary")
        XCTAssertFalse(app.buttons["musicSearchOpen"].exists)
        XCTAssertFalse(app.textFields["musicSearchField"].exists)
        tapReadyMusicButton("musicSongsTab")
        leaveAndReturn(app.descendants(matching: .any)["musicSongCoverFlow"])
        XCTAssertTrue(app.buttons["musicSongsTab"].isSelected)
        tapReadyMusicButton("musicPlaylistsTab")
        leaveAndReturn(app.descendants(matching: .any)["musicPlaylists"])
        XCTAssertTrue(app.buttons["musicPlaylistsTab"].isSelected)
        tapReadyMusicButton("musicAlbumsTab")
        waitForFocusedMusicCover("musicAlbum-validation-album-1")
        XCTAssertTrue((app.buttons["musicMiniPlayer"].value as? String)?.contains("Synthetic song 1.1") == true)
        shot("Music library modes retain browsing position without a search entry")
    }

    func testMusicHomeWidgetAndCoverFlowSharePlaybackWithoutPageSwipe() {
        launchMusicFixtureHome()
        XCTAssertTrue(app.staticTexts["musicValidationData"].waitForExistence(timeout: 8), "Synthetic account fixtures must remain visibly marked")
        let open = app.buttons["homeMusicOpen"], playback = app.buttons["homeMusicPlayback"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        XCTAssertTrue((open.value as? String)?.contains("Synthetic song 1.1") == true)
        playback.tap(); XCTAssertEqual(playback.label, "Pause")
        playback.tap(); XCTAssertEqual(playback.label, "Play")
        app.buttons["homeMusicNext"].tap()
        expectation(for: NSPredicate { _, _ in (open.value as? String)?.contains("Synthetic song 1.2") == true }, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(playback.label, "Play", "Skipping while paused must retain the pause")
        let homeSeek = app.sliders["homeMusicSeek"]
        homeSeek.adjust(toNormalizedSliderPosition: 0.5)
        XCTAssertTrue(app.descendants(matching: .any)["homePage"].exists, "Seeking inside the card must not turn the Home page")
        XCTAssertFalse((homeSeek.value as? String)?.hasPrefix("0:00") == true)
        shot("Music Home widget shared test playback")
        open.tap()
        XCTAssertTrue(app.staticTexts["musicNowPlayingTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["musicNowPlayingTitle"].label, "Synthetic song 1.2")
        XCTAssertEqual(app.buttons["musicPlayback"].label, "Play")
        shot("Music immersive native player test data")
        tapReadyMusicButton("musicLibrary")
        XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5))
        let album = app.buttons["musicAlbum-validation-album-0"]
        XCTAssertTrue(album.waitForExistence(timeout: 5))
        album.swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["musicPage"].exists, "Cover Flow owns its horizontal drag")
        let nextAlbum = app.buttons["musicAlbum-validation-album-1"]
        XCTAssertTrue(nextAlbum.label.hasPrefix("Open"), "The swipe must select the next album")
        XCTAssertTrue((app.buttons["musicMiniPlayer"].value as? String)?.contains("Synthetic song 1.2") == true, "Browsing must not change the playing queue")
        shot("Music Cover Flow native test albums")
        waitForFocusedMusicCover("musicAlbum-validation-album-1")
        tapReadyMusicButton("musicAlbum-validation-album-1")
        let song = app.buttons["musicSong-validation-song-1-1"]
        XCTAssertTrue(song.waitForExistence(timeout: 5)); song.tap()
        waitForMusicMiniTitle("Synthetic song 2.2", playing: true)
        XCTAssertTrue(song.exists, "Song selection must stay in the browsed album")
        XCTAssertFalse(app.staticTexts["musicNowPlayingTitle"].exists)
        openFixtureMusicPlayer()
        waitForMusicTitle("Synthetic song 2.2")
        XCTAssertEqual(app.buttons["musicPlayback"].label, "Pause")
        app.buttons["musicQueue"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "musicQueueEntry-")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["musicLibrary"].tap()
        tab(1)
        XCTAssertTrue((app.buttons["homeMusicOpen"].value as? String)?.contains("Synthetic song 2.2") == true)
    }

    func testMusicBackNavigationRetainsLibraryAndExplicitHomePlayer() {
        launchMusicFixtureHome()
        openFixtureMusicLibrary()
        tapReadyMusicButton("musicNextAlbum")
        waitForFocusedMusicCover("musicAlbum-validation-album-1")
        tapReadyMusicButton("musicAlbum-validation-album-1")
        let song = app.buttons["musicSong-validation-song-1-0"]
        XCTAssertTrue(song.waitForExistence(timeout: 5))
        tab(1); tab(5)
        XCTAssertTrue(song.waitForExistence(timeout: 5), "Returning through navigation must restore the album's songs")
        app.buttons["musicLibrary"].tap()
        let focused = app.buttons["musicAlbum-validation-album-1"]
        XCTAssertTrue(focused.label.hasPrefix("Open"), "Returning from songs must retain the focused album")
        XCTAssertFalse(app.buttons["musicSearchOpen"].exists)
        XCTAssertFalse(app.textFields["musicSearchField"].exists)
        XCTAssertFalse(app.buttons["musicSearch"].exists)
        tab(1); tab(5)
        XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5),
                      "Page switching must restore album browsing without a search destination")
        waitForFocusedMusicCover("musicAlbum-validation-album-1")
        XCTAssertTrue(focused.label.hasPrefix("Open"))
        XCTAssertTrue((app.buttons["musicMiniPlayer"].value as? String)?.contains("Synthetic song 1.1") == true)
        app.buttons["musicPreviousAlbum"].tap()
        let first = app.buttons["musicAlbum-validation-album-0"]
        first.swipeRight()
        XCTAssertTrue(first.label.hasPrefix("Open"), "Dragging beyond the first album must snap back")
        XCTAssertFalse(app.buttons["musicPreviousAlbum"].isEnabled)
        shot("Music restored Cover Flow without search and with edge drag test data")
        tab(1); app.buttons["homeMusicOpen"].tap()
        XCTAssertTrue(app.staticTexts["musicNowPlayingTitle"].waitForExistence(timeout: 5), "The Home card explicitly opens the player")
        XCTAssertEqual(app.staticTexts["musicNowPlayingTitle"].label, "Synthetic song 1.1")
    }

    func testMusicFailedSelectionStaysInAlbumWithRealFailureFeedback() {
        app.terminate()
        app.launchArguments = ["--demo", "--uitesting", "--music-fixture", "--music-playback-failure", "-music.connected", "YES", "-homeWidgetLayouts", "", "-homeShortcuts", "", "-appLanguage", "en", "-display.nightMode", "off", "-display.screenBehaviorV1", "followSystem"]
        launchHome()
        openFixtureMusicLibrary()
        tapReadyMusicButton("musicAlbum-validation-album-0")
        let song = app.buttons["musicSong-validation-song-0-1"]
        XCTAssertTrue(song.waitForExistence(timeout: 5)); song.tap()
        XCTAssertTrue(app.staticTexts["musicMessage"].waitForExistence(timeout: 8))
        XCTAssertTrue(song.exists, "A rejected selection must leave the album visible")
        XCTAssertFalse(app.staticTexts["musicNowPlayingTitle"].exists)
        XCTAssertTrue(song.isEnabled, "Selection controls must recover after failure")
        XCTAssertTrue((app.buttons["musicMiniPlayer"].value as? String)?.contains("Synthetic song 1.1") == true)
        shot("Music failed selection stays in album test data")
    }

    func testMusicPlayerReturnsToSelectableAlbumsAfterAlbumOrPlaylistPlayback() {
        launchMusicFixtureHome()
        openFixtureMusicLibrary()
        tapReadyMusicButton("musicAlbum-validation-album-0")
        tapReadyMusicButton("musicSong-validation-song-0-1")
        waitForMusicMiniTitle("Synthetic song 1.2", playing: true)
        XCTAssertTrue(app.descendants(matching: .any)["musicAlbumTracks"].exists)
        XCTAssertFalse(app.staticTexts["musicNowPlayingTitle"].exists, "Selecting a song must keep the album on screen")
        tapReadyMusicButton("musicLibrary")
        tapReadyMusicButton("musicNextAlbum")
        waitForFocusedMusicCover("musicAlbum-validation-album-1")
        waitForMusicMiniTitle("Synthetic song 1.2", playing: true)
        shot("Music album browsing soft outer edges without changing playback")
        openFixtureMusicPlayer()
        waitForMusicTitle("Synthetic song 1.2")
        tapReadyMusicButton("musicLibrary")
        XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5),
                      "The player must return to selectable covers rather than album tracks or the queue")
        XCTAssertTrue(app.buttons["musicAlbumsTab"].isSelected)
        XCTAssertFalse(app.descendants(matching: .any)["musicAlbumTracks"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
        waitForFocusedMusicCover("musicAlbum-validation-album-0")
        waitForMusicMiniTitle("Synthetic song 1.2", playing: true)
        shot("Music player returns to selectable covers focused on the playing album")

        tapReadyMusicButton("musicPlaylistsTab")
        tapReadyMusicButton("musicPlaylist-validation-playlist-0")
        tapReadyMusicButton("musicPlaylistPlayAll")
        waitForMusicMiniTitle("Synthetic song 1.1", playing: true)
        XCTAssertTrue(app.descendants(matching: .any)["musicPlaylistTracks"].exists)
        tapReadyMusicButton("musicLibrary")
        tapReadyMusicButton("musicAlbumsTab")
        tapReadyMusicButton("musicNextAlbum")
        waitForFocusedMusicCover("musicAlbum-validation-album-1")
        openFixtureMusicPlayer()
        waitForMusicTitle("Synthetic song 1.1")
        tapReadyMusicButton("musicLibrary")
        XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5),
                      "Playlist playback also returns to selectable album covers")
        XCTAssertTrue(app.buttons["musicAlbumsTab"].isSelected)
        XCTAssertFalse(app.descendants(matching: .any)["musicPlaylistTracks"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
        XCUIDevice.shared.orientation = .landscapeRight
        waitForLandscape()
        let surface = app.descendants(matching: .any)["musicAlbumCoverFlowSurface"]
        XCTAssertTrue(surface.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.contains(surface.frame))
        waitForMusicMiniTitle("Synthetic song 1.1", playing: true)
        shot("Music selectable album four-edge surface in opposite landscape direction")
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    func testMusicLibraryModesSongCoverFlowQueueAndReadableSettings() {
        launchMusicFixtureHome()
        openFixtureMusicLibrary()
        func assertMode(_ selected: String) {
            for identifier in ["musicAlbumsTab", "musicSongsTab", "musicPlaylistsTab"] {
                let mode = app.buttons[identifier]
                XCTAssertTrue(mode.waitForExistence(timeout: 5))
                let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == %@", NSNumber(value: identifier == selected)), object: mode)
                XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
                XCTAssertEqual(mode.isSelected, identifier == selected, "The library's current content type must be explicit")
            }
        }
        assertMode("musicAlbumsTab")
        XCTAssertFalse(app.buttons["musicOpenAlbum"].exists)
        XCTAssertFalse(app.buttons["musicShuffleLibrary"].exists)
        XCTAssertFalse(app.staticTexts["Swipe to browse · tap a cover to choose songs"].exists)
        XCTAssertFalse(app.buttons["musicSearchOpen"].exists)
        XCTAssertFalse(app.textFields["musicSearchField"].exists)
        XCTAssertFalse(app.buttons["musicSearch"].exists)
        let albumSurface = app.descendants(matching: .any)["musicAlbumCoverFlowSurface"]
        XCTAssertTrue(albumSurface.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.contains(albumSurface.frame))
        shot("Music album four-edge floating cover surface")
        tapReadyMusicButton("musicSongsTab")
        assertMode("musicSongsTab")
        XCTAssertTrue(app.descendants(matching: .any)["musicSongCoverFlow"].waitForExistence(timeout: 5))
        let first = app.buttons["musicSongCover-validation-song-0-0"]
        waitForFocusedMusicCover("musicSongCover-validation-song-0-0", prefix: "Play")
        first.swipeLeft()
        waitForFocusedMusicCover("musicSongCover-validation-song-0-1", prefix: "Play")
        XCTAssertTrue(app.descendants(matching: .any)["musicPage"].exists, "The song carousel must own its horizontal drag")
        waitForMusicMiniTitle("Synthetic song 1.1", playing: false)
        let songSurface = app.descendants(matching: .any)["musicSongCoverFlowSurface"]
        XCTAssertTrue(songSurface.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.contains(songSurface.frame))
        shot("Music songs four-edge cover surface while browsing does not play")
        tapReadyMusicButton("musicSongCover-validation-song-0-1")
        waitForMusicMiniTitle("Synthetic song 1.2", playing: true)
        XCTAssertTrue(app.descendants(matching: .any)["musicSongCoverFlow"].exists)
        XCTAssertFalse(app.staticTexts["musicNowPlayingTitle"].exists, "Only the mini player opens the full player")
        tapReadyMusicButton("musicNextSongCover")
        waitForFocusedMusicCover("musicSongCover-validation-song-0-2", prefix: "Play")
        waitForMusicMiniTitle("Synthetic song 1.2", playing: true)
        tapReadyMusicButton("musicPlayFocusedSong")
        waitForMusicMiniTitle("Synthetic song 1.3", playing: true)
        openFixtureMusicPlayer()
        waitForMusicTitle("Synthetic song 1.3")
        tapReadyMusicButton("musicQueue")
        let entries = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "musicQueueEntry-"))
        let complete = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in entries.count == 9 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [complete], timeout: 5), .completed,
                       "Explicit song playback must enqueue the complete nine-song library")
        let titles = (1...3).flatMap { album in (1...3).map { song in "Synthetic song \(album).\(song)" } }
        for (index, title) in titles.enumerated() {
            XCTAssertTrue(entries.element(boundBy: index).label.contains(title), "Library queue order must retain every song")
        }
        let last = entries.element(boundBy: 8)
        let queueScroll = app.scrollViews["musicQueueList"]
        XCTAssertTrue(queueScroll.waitForExistence(timeout: 5))
        var previousQueueFrame: CGRect?, previousMiniFrame: CGRect?
        let queueSettled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = queueScroll.frame, mini = self.app.buttons["musicMiniPlayer"].frame
            guard frame.width > 0, frame.height > 80, self.app.frame.contains(frame), self.app.frame.contains(mini) else { return false }
            let stable = previousQueueFrame == frame && previousMiniFrame == mini
            previousQueueFrame = frame; previousMiniFrame = mini
            return stable
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [queueSettled], timeout: 5), .completed)
        func visibleQueueRect() -> CGRect {
            var visible = queueScroll.frame.intersection(app.frame)
            let mini = app.buttons["musicMiniPlayer"]
            if mini.exists { visible.size.height = max(0, min(visible.maxY, mini.frame.minY - 12) - visible.minY) }
            // Rows fill the actual scroll width. Shrinking it horizontally
            // would make full-row containment impossible even after scrolling.
            return visible.insetBy(dx: 0, dy: 4)
        }
        func captureQueueTarget(_ name: String) {
            XCTContext.runActivity(named: name) { activity in
                let trace = XCTAttachment(string: "App: \(app.frame)\nScroll: \(queueScroll.frame)\nVisible: \(visibleQueueRect())\nTarget: \(last.frame)\nMini: \(app.buttons["musicMiniPlayer"].value ?? "none")\n\n" + app.debugDescription)
                trace.lifetime = .keepAlways; activity.add(trace)
                let pixels = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); pixels.name = name
                pixels.lifetime = .keepAlways; activity.add(pixels)
            }
        }
        captureQueueTarget("Music ninth queue item before ensuring complete visibility")
        for attempt in 0..<8 {
            if visibleQueueRect().contains(last.frame), last.isHittable { break }
            let visible = visibleQueueRect()
            XCTAssertGreaterThan(visible.height, 80)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: visible.midX - app.frame.minX, dy: visible.maxY - 20 - app.frame.minY))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: visible.midX - app.frame.minX, dy: visible.minY + 20 - app.frame.minY)))
            captureQueueTarget("Music ninth queue item after scroll \(attempt + 1)")
        }
        XCTAssertTrue(visibleQueueRect().contains(last.frame), "The entire ninth row must be inside the actual scroll viewport, above the fixed mini player")
        XCTAssertTrue(last.isHittable); XCTAssertTrue(last.isEnabled)
        captureQueueTarget("Music ninth queue item fully visible before selection")
        last.tap()
        captureQueueTarget("Music ninth queue item immediately after selection")
        waitForMusicMiniTitle("Synthetic song 3.3", playing: true)
        XCTAssertTrue(app.descendants(matching: .any)["musicQueueList"].exists, "Selecting a queue occurrence must preserve the queue page")
        openFixtureMusicPlayer()
        waitForMusicTitle("Synthetic song 3.3")
        XCTAssertFalse(app.buttons["musicNext"].isEnabled)
        tapReadyMusicButton("musicLibrary")
        assertMode("musicAlbumsTab")
        XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
        XCTAssertFalse(app.buttons["musicLibrary"].exists, "A library root has no redundant back-to-player button")
        tapReadyMusicButton("musicSongsTab")
        assertMode("musicSongsTab")
        waitForFocusedMusicCover("musicSongCover-validation-song-2-2", prefix: "Play")
        tab(1); tab(5)
        XCTAssertTrue(app.descendants(matching: .any)["musicSongCoverFlow"].waitForExistence(timeout: 5))
        waitForFocusedMusicCover("musicSongCover-validation-song-2-2", prefix: "Play")
        tapReadyMusicButton("musicPlaylistsTab")
        assertMode("musicPlaylistsTab")
        XCTAssertTrue(app.descendants(matching: .any)["musicPlaylists"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["musicCoverFlow"].exists)
        tapReadyMusicButton("musicAlbumsTab")
        assertMode("musicAlbumsTab")
        waitForMusicMiniTitle("Synthetic song 3.3", playing: true)
        tapReadyMusicButton("musicSongsTab")
        assertMode("musicSongsTab")
        waitForFocusedMusicCover("musicSongCover-validation-song-2-2", prefix: "Play")
        tapReadyMusicButton("musicOptions")
        let settings = app.descendants(matching: .any)["musicSettingsForm"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Music settings"].exists)
        XCTAssertTrue(app.staticTexts["Apple Music connected"].exists)
        let refresh = app.buttons["refreshMusicLibrary"], files = app.buttons["chooseAudioFile"]
        reveal(refresh); XCTAssertTrue(refresh.isHittable)
        tapReadyMusicButton("refreshMusicLibrary")
        XCTAssertTrue(app.staticTexts["Apple Music connected"].waitForExistence(timeout: 5),
                      "Refreshing the Form row must reload the library without activating Disconnect")
        XCTAssertTrue(settings.exists, "An explicit refresh must leave Music settings presented")
        XCTAssertTrue(refresh.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["disconnectMusic"].exists)
        XCTAssertFalse(app.buttons["connectAppleMusic"].exists,
                       "The refresh action must not disconnect the existing Apple Music connection")
        reveal(files); XCTAssertTrue(files.isHittable)
        shot("Music settings readable native form landscape left")
        XCUIDevice.shared.orientation = .landscapeRight
        waitForLandscape()
        XCTAssertTrue(settings.exists)
        reveal(files); XCTAssertTrue(files.isHittable)
        shot("Music settings readable native form landscape right")
        closeMusicSettings()
        XCTAssertTrue(app.descendants(matching: .any)["musicSongCoverFlow"].waitForExistence(timeout: 5),
                      "Closing settings after refresh must preserve the song library page")
        assertMode("musicSongsTab")
        waitForFocusedMusicCover("musicSongCover-validation-song-2-2", prefix: "Play")
        waitForMusicMiniTitle("Synthetic song 3.3", playing: true)
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    func testMusicRepeatedQueueExitReachesAlbumsAndVolumePreservesBrowsingAndPlayback() {
        launchMusicFixtureHome()
        tapReadyMusicButton("homeMusicOpen")
        waitForFixtureMusicPlayerEntry()
        for cycle in 0..<2 {
            let playing = cycle == 1
            waitForMusicTitle("Synthetic song 1.1")
            XCTAssertEqual(app.buttons["musicPlayback"].label, playing ? "Pause" : "Play")
            let queueButton = app.buttons["musicQueue"]
            XCTAssertTrue(queueButton.isHittable)
            XCTAssertGreaterThanOrEqual(queueButton.frame.width, 44)
            XCTAssertGreaterThanOrEqual(queueButton.frame.height, 44)
            tapReadyMusicButton("musicQueue")
            XCTAssertTrue(app.descendants(matching: .any)["musicQueueList"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.descendants(matching: .any)["musicCoverFlow"].exists)
            let entries = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "musicQueueEntry-"))
            XCTAssertEqual(entries.count, 3)
            for index in 0..<3 { XCTAssertTrue(entries.element(boundBy: index).label.contains("Synthetic song 1.\(index + 1)")) }
            tapReadyMusicButton("musicLibrary")
            waitForFixtureMusicPlayerEntry()
            waitForMusicTitle("Synthetic song 1.1")
            XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
            tapReadyMusicButton("musicLibrary")
            XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5),
                          "Queue back → player back must always reach selectable album covers")
            XCTAssertTrue(app.buttons["musicAlbumsTab"].isSelected)
            XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["musicAlbumTracks"].exists)
            XCTAssertFalse(app.buttons["musicSearchOpen"].exists)
            waitForMusicMiniTitle("Synthetic song 1.1", playing: playing)
            XCUIDevice.shared.orientation = cycle == 0 ? .landscapeLeft : .landscapeRight
            waitForLandscape()
            let surface = app.descendants(matching: .any)["musicAlbumCoverFlowSurface"]
            XCTAssertTrue(surface.waitForExistence(timeout: 5))
            XCTAssertTrue(app.frame.contains(surface.frame))
            let volume = app.buttons["musicVolume"]
            XCTAssertTrue(volume.isHittable)
            XCTAssertTrue(app.frame.contains(volume.frame))
            XCTAssertGreaterThanOrEqual(volume.frame.width, 44)
            XCTAssertGreaterThanOrEqual(volume.frame.height, 44)
            tapReadyMusicButton("musicVolume")
            let panel = app.descendants(matching: .any)["musicVolumePanel"]
            XCTAssertTrue(panel.waitForExistence(timeout: 5))
            XCTAssertTrue(panel.descendants(matching: .any)["musicSystemVolumeControl"].exists,
                          "Only native volume-view presence is checked; volume is not read or adjusted")
            shot("Music native volume panel and album exit landscape \(cycle == 0 ? "left" : "right")")
            tapReadyMusicButton("musicVolumeDone")
            XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
            XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["musicAlbumsTab"].isSelected)
            waitForMusicMiniTitle("Synthetic song 1.1", playing: playing)
            shot("Music selectable four-edge album covers after volume landscape \(cycle == 0 ? "left" : "right")")
            if cycle == 0 {
                tapReadyMusicButton("musicMiniPlayback")
                waitForMusicMiniTitle("Synthetic song 1.1", playing: true)
                openFixtureMusicPlayer()
            }
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        tab(1)
        XCTAssertTrue((app.buttons["homeMusicOpen"].value as? String)?.contains("Synthetic song 1.1") == true)
        XCTAssertEqual(app.buttons["homeMusicPlayback"].label, "Pause")
    }

    func testMusicUnknownRestoredSourceReturnsToAlbumsWithAndWithoutAlbumLibrary() {
        for emptyAlbums in [false, true] {
            let flags = ["--music-restored-unknown"] + (emptyAlbums ? ["--music-empty-albums"] : [])
            launchMusicBoundaryFixture(extraArguments: flags, initialTitle: "Restored test song", hasPlayback: true)
            tapReadyMusicButton("homeMusicOpen")
            waitForFixtureMusicPlayerEntry()
            waitForMusicTitle("Restored test song")
            XCTAssertEqual(app.buttons["musicPlayback"].label, "Play")
            XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
            tapReadyMusicButton("musicQueue")
            XCTAssertTrue(app.descendants(matching: .any)["musicQueueList"].waitForExistence(timeout: 5))
            let entries = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "musicQueueEntry-"))
            XCTAssertEqual(entries.count, 1)
            let restored = app.buttons["musicQueueEntry-validation-entry-validation-restored-unknown-0"]
            XCTAssertTrue(restored.exists)
            XCTAssertTrue(restored.label.contains("Restored test song"))
            shot("Music unknown restored queue with \(emptyAlbums ? "empty" : "available") album library")

            tapReadyMusicButton("musicLibrary")
            waitForFixtureMusicPlayerEntry()
            waitForMusicTitle("Restored test song")
            XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
            tapReadyMusicButton("musicLibrary")
            XCTAssertTrue(app.buttons["musicAlbumsTab"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["musicAlbumsTab"].isSelected,
                          "An unknown restored source must exit to Albums rather than enter its queue again")
            if emptyAlbums {
                XCTAssertTrue(app.staticTexts["Your library has no available albums."].waitForExistence(timeout: 5))
                XCTAssertFalse(app.descendants(matching: .any)["musicCoverFlow"].exists)
                XCTAssertFalse(app.buttons["musicAlbum-validation-album-0"].exists)
            } else {
                XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5))
                waitForFocusedMusicCover("musicAlbum-validation-album-0")
            }
            XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["musicAlbumTracks"].exists)
            XCTAssertFalse(app.buttons["musicSearchOpen"].exists)
            waitForMusicMiniTitle("Restored test song", playing: false)

            tapReadyMusicButton("musicSongsTab")
            XCTAssertTrue(app.descendants(matching: .any)["musicSongCoverFlow"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["musicSongsTab"].isSelected)
            XCTAssertFalse(app.buttons["musicAlbumsTab"].isSelected)
            waitForFocusedMusicCover("musicSongCover-validation-song-0-0", prefix: "Play")
            XCTAssertFalse(app.buttons["musicSongCover-validation-restored-unknown"].exists,
                           "The restored item is deliberately absent from the library and has no album metadata")
            XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
            XCTAssertFalse(app.buttons["musicSearchOpen"].exists)
            waitForMusicMiniTitle("Restored test song", playing: false)
            shot("Music unknown restored source exits to selectable songs with \(emptyAlbums ? "empty" : "available") albums")
        }
    }

    func testMusicInitiallyEmptyQueueCanPlayWholeAlbumAndReturnToCards() {
        launchMusicBoundaryFixture(extraArguments: ["--music-empty-queue"], initialTitle: "Choose your music", hasPlayback: false)
        tapReadyMusicButton("homeMusicOpen")
        waitForFixtureMusicPlayerEntry()
        waitForMusicTitle("Choose your music")
        XCTAssertFalse(app.buttons["musicPlayback"].isEnabled)
        XCTAssertFalse(app.sliders["musicSeek"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
        tapReadyMusicButton("musicQueue")
        XCTAssertTrue(app.descendants(matching: .any)["musicQueueList"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["The playback queue is empty."].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "musicQueueEntry-")).count, 0)
        XCTAssertFalse(app.buttons["musicMiniPlayer"].exists)
        shot("Music explicitly opened empty queue test data")
        tapReadyMusicButton("musicLibrary")
        waitForFixtureMusicPlayerEntry()
        waitForMusicTitle("Choose your music")
        tapReadyMusicButton("musicLibrary")
        XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["musicAlbumsTab"].isSelected)
        waitForFocusedMusicCover("musicAlbum-validation-album-0")
        XCTAssertFalse(app.buttons["musicMiniPlayer"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)

        // Reopening the foreground music card preserves the accepted empty
        // player behavior; simply browsing never invents or starts a queue.
        tab(1)
        XCTAssertTrue((app.buttons["homeMusicOpen"].value as? String)?.contains("Choose your music") == true)
        XCTAssertFalse(app.buttons["homeMusicPlayback"].isEnabled)
        tapReadyMusicButton("homeMusicOpen")
        waitForFixtureMusicPlayerEntry()
        waitForMusicTitle("Choose your music")
        XCTAssertFalse(app.buttons["musicPlayback"].isEnabled)
        XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
        tapReadyMusicButton("musicLibrary")
        XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5))
        waitForFocusedMusicCover("musicAlbum-validation-album-0")
        tapReadyMusicButton("musicAlbum-validation-album-0")
        XCTAssertTrue(app.descendants(matching: .any)["musicAlbumTracks"].waitForExistence(timeout: 5))
        tapReadyMusicButton("musicAlbumPlayAll")
        waitForMusicMiniTitle("Synthetic song 1.1", playing: true)
        XCTAssertTrue(app.descendants(matching: .any)["musicAlbumTracks"].exists,
                      "Explicit whole-album playback must keep the current browsing page")
        openFixtureMusicPlayer()
        waitForMusicTitle("Synthetic song 1.1")
        XCTAssertEqual(app.buttons["musicPlayback"].label, "Pause")
        tapReadyMusicButton("musicQueue")
        XCTAssertTrue(app.descendants(matching: .any)["musicQueueList"].waitForExistence(timeout: 5))
        let entries = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "musicQueueEntry-"))
        XCTAssertEqual(entries.count, 3, "Play all must replace the empty queue with the entire album")
        for index in 0..<3 {
            let entry = app.buttons["musicQueueEntry-validation-entry-validation-song-0-\(index)-\(index)"]
            XCTAssertTrue(entry.exists)
            XCTAssertTrue(entry.label.contains("Synthetic song 1.\(index + 1)"))
        }
        tapReadyMusicButton("musicLibrary")
        waitForFixtureMusicPlayerEntry()
        waitForMusicTitle("Synthetic song 1.1")
        tapReadyMusicButton("musicLibrary")
        XCTAssertTrue(app.descendants(matching: .any)["musicCoverFlow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["musicAlbumsTab"].isSelected)
        waitForFocusedMusicCover("musicAlbum-validation-album-0")
        XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["musicAlbumTracks"].exists)
        XCTAssertFalse(app.buttons["musicSearchOpen"].exists)
        waitForMusicMiniTitle("Synthetic song 1.1", playing: true)
        shot("Music whole album started from empty queue returns to selectable album card")
    }

    func testMusicAccessibleChinesePlayerAndAlbumList() {
        app.terminate()
        app.launchArguments = ["--demo", "--uitesting", "--music-fixture", "-music.connected", "YES", "-homeWidgetLayouts", "", "-homeShortcuts", "", "-appLanguage", "zh-Hans", "-display.nightMode", "off", "-display.screenBehaviorV1", "followSystem", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchHome()
        let open = app.buttons["homeMusicOpen"]
        reveal(open); XCTAssertTrue(open.isHittable); open.tap()
        waitForFixtureMusicPlayerEntry()
        let playback = app.buttons["musicPlayback"]
        reveal(playback); XCTAssertTrue(playback.isHittable)
        XCTAssertTrue(app.staticTexts["musicValidationData"].exists)
        let pages = app.buttons["showNavigationButton"]
        XCTAssertEqual(pages.label, "切换页面")
        XCTAssertTrue(pages.isHittable)
        XCTAssertTrue(app.frame.contains(pages.frame), "Largest-text player must retain its page exit")
        shot("Music Chinese accessibility player test data")
        let volume = app.buttons["musicVolume"]
        XCTAssertTrue(volume.isHittable)
        XCTAssertGreaterThanOrEqual(volume.frame.width, 44)
        XCTAssertGreaterThanOrEqual(volume.frame.height, 44)
        tapReadyMusicButton("musicVolume")
        let volumePanel = app.descendants(matching: .any)["musicVolumePanel"]
        XCTAssertTrue(volumePanel.waitForExistence(timeout: 5))
        XCTAssertTrue(volumePanel.descendants(matching: .any)["musicSystemVolumeControl"].exists,
                      "The panel contains the native system volume view; no volume value is changed")
        shot("Music Chinese largest-text volume panel native controls")
        tapReadyMusicButton("musicVolumeDone")
        XCTAssertTrue(volumePanel.waitForNonExistence(timeout: 5))
        waitForFixtureMusicPlayerEntry()
        XCTAssertEqual(playback.label, "播放")
        tapReadyMusicButton("musicOptions")
        let settings = app.descendants(matching: .any)["musicSettingsForm"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["音乐设置"].exists)
        let refresh = app.buttons["refreshMusicLibrary"]
        reveal(refresh); XCTAssertTrue(refresh.isHittable)
        shot("Music settings Chinese largest text readable native form")
        let files = app.buttons["chooseAudioFile"]
        reveal(files); XCTAssertTrue(files.isHittable)
        shot("Music settings Chinese largest text audio file controls")
        closeMusicSettings()
        tapReadyMusicButton("musicLibrary")
        XCTAssertTrue(app.buttons["musicAlbumsTab"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["musicQueueList"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["musicAlbumTracks"].exists)
        XCTAssertTrue(app.buttons["musicAlbumsTab"].isSelected)
        XCTAssertFalse(app.descendants(matching: .any)["musicCoverFlow"].exists, "Large text uses an accessible album list")
        let album = app.buttons["musicAlbum-validation-album-0"]
        XCTAssertTrue(album.waitForExistence(timeout: 5)); album.tap()
        let song = app.buttons["musicSong-validation-song-0-1"]
        reveal(song); XCTAssertTrue(song.isHittable)
        shot("Music Chinese accessibility album tracks test data")
        tab(4)
        XCTAssertTrue(app.buttons["settingsHome"].waitForExistence(timeout: 5))
    }

    func testRealMusicCalendarAndCameraConnectionEntrypoints() {
        app.terminate()
        app.launchArguments = ["--fresh", "--uitesting", "-appLanguage", "en", "-music.connected", "NO", "-showPersonal", "NO", "-display.nightMode", "off"]
        launchHome()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertFalse(springboard.alerts.firstMatch.exists)
        tab(5)
        XCTAssertTrue(app.buttons["connectAppleMusic"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Apple Music connected"].exists)
        XCTAssertFalse(springboard.alerts.firstMatch.exists, "Opening Music must not request access")
        XCTAssertEqual(app.buttons["showNavigationButton"].label, "Switch page")
        XCTAssertTrue(app.buttons["showNavigationButton"].isHittable)
        shot("Real Apple Music page before connecting")
        panel("agendaCard")
        XCTAssertTrue(app.buttons["connectCalendar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["DEMO · No calendar is connected"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "reminders")).firstMatch.exists)
        XCTAssertFalse(springboard.alerts.firstMatch.exists, "Opening calendar must not request access")
        shot("Real calendar explicit connection and shared-screen explanation")
        closePanel()
        panel("cameraCard")
        XCTAssertTrue(app.staticTexts["Connect your home first"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Demo camera"].exists)
        XCTAssertFalse(springboard.alerts.firstMatch.exists, "Opening camera without a home must not use this iPad camera")
        closePanel()
        tab(4); settingsCategory("settingsHome")
        XCTAssertTrue(app.descendants(matching: .any)["settingsSelectedHome"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settingsHomeConnectionStatus"].exists)
        XCTAssertTrue(app.buttons["connectHome"].exists)
        shot("Real household selection before connection")
    }

    func testMultipleSelectedPhotosWallPersistenceCancellationAndStandby() throws {
        openPhotoSettings()
        let choose = app.buttons["singlePhotoPicker"]
        choose.tap()
        XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 8))
        let photos = app.images.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Photo,", "照片,"))
        XCTAssertTrue(photos.element(boundBy: 1).waitForExistence(timeout: 8), "The isolated simulator must contain the seeded photos")
        for index in 0..<2 {
            let photo = photos.element(boundBy: index)
            XCTAssertGreaterThan(photo.frame.width, 1)
            photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        let confirmation = app.buttons.matching(NSPredicate(format: "(identifier == %@ OR label IN %@) AND identifier != %@", "Add", ["Add", "Done", "添加", "完成"], "dismissPanel")).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 8))
        XCTAssertTrue(confirmation.isEnabled)
        confirmation.tap()
        let count = app.staticTexts["selectedPhotoCount"]
        expectation(for: NSPredicate { _, _ in count.label == "2 photos" }, evaluatedWith: nil); waitForExpectations(timeout: 20)
        shot("Multiple selected photos saved")
        choose.tap(); XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 5)); app.buttons["Cancel"].firstMatch.tap()
        XCTAssertEqual(count.label, "2 photos", "Cancelling keeps the saved wall")
        closePanel()
        let composition = app.descendants(matching: .any)["photoWallComposition"]
        XCTAssertTrue(composition.waitForExistence(timeout: 5)); XCTAssertEqual(composition.value as? String, "2 photos")
        shot("Real selected-photo wall with two synthetic photos")
        app.terminate(); launchHome(); tab(3)
        XCTAssertEqual(composition.value as? String, "2 photos", "The wall must restore the saved multi-photo selection")
        tab(4); settingsCategory("settingsDisplay")
        let content = app.buttons["standbyContent"]
        reveal(content)
        let currentValue = content.staticTexts.firstMatch
        if currentValue.isHittable { currentValue.tap() } else { content.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap() }
        app.buttons["Photo wall"].tap()
        let preview = app.buttons["standbyPreview"]
        reveal(preview); preview.tap()
        XCTAssertTrue(app.staticTexts["Tap anywhere to wake"].waitForExistence(timeout: 5))
        XCTAssertEqual(composition.value as? String, "2 photos")
        shot("Photo wall standby preview")
        composition.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.descendants(matching: .any)["settingsPage"].waitForExistence(timeout: 5))
        // Restore through the real setting so later clock tests retain their fixture.
        reveal(content, towardTop: true)
        let selected = content.staticTexts.firstMatch
        if selected.isHittable { selected.tap() } else { content.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap() }
        app.buttons["Clock"].tap()
    }

    func testHomeInPlaceEditingReordersPersistsAndNeverOperatesDevices() {
        XCTAssertFalse(app.buttons["homeRemove-slot-1"].exists)
        let card = app.descendants(matching: .any)["homeWidget-slot-1"]
        card.press(forDuration: 1.2)
        tapReadyMusicButton("contextEditHome")
        shot("Home immediately after edit context action")
        XCTAssertTrue(app.buttons["homeEditDone"].waitForExistence(timeout: 4))
        let power = app.buttons["accessory-Pendant lights"]
        XCTAssertFalse(power.isEnabled)
        let beforePower = power.label
        power.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertEqual(power.label, beforePower, "Editing must consume touches without changing accessory state")
        let drag = app.descendants(matching: .any)["homeDrag-slot-1"]
        let target = app.descendants(matching: .any)["homeWidget-slot-0"]
        drag.press(forDuration: 0.8, thenDragTo: target)
        shot("Home after dragging clock onto climate")
        let first = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in card.frame.minX < target.frame.minX }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [first], timeout: 5), .completed)
        let cameraHandle = app.descendants(matching: .any)["homeDrag-camera"]
        let musicHandle = app.descendants(matching: .any)["homeDrag-music"]
        musicHandle.press(forDuration: 0.8, thenDragTo: cameraHandle)
        XCTAssertLessThan(musicHandle.frame.minY, cameraHandle.frame.minY)
        let rightCamera = app.descendants(matching: .any)["shortcut-camera"]
        let rightMusic = app.descendants(matching: .any)["shortcut-music"]
        shot("In-place Home edit controls keep approved card geometry")
        XCTAssertTrue(app.buttons["homeRemove-slot-1"].isEnabled)
        app.buttons["homeRemove-slot-1"].tap()
        shot("Home after removing reordered clock")
        XCTAssertTrue(card.waitForNonExistence(timeout: 4))
        app.buttons["homeEditAdd"].tap(); app.buttons["editAddControl"].tap()
        XCTAssertTrue(app.buttons["widgetOption-clock"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["widgetOption-camera"].exists)
        app.buttons["widgetOption-clock"].tap()
        XCTAssertTrue(app.buttons["homeEditDone"].waitForExistence(timeout: 4))
        app.buttons["homeEditDone"].tap()
        XCTAssertFalse(app.buttons["homeRemove-slot-0"].exists)
        tab(2); tab(1)
        XCTAssertLessThan(rightMusic.frame.minY, rightCamera.frame.minY)
        XCTAssertFalse(card.exists)
        XCTAssertTrue(app.buttons["accessory-Pendant lights"].isEnabled)
        app.terminate()
        for key in ["-homeWidgetLayouts", "-homeShortcuts"] {
            if let index = app.launchArguments.firstIndex(of: key) { app.launchArguments.removeSubrange(index...index + 1) }
        }
        launchHome()
        XCTAssertLessThan(rightMusic.frame.minY, rightCamera.frame.minY)
        XCTAssertFalse(card.exists)
        shot("Home leaves editing and preserves right column order")
    }
    func testHomeMinimalControlKeepsMetadataBehindDetails() {
        app.terminate(); app.launchArguments += ["--homekit-coverage-fixture"]; launchHome()
        app.buttons["accessory-Door lock"].tap()
        XCTAssertTrue(app.staticTexts["accessoryDetailState"].waitForExistence(timeout: 4))
        let readings = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "accessoryReading-"))
        XCTAssertEqual(readings.count, 0)
        XCTAssertTrue(app.buttons["accessoryInformation"].isHittable)
        shot("Minimal lock control before details")
        app.buttons["accessoryInformation"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["accessoryInformationPage"].waitForExistence(timeout: 3))
        XCTAssertGreaterThan(readings.count, 0)
        shot("Accessory information in a separate destination")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["accessoryDetailState"].waitForExistence(timeout: 3))
        XCTAssertEqual(readings.count, 0)
    }
    func testMusicBackdropFadesWithoutReplacingIndependentPages() {
        launchMusicFixtureHome()
        let playback = app.buttons["homeMusicPlayback"]
        XCTAssertEqual(playback.label, "Play")
        shot("Home saved background before music fade")
        playback.tap(); XCTAssertEqual(playback.label, "Pause")
        shot("Home music background fades in")
        tab(2); shot("Clock shares playing music background")
        tab(3); XCTAssertTrue(app.descendants(matching: .any)["photoWall"].waitForExistence(timeout: 5))
        shot("Photo wall remains independent during music playback")
        tab(1); playback.tap(); XCTAssertEqual(playback.label, "Play")
        shot("Home music fades back to saved background")
    }

    func testHomeFavoritesEditorRevealsAddsAndRequiresRestoreConfirmation() throws {
        XCTAssertFalse(app.buttons["cameraWidget"].exists)
        let sidebar = app.descendants(matching: .any)["shortcut-camera"]
        XCTAssertTrue(sidebar.exists)
        let widgets = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "homeWidget-"))
        let before = Set(widgets.allElementsBoundByIndex.map(\.identifier))
        navigationAction("beginHomeEditing")
        app.buttons["editHomeLayout"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["homeLayoutEditor"].waitForExistence(timeout: 4))
        app.buttons["layoutAddFavorite"].tap()
        XCTAssertFalse(app.buttons["widgetOption-camera"].exists)
        XCTAssertFalse(app.buttons["widgetOption-agenda"].exists)
        app.buttons["widgetOption-clock"].tap()
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let ids = Set(widgets.allElementsBoundByIndex.map(\.identifier)).subtracting(before)
            guard let id = ids.first else { return false }
            return self.app.frame.contains(self.app.descendants(matching: .any)[id].frame)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 6), .completed, "Added card must be fully revealed without manual scrolling")
        let addedID = try XCTUnwrap(Set(widgets.allElementsBoundByIndex.map(\.identifier)).subtracting(before).first)
        let id = String(addedID.dropFirst("homeWidget-".count))
        shot("New favorite automatically revealed")
        app.buttons["editHomeLayout"].tap()
        let size = app.buttons["layoutSize-" + id]
        reveal(size); size.tap()
        app.buttons["moveFirst-" + id].tap()
        closePanel()
        let added = app.descendants(matching: .any)[addedID]
        app.descendants(matching: .any)["homeControlGrid"].swipeDown()
        XCTAssertLessThan(added.frame.minY, app.descendants(matching: .any)["homeWidget-slot-0"].frame.minY + 2)
        app.buttons["homeEditDone"].tap()
        navigationAction("restoreHomeWidgets")
        XCTAssertTrue(app.buttons["confirmRestoreWidgets"].firstMatch.waitForExistence(timeout: 4))
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "取消"])).firstMatch
        if cancel.exists { cancel.tap() }
        else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.08)).tap() }
        XCTAssertTrue(app.buttons["confirmRestoreWidgets"].firstMatch.waitForNonExistence(timeout: 4))
        XCTAssertTrue(added.exists, "Cancel must preserve the customized favorites")
        shot("Home favorite editing and right-only content")
    }

    func testHomeDimmerCommitsOnReleaseAndOfflineKeepsIndependentCards() {
        app.terminate()
        app.launchArguments += ["--home-controls-fixture"]
        launchHome()
        app.buttons["accessoryDetails-Pendant lights"].tap()
        let dimmer = app.descendants(matching: .any)["adjustment-brightness"]
        XCTAssertTrue(dimmer.waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["applyAdjustment-brightness"].exists)
        dimmer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            .press(forDuration: 0.1, thenDragTo: dimmer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        let applied = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (dimmer.value as? String)?.hasPrefix("80") == true && !self.app.buttons["retryAdjustment-brightness"].exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [applied], timeout: 5), .completed)
        shot("Focused large light dimmer after confirmed adjustment")
        closePanel()
        app.terminate(); app.launchArguments += ["--home-offline-fixture"]; launchHome()
        XCTAssertTrue(app.descendants(matching: .any)["clockWidget"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["shortcut-music"].exists)
        XCTAssertTrue(app.staticTexts["homeMusicTitle"].exists)
        XCTAssertTrue(app.buttons["accessory-Pendant lights"].label.contains("Offline"))
        XCTAssertFalse(app.buttons["accessory-Pendant lights"].isEnabled)
        shot("Offline accessories keep Home layout clock and music")
    }

    func testLegacyLeftCameraAndCalendarMigrateToRightColumn() {
        app.terminate()
        app.launchArguments = ["--demo", "--uitesting", "--home-legacy-fixture", "-appLanguage", "en", "-display.nightMode", "off"]
        launchHome()
        XCTAssertTrue(app.descendants(matching: .any)["homeWidget-old-clock"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["homeWidget-old-camera"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["homeWidget-old-calendar"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["shortcut-migrated-demo-old-camera"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["shortcut-migrated-demo-old-calendar"].exists)
        XCTAssertFalse(app.buttons["cameraWidget"].exists)
        shot("Legacy camera and calendar preserved in right column")
    }

    func testHomeKitLockCoverAndSensorControlsUseTheirActualStates() {
        app.terminate(); app.launchArguments += ["--homekit-coverage-fixture"]; launchHome()
        XCTAssertTrue(app.buttons["accessory-Door lock"].label.contains("Locked"))
        app.buttons["accessory-Door lock"].tap()
        XCTAssertFalse(app.buttons["accessoryDetailPower"].exists)
        let unlock = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@", "accessoryOption-", "-0")).firstMatch
        XCTAssertTrue(unlock.waitForExistence(timeout: 4)); unlock.tap()
        XCTAssertTrue(app.staticTexts["accessoryDetailState"].label.contains("Unlocked"))
        shot("HomeKit lock explicit controls and current state with battery")
        closePanel()
        XCTAssertTrue(app.buttons["accessory-Door lock"].label.contains("Unlocked"))
        app.buttons["accessory-Window covering"].tap()
        let position = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "adjustment-")).firstMatch
        XCTAssertTrue(position.waitForExistence(timeout: 4))
        position.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).press(forDuration: 0.1,
            thenDragTo: position.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        XCTAssertTrue((position.value as? String)?.hasPrefix("80") == true)
        let stop = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@", "accessoryOption-", "-1")).firstMatch
        XCTAssertTrue(app.frame.contains(stop.frame)); stop.tap()
        XCTAssertTrue(app.staticTexts["accessoryCommandNotice"].waitForExistence(timeout: 3))
        shot("HomeKit window covering position and stop controls")
        closePanel()
        app.buttons["accessory-Motion sensor"].tap()
        XCTAssertTrue(app.staticTexts["accessoryDetailState"].label.contains("No motion"))
        XCTAssertFalse(app.buttons["accessoryDetailPower"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "accessoryOption-")).count, 0)
        shot("HomeKit sensor read-only state is not a switch")
    }

    func testHomeKitAirPurifierModeSecurityAndTypedValvePower() {
        app.terminate(); app.launchArguments += ["--homekit-coverage-fixture"]; launchHome()
        app.buttons["accessoryDetails-Air purifier"].tap()
        let manual = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@", "accessoryOption-", "-0")).firstMatch
        XCTAssertTrue(manual.waitForExistence(timeout: 4)); manual.tap()
        XCTAssertEqual(manual.value as? String, "Selected")
        shot("HomeKit purifier uses Active power fan speed and modes")
        closePanel()
        app.buttons["accessory-Security system"].tap()
        let disarm = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@", "accessoryOption-", "-3")).firstMatch
        XCTAssertTrue(disarm.waitForExistence(timeout: 4)); disarm.tap()
        XCTAssertTrue(app.staticTexts["accessoryDetailState"].label.contains("Disarmed"))
        shot("HomeKit security modes separate from alarms")
        closePanel()
        XCTAssertTrue(app.buttons["accessory-Valve"].label.contains("Off"))
        app.buttons["accessory-Valve"].tap()
        XCTAssertTrue(app.buttons["accessory-Valve"].label.contains("On"))
        shot("HomeKit six device families on unchanged Home grid")
    }

    func testHomeKitChineseLargestTextControlsRemainScrollableAndComplete() {
        app.terminate(); app.launchArguments += ["--homekit-coverage-fixture", "-appLanguage", "zh-Hans", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        launchHome()
        let details = app.buttons["accessoryDetails-Air purifier"]
        reveal(details); details.tap()
        let modes = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "accessoryOption-")).firstMatch
        reveal(modes)
        XCTAssertTrue(modes.exists); XCTAssertTrue(app.frame.contains(modes.frame))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "净化")).firstMatch.exists)
        shot("Chinese largest text HomeKit purifier controls")
        closePanel(); XCUIDevice.shared.orientation = .landscapeRight; waitForLandscape()
        let lock = app.buttons["accessory-Door lock"]; reveal(lock); lock.tap()
        let unlock = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@", "accessoryOption-", "-0")).firstMatch
        reveal(unlock)
        XCTAssertTrue(unlock.label.contains("解锁")); XCTAssertTrue(app.frame.contains(unlock.frame))
        shot("Chinese largest text HomeKit lock opposite landscape")
    }

}
