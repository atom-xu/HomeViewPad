import XCTest
final class HomePadUITests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication(); app.launchArguments = ["--demo", "--uitesting"]; app.launch()
        XCTAssertTrue(app.staticTexts["demoBadge"].waitForExistence(timeout: 10))
    }
    func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func showNavigation() {
        if app.buttons["tab-0"].isHittable { return }
        let point = app.frame.width > app.frame.height ? CGVector(dx: 0.04, dy: 0.5) : CGVector(dx: 0.5, dy: 0.04)
        app.coordinate(withNormalizedOffset: point).tap()
        XCTAssertTrue(app.buttons["tab-0"].waitForExistence(timeout: 3))
    }
    func tab(_ index: Int) { showNavigation(); app.buttons["tab-\(index)"].tap() }
    func panel(_ identifier: String) {
        showNavigation(); app.buttons[identifier].tap()
        XCTAssertTrue(app.buttons["dismissPanel"].waitForExistence(timeout: 3))
    }
    func closePanel() { app.buttons["dismissPanel"].tap() }
    func reveal(_ element: XCUIElement) {
        for _ in 0..<8 { if element.isHittable { return }; app.swipeUp() }
    }
    // A reproducible capture journey using only demo accessories and seeded simulator photos.
    // scripts/record_demo.py records between the READY and DONE markers.
    func testReadmeDemoJourney() {
        app.resetAuthorizationStatus(for: .photos); app.launch()
        app.buttons["photoWidget"].tap()
        XCTAssertTrue(app.buttons["connectPhotos"].waitForExistence(timeout: 5)); app.buttons["connectPhotos"].tap()
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow Full Access"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5)); allow.tap()
        XCTAssertTrue(app.buttons["album-all"].waitForExistence(timeout: 8)); app.buttons["album-all"].tap()
        XCTAssertTrue(app.images["photoPreview"].waitForExistence(timeout: 10)); closePanel()
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil)
        waitForExpectations(timeout: 8)
        print("HOMEVIEWPAD_DEMO_READY")
        Thread.sleep(forTimeInterval: 4)
        app.buttons["temperatureUp"].tap()
        XCTAssertEqual(app.staticTexts["temperatureValue"].label, "22.5")
        Thread.sleep(forTimeInterval: 1)
        app.buttons["temperatureDown"].tap()
        app.buttons["accessory-Pendant lights"].tap()
        Thread.sleep(forTimeInterval: 1)
        app.buttons["accessory-Pendant lights"].tap()
        app.buttons["accessory-Pendant lights"].swipeUp()
        XCTAssertTrue(app.buttons["accessory-Reading lamp"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1)
        app.buttons["accessory-Reading lamp"].swipeDown()
        app.descendants(matching: .any)["climateWidget"].swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["fullClock"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 2)
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 3))
        let wall = app.descendants(matching: .any)["photoWall"]
        shot("README photo wall 1")
        // Capture two real 30-second album transitions without changing app timing.
        for index in 2...3 {
            let previousPhoto = wall.value as? String
            expectation(for: NSPredicate { _, _ in wall.value as? String != previousPhoto }, evaluatedWith: nil)
            waitForExpectations(timeout: 36)
            shot("README photo wall \(index)")
        }
        Thread.sleep(forTimeInterval: 3)
        app.swipeRight(); app.swipeRight()
        showNavigation(); Thread.sleep(forTimeInterval: 2)
        app.buttons["hideNavigation"].tap()
        Thread.sleep(forTimeInterval: 2)
        print("HOMEVIEWPAD_DEMO_DONE")
        shot("README demo dashboard")
    }
    func testDashboardRepeatedControlsAndSceneCancellation() {
        shot("Portrait dashboard")
        let lamp = app.buttons["accessory-Pendant lights"]
        lamp.tap(); XCTAssertTrue(lamp.label.contains("Off")); lamp.tap(); XCTAssertTrue(lamp.label.contains("On"))
        panel("allControls")
        reveal(app.buttons["scene-Good night"])
        app.buttons["scene-Good night"].tap(); app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "accessory-Pendant lights").firstMatch.label.contains("On"))
        app.buttons["scene-Good night"].tap(); app.buttons["Run scene"].tap()
        XCTAssertTrue(app.staticTexts["sceneNotice"].waitForExistence(timeout: 3))
        closePanel()
        XCTAssertTrue(lamp.label.contains("Off"))
    }
    func testImmersiveLandscapeGeometryAndHiddenNavigation() {
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil)
        waitForExpectations(timeout: 8)
        let hero = app.descendants(matching: .any)["climateWidget"]
        let clock = app.descendants(matching: .any)["clockWidget"]
        let photo = app.buttons["photoWidget"]
        let bottom = app.buttons["accessory-Pendant lights"]
        XCTAssertEqual(hero.frame.width, hero.frame.height, accuracy: 2)
        XCTAssertEqual(hero.frame.minY, clock.frame.minY, accuracy: 2)
        XCTAssertEqual(clock.frame.minX, photo.frame.minX, accuracy: 2)
        XCTAssertEqual(hero.frame.maxY, photo.frame.maxY, accuracy: 2)
        XCTAssertLessThan(hero.frame.maxX, clock.frame.minX)
        let scene = app.buttons["scene-Good morning"], fan = app.buttons["accessory-Ceiling fan"]
        XCTAssertEqual(scene.frame.minX, hero.frame.minX, accuracy: 2)
        XCTAssertEqual(scene.frame.minY, fan.frame.minY, accuracy: 2)
        XCTAssertEqual(fan.frame.minY, bottom.frame.minY, accuracy: 2)
        XCTAssertEqual(bottom.frame.minX, photo.frame.minX, accuracy: 2)
        XCTAssertEqual(clock.frame.width, clock.frame.height, accuracy: 2)
        XCTAssertEqual(photo.frame.width, photo.frame.height, accuracy: 2)
        XCTAssertEqual(bottom.frame.width, bottom.frame.height, accuracy: 2)
        XCTAssertGreaterThan(bottom.frame.maxY - hero.frame.minY, app.frame.height * 0.96)
        XCTAssertFalse(app.buttons["tab-0"].exists)
        XCTAssertFalse(app.navigationBars.firstMatch.exists)
        XCTAssertFalse(app.staticTexts["HomeViewPad"].exists)
        shot("Landscape dashboard")
        showNavigation()
        XCTAssertGreaterThan(app.buttons["tab-0"].frame.minX, bottom.frame.maxX)
        shot("Right navigation")
        app.buttons["hideNavigation"].tap()
        XCTAssertFalse(app.buttons["tab-0"].exists)
        // Background taps toggle the rail without toggling an accessory.
        showNavigation(); app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.5)).tap()
        XCTAssertFalse(app.buttons["tab-0"].exists)
        XCTAssertTrue(app.buttons.matching(identifier: "accessory-Pendant lights").firstMatch.label.contains("On"))
    }
    func testPortraitDockMovesToRightOnRotation() {
        XCTAssertFalse(app.descendants(matching: .any)["bottomNavigation"].exists)
        showNavigation()
        XCTAssertTrue(app.descendants(matching: .any)["bottomNavigation"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["sideNavigation"].exists)
        XCTAssertGreaterThan(app.buttons["tab-0"].frame.minY, app.frame.height * 0.8)
        XCTAssertEqual(app.buttons["tab-0"].frame.midY, app.buttons["tab-3"].frame.midY, accuracy: 2)
        shot("Portrait bottom navigation")
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil); waitForExpectations(timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["sideNavigation"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["bottomNavigation"].exists)
        XCTAssertGreaterThan(app.buttons["tab-0"].frame.minX, app.frame.width * 0.8)
        app.buttons["hideNavigation"].tap()
        XCTAssertFalse(app.buttons["tab-0"].exists)
    }
    func testHorizontalPagingAndIndependentWidgetSwipes() {
        let photo = app.buttons["photoWidget"]
        XCTAssertFalse(app.descendants(matching: .any)["widgetPosition-2"].exists)
        photo.swipeUp()
        XCTAssertTrue(app.buttons["cameraWidget"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["climateWidget"].exists)
        XCTAssertFalse(app.buttons["dismissPanel"].exists)
        app.buttons["cameraWidget"].swipeDown()
        XCTAssertTrue(photo.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["dismissPanel"].exists)
        let lamp = app.buttons["accessory-Pendant lights"]
        lamp.swipeUp()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: lamp); waitForExpectations(timeout: 3)
        XCTAssertEqual(app.buttons.matching(identifier: "accessory-Reading lamp").count, 1)
        XCTAssertTrue(app.buttons["accessory-Ceiling fan"].exists)
        app.buttons["accessory-Reading lamp"].swipeDown()
        XCTAssertTrue(lamp.waitForExistence(timeout: 3)); XCTAssertTrue(lamp.label.contains("On"))
        app.descendants(matching: .any)["climateWidget"].swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["fullClock"].waitForExistence(timeout: 3))
        shot("Clock page")
        app.swipeLeft(); XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["chooseWallAlbum"].exists)
        app.swipeLeft(); XCTAssertTrue(app.buttons["Disconnect home"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Start timer"].exists)
        app.swipeRight(); XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 3))
        tab(0); XCTAssertTrue(photo.exists); XCTAssertTrue(lamp.label.contains("On"))
        XCTAssertFalse(app.buttons["tab-0"].exists)
    }
    func testThermostatArrowsAndTransientIndicators() {
        let value = app.staticTexts["temperatureValue"]
        let up = app.buttons["temperatureUp"], down = app.buttons["temperatureDown"]
        XCTAssertEqual(value.label, "22.0")
        up.tap(); XCTAssertEqual(value.label, "22.5")
        down.tap(); XCTAssertEqual(value.label, "22.0")
        let hero = app.descendants(matching: .any)["climateWidget"]
        XCTAssertTrue(hero.frame.contains(value.frame))
        XCTAssertTrue(hero.frame.contains(up.frame)); XCTAssertTrue(hero.frame.contains(down.frame))
        shot("Thermostat complete digits and arrows")
        let position = app.descendants(matching: .any)["widgetPosition-0"]
        XCTAssertFalse(position.exists)
        hero.swipeUp()
        XCTAssertEqual(value.label, "21.5")
        XCTAssertFalse(up.isEnabled); XCTAssertFalse(down.isEnabled)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: position)
        waitForExpectations(timeout: 4)
        XCTAssertTrue(app.buttons["photoWidget"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["clockWidget"].exists)
        hero.swipeDown(); XCTAssertTrue(up.isEnabled)
        XCTAssertEqual(value.label, "22.0")
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(up.waitForExistence(timeout: 5))
        tab(3); XCTAssertTrue(app.buttons["Disconnect home"].waitForExistence(timeout: 3))
        showNavigation(); XCTAssertFalse(app.buttons["tab-4"].exists)
        XCTAssertFalse(app.buttons["Start timer"].exists)
    }
    func testLandscapeCameraAndAgenda() {
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil); waitForExpectations(timeout: 8)
        panel("agendaCard"); XCTAssertTrue(app.staticTexts["17:30 · Water the plants"].exists); closePanel()
        panel("cameraCard"); XCTAssertTrue(app.staticTexts["Demo camera"].waitForExistence(timeout: 5)); shot("Camera placeholder"); closePanel()
        tab(1); shot("Clock landscape")
    }
    func testFailureStatesAndReturnToRealOnboarding() {
        for state in ["denied", "empty", "offline", "loading"] {
            tab(3); reveal(app.buttons["Simulate \(state)"]); app.buttons["Simulate \(state)"].tap()
            XCTAssertTrue(app.staticTexts["homeStateTitle"].waitForExistence(timeout: 3)); XCTAssertTrue(app.staticTexts["demoBadge"].exists); shot("State \(state)")
        }
        tab(3); app.buttons["Disconnect home"].tap()
        XCTAssertTrue(app.buttons["connectHome"].exists); XCTAssertFalse(app.staticTexts["demoBadge"].exists); shot("Real onboarding")
        app.buttons["exploreDemo"].tap(); XCTAssertTrue(app.staticTexts["demoBadge"].exists)
    }
    func testRealConnectionGracefulWithoutDevices() {
        app.terminate(); app.launchArguments = ["--fresh", "--uitesting"]; app.launch()
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
        app.buttons["photoWidget"].tap()
        XCTAssertTrue(app.buttons["singlePhotoPicker"].waitForExistence(timeout: 3))
        app.buttons["singlePhotoPicker"].tap()
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.waitForExistence(timeout: 3) { cancel.tap() } else { app.swipeDown() }
        closePanel()
        panel("musicCard"); app.buttons["Choose audio file"].tap()
        XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 5)); shot("Audio file picker"); app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Choose audio file"].waitForExistence(timeout: 5))
        closePanel(); tab(0); XCTAssertTrue(app.buttons["photoWidget"].exists)
    }
    func testPhotoLibraryDenialKeepsSinglePhotoAvailable() {
        app.resetAuthorizationStatus(for: .photos)
        app.launch() // Resetting an existing Photos grant terminates the app.
        app.buttons["photoWidget"].tap()
        XCTAssertTrue(app.buttons["connectPhotos"].waitForExistence(timeout: 5)); app.buttons["connectPhotos"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Allow")).matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Don")).firstMatch
        XCTAssertTrue(deny.waitForExistence(timeout: 5)); deny.tap()
        XCTAssertTrue(app.staticTexts["photosDenied"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["singlePhotoPicker"].exists); shot("Photo permission denied")
        closePanel(); XCTAssertTrue(app.buttons["photoWidget"].exists)
    }
    func testPhotoLibraryAlbumDisplayRotationRestoreAndRemoval() {
        app.launchArguments += ["-photoSlideshow", "YES"]
        app.resetAuthorizationStatus(for: .photos)
        app.launch()
        app.buttons["photoWidget"].tap()
        XCTAssertTrue(app.buttons["connectPhotos"].waitForExistence(timeout: 5)); app.buttons["connectPhotos"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow Full Access"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5)); allow.tap()
        let album = app.buttons["album-all"]
        XCTAssertTrue(album.waitForExistence(timeout: 8)); album.tap()
        XCTAssertTrue(app.images["photoPreview"].waitForExistence(timeout: 10))
        shot("Photo album selection")
        let position = app.staticTexts["photoPosition"]
        reveal(position); let initial = position.label
        XCTAssertTrue(app.buttons["nextPhoto"].isEnabled); app.buttons["nextPhoto"].tap()
        expectation(for: NSPredicate { _, _ in position.label != initial }, evaluatedWith: nil); waitForExpectations(timeout: 5)
        closePanel(); shot("Dashboard with library photo")
        tab(2)
        let wall = app.descendants(matching: .any)["photoWall"]
        XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["chooseWallAlbum"].exists)
        XCTAssertEqual(wall.frame.width, app.frame.width, accuracy: 2)
        XCTAssertEqual(wall.frame.height, app.frame.height, accuracy: 2)
        shot("Photo wall portrait")
        let firstPhoto = wall.value as? String
        expectation(for: NSPredicate { _, _ in wall.value as? String != firstPhoto }, evaluatedWith: nil)
        waitForExpectations(timeout: 36) // Actual 30-second slideshow, no shortened test timer.
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate { _, _ in self.app.frame.width > self.app.frame.height }, evaluatedWith: nil); waitForExpectations(timeout: 8)
        XCTAssertEqual(wall.frame.width, app.frame.width, accuracy: 2)
        XCTAssertEqual(wall.frame.height, app.frame.height, accuracy: 2)
        shot("Photo wall landscape")
        showNavigation(); XCTAssertTrue(app.descendants(matching: .any)["sideNavigation"].exists)
        app.buttons["hideNavigation"].tap()
        app.swipeLeft(); XCTAssertTrue(app.buttons["Disconnect home"].waitForExistence(timeout: 3))
        app.swipeRight(); XCTAssertTrue(app.staticTexts["photoWallClock"].waitForExistence(timeout: 3))
        app.terminate(); app.launch()
        app.buttons["photoWidget"].tap()
        XCTAssertTrue(app.images["photoPreview"].waitForExistence(timeout: 10))
        // Revoking permission must not restore the cached album image on relaunch.
        app.resetAuthorizationStatus(for: .photos); app.launch()
        app.buttons["photoWidget"].tap()
        XCTAssertTrue(app.buttons["connectPhotos"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["photoPreview"].exists)
        XCTAssertTrue(app.staticTexts["photoMessage"].exists)
        let clear = app.buttons["clearPhotos"]; reveal(clear); clear.tap()
        XCTAssertFalse(app.images["photoPreview"].exists); XCTAssertFalse(app.staticTexts["photoPosition"].exists)
        closePanel(); XCTAssertTrue(app.buttons["photoWidget"].exists)
    }
    func testRoomFilteringCanBeRepeated() {
        panel("allControls")
        app.buttons["room-Kitchen"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "accessory-Pendant lights").firstMatch.exists); XCTAssertFalse(app.buttons.matching(identifier: "accessory-Reading lamp").firstMatch.exists)
        app.buttons["room-All rooms"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "accessory-Reading lamp").firstMatch.exists); closePanel()
        XCTAssertTrue(app.buttons.matching(identifier: "accessory-Pendant lights").firstMatch.exists)
    }
    func testLargeTextLayout() {
        app.terminate(); app.launchArguments = ["--demo", "--uitesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]; app.launch()
        XCTAssertTrue(app.staticTexts["demoBadge"].waitForExistence(timeout: 5)); shot("Accessibility large text")
        reveal(app.buttons["photoWidget"]); XCTAssertTrue(app.buttons["photoWidget"].isHittable)
        tab(3); XCTAssertTrue(app.buttons["Disconnect home"].exists)
    }
    func testGlassThemePersistsAfterNavigation() {
        tab(3)
        let teal = app.switches["tealWallpaper"]
        if teal.switches.firstMatch.exists { teal.switches.firstMatch.tap() } else { teal.tap() }
        XCTAssertEqual(teal.value as? String, "1")
        tab(0); shot("Teal dashboard")
        tab(3); XCTAssertEqual(app.switches["tealWallpaper"].value as? String, "1")
        tab(0); XCTAssertTrue(app.descendants(matching: .any)["climateWidget"].exists)
    }
}
