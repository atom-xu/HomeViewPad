import XCTest
import UIKit

extension HomePadUITests {
    func chooseBackgroundSource(_ source: String, towardTop: Bool = false) {
        if !app.descendants(matching: .any)["settingsWallpaperPage"].exists {
            let entry = app.buttons["settingsWallpaper"]
            reveal(entry, towardTop: true); XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
            XCTAssertTrue(app.descendants(matching: .any)["settingsWallpaperPage"].waitForExistence(timeout: 5))
        }
        let target = app.buttons[source == "photo" ? "chooseWallpaper" : source == "aerial" ? "aerialShuffle" : "wallpaperDefault-warmGray"]
        let up = target.exists ? target.frame.midY < app.frame.midY : towardTop
        reveal(target, towardTop: up)
        if !target.isHittable { reveal(target, towardTop: !up) }
        XCTAssertTrue(target.waitForExistence(timeout: 5))
    }

    func leaveWallpaperGallery() {
        if app.descendants(matching: .any)["settingsWallpaperPage"].exists {
            let back = app.navigationBars.buttons.matching(NSPredicate(format: "identifier != %@", "showNavigationButton")).firstMatch
            XCTAssertTrue(back.exists); back.tap()
            XCTAssertTrue(app.descendants(matching: .any)["settingsDisplayPage"].waitForExistence(timeout: 5))
        }
    }

    func testWallpaperGalleryHasThumbnailCardsAndCompactCurrentPreview() {
        tab(4); settingsCategory("settingsDisplay"); chooseBackgroundSource("colors")
        let warm = app.buttons["wallpaperDefault-warmGray"], teal = app.buttons["wallpaperDefault-teal"]
        XCTAssertLessThan(warm.frame.width, app.frame.width * 0.4, "A wallpaper choice is a thumbnail card, not a full-width strip")
        XCTAssertEqual(warm.frame.width, teal.frame.width, accuracy: 2)
        XCTAssertEqual(warm.frame.minY, teal.frame.minY, accuracy: 2)
        XCTAssertGreaterThan(warm.frame.height, warm.frame.width * 0.55)
        let preview = app.descendants(matching: .any)["backgroundPreview"]
        reveal(preview, towardTop: true)
        shot("Mac style wallpaper gallery compact preview and photo color thumbnails")
        let geometry = XCTAttachment(string: "app=\(app.frame) preview=\(preview.frame) warm=\(warm.frame) teal=\(teal.frame)")
        geometry.name = "Wallpaper gallery geometry"; geometry.lifetime = .keepAlways; add(geometry)
        XCTAssertLessThanOrEqual(preview.frame.width, 360)
        XCTAssertEqual(preview.frame.width / preview.frame.height, 1.6, accuracy: 0.03)
        XCTAssertFalse(app.segmentedControls["backgroundSource"].exists)
        chooseBackgroundSource("aerial")
        reveal(app.buttons["aerial-12E0343D-2CD9-48EA-AB57-4D680FB6D0C7"])
        shot("Mac style Apple aerial gallery fixed ratio thumbnail cards")
        leaveWallpaperGallery()
        XCTAssertTrue(app.buttons["settingsWallpaper"].exists)
    }

    func launchAerialFixture(extra: [String] = []) {
        app.terminate()
        if let index = app.launchArguments.firstIndex(of: "-background.aerialSelectionV1") { app.launchArguments.removeSubrange(index...index + 1) }
        app.launchArguments += ["--aerial-fixture", "--aerial-fixture-reset", "-display.screenBehaviorV1", "followSystem"] + extra
        launchHome(); tab(4); settingsCategory("settingsDisplay"); chooseBackgroundSource("aerial")
    }

