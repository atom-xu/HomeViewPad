import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
import CryptoKit
@testable import HomePad

final class WallpaperStoreTests: XCTestCase {
    @MainActor func testImportSavesJPEGAndRestoresStableIdentityThenDeletesOnlyWallpaper() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "wallpaper.jpg")
        let unrelated = directory.appending(path: "photo-wall.jpg")
        let unrelatedData = Data("separate photo-page content".utf8)
        try unrelatedData.write(to: unrelated)
        let store = WallpaperStore(fileURL: file)
        let source = try picture(width: 800, height: 450, color: .systemTeal)

        await store.importImage { source }

        let displayed = try XCTUnwrap(store.image)
        XCTAssertEqual(displayed.size, CGSize(width: 800, height: 450))
        XCTAssertFalse(store.loading)
        XCTAssertNil(store.message)
        let saved = try Data(contentsOf: file)
        XCTAssertEqual(Array(saved.prefix(3)), [0xff, 0xd8, 0xff], "Persist an actual JPEG, regardless of the picked source format")
        let savedSource = try XCTUnwrap(CGImageSourceCreateWithData(saved as CFData, nil))
        XCTAssertEqual(CGImageSourceGetType(savedSource) as String?, UTType.jpeg.identifier)
        let identifier = SHA256.hash(data: saved).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(store.imageID, identifier)

        let reopened = WallpaperStore(fileURL: file)
        await reopened.restore()
        XCTAssertEqual(reopened.imageID, identifier)
        XCTAssertEqual(reopened.image?.size, displayed.size)
        XCTAssertEqual(try Data(contentsOf: file), saved, "Restarting must not re-encode or change the wallpaper's identity")

        reopened.clear()
        XCTAssertNil(reopened.image)
        XCTAssertEqual(reopened.imageID, "")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(try Data(contentsOf: unrelated), unrelatedData)
        let afterRemoval = WallpaperStore(fileURL: file)
        await afterRemoval.restore()
        XCTAssertNil(afterRemoval.image)
        XCTAssertEqual(afterRemoval.imageID, "")
    }

    @MainActor func testLargeEXIFRotatedSourceIsUprightPortraitAndBoundedTo3072Pixels() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "wallpaper.jpg")
        // Stored pixels are landscape; EXIF 6 means the visible photo is portrait.
        let source = try picture(width: 4000, height: 2000, color: .systemOrange, orientation: 6)
        let store = WallpaperStore(fileURL: file)
        await store.importImage { source }
        let image = try XCTUnwrap(store.image)
        XCTAssertEqual(image.imageOrientation, .up)
        XCTAssertEqual(image.size.width, 1536)
        XCTAssertEqual(image.size.height, 3072)
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 3072)
        let reopened = WallpaperStore(fileURL: file)
        await reopened.restore()
        XCTAssertEqual(reopened.image?.size, image.size)
        XCTAssertEqual(reopened.image?.imageOrientation, .up)
        XCTAssertEqual(reopened.imageID, store.imageID)
    }

    @MainActor func testBadMissingAndFailedLoadsPreserveTheLastSavedWallpaper() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "wallpaper.jpg")
        let store = WallpaperStore(fileURL: file)
        let baseline = try picture(width: 640, height: 360, color: .systemBlue)
        await store.importImage { baseline }
        let identifier = store.imageID
        let saved = try Data(contentsOf: file)

        await store.importImage { Data("not an image".utf8) }
        XCTAssertEqual(store.imageID, identifier)
        XCTAssertEqual(store.image?.size, CGSize(width: 640, height: 360))
        XCTAssertEqual(try Data(contentsOf: file), saved)
        XCTAssertFalse(store.loading)
        XCTAssertNotNil(store.message)

        await store.importImage { nil }
        XCTAssertEqual(store.imageID, identifier)
        XCTAssertEqual(try Data(contentsOf: file), saved)
        XCTAssertFalse(store.loading)
        XCTAssertNotNil(store.message)

        await store.importImage { throw CocoaError(.fileReadUnknown) }
        XCTAssertEqual(store.imageID, identifier)
        XCTAssertEqual(try Data(contentsOf: file), saved)
        XCTAssertFalse(store.loading)
        XCTAssertNotNil(store.message)

        try FileManager.default.removeItem(at: file)
        await store.restore()
        XCTAssertEqual(store.imageID, identifier, "A failed restore read must not clear an already displayed image")
        try Data("corrupt saved wallpaper".utf8).write(to: file)
        await store.restore()
        XCTAssertEqual(store.imageID, identifier, "A corrupt restore must not clear an already displayed image")
    }

    @MainActor func testSaveFailureKeepsThePreviousDisplayedWallpaper() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "wallpaper.jpg")
        let backup = directory.appending(path: "previous.jpg")
        let store = WallpaperStore(fileURL: file)
        await store.importImage { try picture(width: 600, height: 400, color: .systemPurple) }
        let identifier = store.imageID
        let saved = try Data(contentsOf: file)
        // A directory at the destination reliably rejects the atomic file write,
        // without depending on simulator/root-user filesystem permission rules.
        try FileManager.default.moveItem(at: file, to: backup)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)

        await store.importImage { try picture(width: 900, height: 500, color: .systemRed) }

        XCTAssertEqual(store.imageID, identifier)
        XCTAssertEqual(store.image?.size, CGSize(width: 600, height: 400))
        XCTAssertEqual(try Data(contentsOf: backup), saved)
        XCTAssertFalse(store.loading)
        XCTAssertNotNil(store.message)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.moveItem(at: backup, to: file)
        let reopened = WallpaperStore(fileURL: file)
        await reopened.restore()
        XCTAssertEqual(reopened.imageID, identifier)
    }

    @MainActor func testLateSelectionCannotOverwriteANewerSavedSelection() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "wallpaper.jpg")
        let store = WallpaperStore(fileURL: file)
        let older = try picture(width: 400, height: 300, color: .systemRed)
        let newer = try picture(width: 700, height: 400, color: .systemGreen)
        let started = expectation(description: "older load is suspended")
        let gate = WallpaperLoadGate(started: started)
        let oldTask = Task { await store.importImage { try await gate.load() } }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(store.loading)

        await store.importImage { newer }
        let currentID = store.imageID
        let currentFile = try Data(contentsOf: file)
        gate.finish(older)
        await oldTask.value

        XCTAssertEqual(store.imageID, currentID)
        XCTAssertEqual(store.image?.size, CGSize(width: 700, height: 400))
        XCTAssertEqual(try Data(contentsOf: file), currentFile)
        XCTAssertFalse(store.loading)
        XCTAssertNil(store.message)
    }

    @MainActor func testClearInvalidatesAnInFlightSelectionSoItCannotResurrectWallpaper() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "wallpaper.jpg")
        let store = WallpaperStore(fileURL: file)
        let source = try picture(width: 500, height: 300, color: .systemIndigo)
        await store.importImage { source }
        let started = expectation(description: "replacement load is suspended")
        let gate = WallpaperLoadGate(started: started)
        let pending = Task { await store.importImage { try await gate.load() } }
        await fulfillment(of: [started], timeout: 2)

        store.clear()
        gate.finish(source)
        await pending.value

        XCTAssertNil(store.image)
        XCTAssertEqual(store.imageID, "")
        XCTAssertFalse(store.loading)
        XCTAssertNil(store.message)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        let reopened = WallpaperStore(fileURL: file)
        await reopened.restore()
        XCTAssertNil(reopened.image)
    }

    @MainActor func testCancelledImportNeverWritesOrReplacesThePreviousWallpaper() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "wallpaper.jpg")
        let store = WallpaperStore(fileURL: file)
        await store.importImage { try picture(width: 400, height: 250, color: .systemCyan) }
        let identifier = store.imageID
        let saved = try Data(contentsOf: file)
        let replacement = try picture(width: 800, height: 500, color: .systemYellow)
        let started = expectation(description: "cancelled load is suspended")
        let gate = WallpaperLoadGate(started: started)
        let pending = Task { await store.importImage { try await gate.load() } }
        await fulfillment(of: [started], timeout: 2)
        pending.cancel()
        // The loader deliberately ignores cancellation, like a late picker
        // response. The store itself must refuse to decode/save its result.
        gate.finish(replacement)
        await pending.value
        XCTAssertEqual(store.imageID, identifier)
        XCTAssertEqual(store.image?.size, CGSize(width: 400, height: 250))
        XCTAssertEqual(try Data(contentsOf: file), saved)
        XCTAssertFalse(store.loading)
        XCTAssertNil(store.message)
    }

    func testAppBundleSupportsBothLandscapeDirectionsAndRequiresFullScreen() throws {
        let expected: Set<String> = ["UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]
        for key in ["UISupportedInterfaceOrientations", "UISupportedInterfaceOrientations~ipad"] {
            let orientations = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: key) as? [String], key)
            XCTAssertEqual(Set(orientations), expected, "Both iPad landscape orientations must be available, with no portrait fallback")
            XCTAssertEqual(orientations.count, expected.count)
        }
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "UIRequiresFullScreen") as? Bool, true)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "WallpaperStoreTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @MainActor private func picture(width: Int, height: Int, color: UIColor, orientation: Int = 1) throws -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let size = CGSize(width: CGFloat(width), height: CGFloat(height))
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill(); context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: size.width / 4, height: size.height / 4))
        }
        let image = try XCTUnwrap(rendered.cgImage)
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}

@MainActor private final class WallpaperLoadGate {
    private let started: XCTestExpectation
    private var continuation: CheckedContinuation<Data?, Error>?
    init(started: XCTestExpectation) { self.started = started }
    func load() async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            started.fulfill()
        }
    }
    func finish(_ data: Data) {
        continuation?.resume(returning: data)
        continuation = nil
    }
}