    func selectAerial(_ id: String, timeout: TimeInterval = 15) {
        let tile = app.buttons["aerial-" + id]
        reveal(tile); XCTAssertTrue(tile.waitForExistence(timeout: 5)); tile.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard tile.exists else { return false }
            return tile.isSelected && ["Selected", "已选择"].contains(tile.value as? String ?? "")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: timeout), .completed)
        XCTAssertFalse(app.staticTexts["aerialError"].exists)
    }

    func testAerialGallerySelectionShufflePersistenceAndSharedStandbyBackground() {
        let hawaii = "12E0343D-2CD9-48EA-AB57-4D680FB6D0C7"
        let patagonia = "25A6CFB2-3570-4448-B114-244A4E454B7A"
        launchAerialFixture()
        XCTAssertFalse(app.buttons["aerialShuffle"].isEnabled)
        selectAerial(hawaii)
        selectAerial(patagonia)
        let shuffle = app.buttons["aerialShuffle"]
        reveal(shuffle, towardTop: true); shuffle.tap(); XCTAssertTrue(shuffle.isSelected)
        let interval = app.buttons["aerialShuffleInterval"]
        reveal(interval); interval.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.buttons["1 minute"].tap()
        shot("Aerial unified gallery with downloaded synthetic clips and shuffle")
        app.launchArguments.removeAll { $0 == "--aerial-fixture-reset" }
        app.terminate(); launchHome()
        let background = app.descendants(matching: .any)["aerialWallpaper"]
        XCTAssertTrue(background.waitForExistence(timeout: 5)); assertFillsViewport(background)
        XCTAssertTrue((background.value as? String ?? "").contains("Patagonia"))
        shot("Home synthetic aerial background restored with visible test label")
        tab(2); assertFillsViewport(background)
        shot("Clock synthetic aerial background shared with Home")
        tab(4); settingsCategory("settingsDisplay")
        chooseBackgroundSource("aerial")
        reveal(shuffle); XCTAssertTrue(shuffle.isSelected)
        reveal(interval)
        XCTAssertTrue((interval.value as? String ?? "").contains("1 minute"))
        let preview = app.buttons["standbyPreview"]
        reveal(preview, towardTop: true); preview.tap()
        let standby = app.descendants(matching: .any)["standbyDisplay"]
        XCTAssertTrue(standby.waitForExistence(timeout: 5)); assertFillsViewport(standby)
        XCTAssertTrue(background.exists)
        shot("Clock standby over the same synthetic aerial background")
        assertSyntheticAerialInStandbyCorners()
        app.buttons["standbyWake"].tap()
        XCTAssertTrue(standby.waitForNonExistence(timeout: 5))
        chooseBackgroundSource("colors")
        let teal = app.buttons["wallpaperDefault-teal"]
        reveal(teal); teal.tap(); XCTAssertTrue(teal.isSelected)
        tab(1); XCTAssertFalse(background.exists)
    }

    func testAerialCancelAndFailureRetainStaticBackground() {
        launchAerialFixture(extra: ["--aerial-fixture-slow"])
        let first = app.buttons["aerial-12E0343D-2CD9-48EA-AB57-4D680FB6D0C7"]
        reveal(first); first.tap()
        let cancel = app.buttons["aerialCancelDownload"]
        reveal(cancel, towardTop: true); XCTAssertTrue(cancel.waitForExistence(timeout: 5)); cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        XCTAssertFalse(first.isSelected)
        tab(1); XCTAssertFalse(app.descendants(matching: .any)["aerialWallpaper"].exists)

        app.launchArguments.removeAll { $0 == "--aerial-fixture-slow" }
        app.launchArguments += ["--aerial-fixture-failure"]
        app.terminate(); launchHome(); tab(4); settingsCategory("settingsDisplay"); chooseBackgroundSource("aerial")
        reveal(first); first.tap()
        let error = app.staticTexts["aerialError"]
        reveal(error, towardTop: true)
        XCTAssertTrue(error.waitForExistence(timeout: 10)); XCTAssertTrue(error.label.contains("previous background is unchanged"))
        shot("Aerial network failure preserves the prior background")
        tab(1); XCTAssertFalse(app.descendants(matching: .any)["aerialWallpaper"].exists)
    }

    func testAerialChineseLargestTextAndLandscapeDirections() {
        launchAerialFixture(extra: ["-appLanguage", "zh-Hans", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let first = app.buttons["aerial-12E0343D-2CD9-48EA-AB57-4D680FB6D0C7"]
        selectAerial("12E0343D-2CD9-48EA-AB57-4D680FB6D0C7")
        XCTAssertEqual(first.label, "夏威夷")
        XCTAssertGreaterThanOrEqual(first.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(first.frame.maxX, app.frame.maxX)
        shot("Chinese largest-text aerial gallery")
        XCUIDevice.shared.orientation = .landscapeRight; waitForLandscape()
        reveal(first); XCTAssertTrue(first.isHittable)
        shot("Chinese largest-text aerial gallery opposite landscape")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertGreaterThan(app.frame.width, app.frame.height, "The current project declares landscape orientations only")
        XCUIDevice.shared.orientation = .landscapeRight
        waitForLandscape()
        chooseBackgroundSource("photo", towardTop: true)
        let choose = app.buttons["chooseWallpaper"]
        reveal(choose); XCTAssertTrue(choose.isHittable)
        chooseBackgroundSource("colors", towardTop: true)
        let warm = app.buttons["wallpaperDefault-warmGray"]
        reveal(warm); XCTAssertTrue(warm.isHittable)
        shot("Chinese unified background photo and color choices remain accessible")
    }

    func assertSyntheticAerialInStandbyCorners() {
        guard let source = XCUIScreen.main.screenshot().image.cgImage else { XCTFail("A screen image is required"); return }
        var pixels = [UInt8](repeating: 0, count: 64 * 64 * 4)
        guard let context = CGContext(data: &pixels, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 64 * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            XCTFail("A screenshot context is required"); return
        }
        context.draw(source, in: CGRect(x: 0, y: 0, width: 64, height: 64))
        for (x, y) in [(3, 3), (60, 3), (3, 60), (60, 60)] {
            let offset = (y * 64 + x) * 4
            XCTAssertGreaterThan(Int(pixels[offset + 1]) - Int(pixels[offset]), 12,
                                 "Standby must show the teal synthetic movie, rather than the opaque Settings page underneath")
        }
    }

    func testAppleOfficialAerialDownloadAndActualSimulatorPlayback() {
        // This is an integration test against Apple's real CDN, separate from
        // deterministic fixtures and from physical-device or HomeKit acceptance.
        app.terminate()
        app.launchArguments += ["-display.screenBehaviorV1", "followSystem", "-musicArtworkBackground", "NO"]
        launchHome(); tab(4); settingsCategory("settingsDisplay"); chooseBackgroundSource("aerial")
        selectAerial("12E0343D-2CD9-48EA-AB57-4D680FB6D0C7", timeout: 240)
        shot("Apple official Hawaii aerial downloaded in the unified gallery")
        tab(1)
        let background = app.descendants(matching: .any)["aerialWallpaper"]
        XCTAssertTrue(background.waitForExistence(timeout: 10)); assertFillsViewport(background)
        let playing = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (background.value as? String ?? "").contains("Playing")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [playing], timeout: 20), .completed)
        shot("Apple official Hawaii aerial playing behind Home")
        tab(2); assertFillsViewport(background)
        shot("Apple official Hawaii aerial playing behind Clock")
        tab(4); settingsCategory("settingsDisplay")
        let preview = app.buttons["standbyPreview"]
        reveal(preview); preview.tap()
        XCTAssertTrue(app.descendants(matching: .any)["standbyDisplay"].waitForExistence(timeout: 5))
        XCTAssertTrue(background.exists)
        shot("Apple official Hawaii aerial visible behind clock standby")
        app.buttons["standbyWake"].tap()
        chooseBackgroundSource("colors")
        let warm = app.buttons["wallpaperDefault-warmGray"]
        reveal(warm); warm.tap()
        tab(1); XCTAssertFalse(background.exists)
    }
}
