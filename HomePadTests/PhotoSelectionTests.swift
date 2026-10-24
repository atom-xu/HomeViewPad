import XCTest
import UIKit
import Photos
@testable import HomePad

final class PhotoSelectionTests: XCTestCase {
    @MainActor func testAsyncLibraryQueryRejectsOlderSelectionAndClear() async throws {
        let fixture = try PhotoFixture(); defer { fixture.remove() }
        let gate = LibraryQueryGate()
        let store = PhotoLibraryStore(defaults: fixture.defaults, fileURL: fixture.directory.appending(path: "photo.jpg"), query: gate.client)
        let a = PhotoAlbum(id: "a", title: "Album A", count: 1), b = PhotoAlbum(id: "b", title: "Album B", count: 2)
        store.refresh()
        await gate.waitForRequests(1)
        XCTAssertTrue(store.libraryLoading, "The main actor remains available while the album query waits")
        gate.finish(0, albums: [a, b]); await gate.drain()
        XCTAssertEqual(store.albums, [a, b])
        store.select(a); await gate.waitForRequests(2)
        store.select(b); await gate.waitForRequests(3)
        gate.finish(2, albums: [a, b]); await gate.drain()
        XCTAssertEqual(store.selectedAlbumID, b.id); XCTAssertEqual(store.albumTitle, b.title)
        gate.finish(1, albums: [a]); await gate.drain()
        XCTAssertEqual(store.selectedAlbumID, b.id); XCTAssertEqual(store.albums, [a, b])
        store.refresh(); await gate.waitForRequests(4)
        store.clear(); gate.finish(3, albums: [a]); await gate.drain()
        XCTAssertNil(store.selectedAlbumID); XCTAssertTrue(store.albums.isEmpty)
        XCTAssertFalse(store.libraryLoading)
    }

    @MainActor func testAsyncLibraryQueryRechecksPermissionAndCannotReturnAfterBackground() async throws {
        let fixture = try PhotoFixture(); defer { fixture.remove() }
        let gate = LibraryQueryGate()
        let store = PhotoLibraryStore(defaults: fixture.defaults, fileURL: fixture.directory.appending(path: "photo.jpg"), query: gate.client)
        let privateAlbum = PhotoAlbum(id: "private", title: "Private album", count: 1)
        store.refresh(); await gate.waitForRequests(1)
        gate.finish(0, albums: [privateAlbum]); await gate.drain()
        XCTAssertEqual(store.albums, [privateAlbum])
        gate.status = .limited; store.refresh(); await gate.waitForRequests(2)
        XCTAssertTrue(store.albums.isEmpty, "Full-access album names disappear before a limited-access query completes")
        gate.status = .denied
        gate.finish(1, albums: [privateAlbum]); await gate.drain()
        XCTAssertEqual(store.authorization, .denied); XCTAssertTrue(store.albums.isEmpty)
        XCTAssertFalse(store.libraryLoading)
        gate.status = .authorized; store.refresh(); await gate.waitForRequests(3)
        store.setActive(false); gate.finish(2, albums: [privateAlbum]); await gate.drain()
        XCTAssertTrue(store.albums.isEmpty, "A late query cannot repopulate data after backgrounding")
        XCTAssertFalse(store.libraryLoading)
    }
    @MainActor func testMultiplePickedPhotosPersistInOrderAndRotateWithoutTouchingWallpaperOrOriginals() async throws {
        let fixture = try PhotoFixture()
        defer { fixture.remove() }
        let originals = [try picture(width: 800, height: 450, color: .systemTeal), try picture(width: 450, height: 800, color: .systemOrange), try picture(width: 700, height: 500, color: .systemIndigo)]
        let unrelated = fixture.directory.appending(path: "background-wallpaper.jpg")
        try Data("separate wallpaper".utf8).write(to: unrelated)
        let original = fixture.directory.appending(path: "original.jpg")
        try originals[0].write(to: original)
        let store = fixture.store()
        await store.importImages(originals.map { bytes in { bytes } })

        XCTAssertNil(store.selectedAlbumID)
        XCTAssertEqual(store.photoCount, 3)
        XCTAssertEqual(store.position, 0)
        XCTAssertEqual(store.wallFrames.map(\.image.size), [CGSize(width: 800, height: 450), CGSize(width: 450, height: 800), CGSize(width: 700, height: 500)])
        XCTAssertEqual(Set(store.wallFrames.map(\.id)).count, 3)
        XCTAssertFalse(store.loading)
        XCTAssertNil(store.message)
        XCTAssertEqual(try Data(contentsOf: unrelated), Data("separate wallpaper".utf8))
        XCTAssertEqual(try Data(contentsOf: original), originals[0])

        let reopened = fixture.store(); reopened.restore()
        XCTAssertEqual(reopened.photoCount, 3)
        XCTAssertEqual(reopened.wallFrames.map(\.image.size), store.wallFrames.map(\.image.size))
        reopened.next()
        XCTAssertEqual(reopened.position, 1)
        XCTAssertEqual(reopened.image?.size, CGSize(width: 450, height: 800))
        XCTAssertEqual(reopened.wallFrames.map(\.image.size), [CGSize(width: 450, height: 800), CGSize(width: 700, height: 500), CGSize(width: 800, height: 450)])

        reopened.clear()
        let afterClear = fixture.store(); afterClear.restore()
        XCTAssertNil(afterClear.image)
        XCTAssertTrue(afterClear.wallFrames.isEmpty)
        XCTAssertEqual(afterClear.photoCount, 0)
        XCTAssertEqual(try Data(contentsOf: original), originals[0])
        XCTAssertEqual(try Data(contentsOf: unrelated), Data("separate wallpaper".utf8))
    }

    @MainActor func testBadPhotoInReplacementKeepsTheEntirePreviousSelectionAfterRestart() async throws {
        let fixture = try PhotoFixture(); defer { fixture.remove() }
        let store = fixture.store()
        await store.importImages([{ try self.picture(width: 700, height: 400, color: .systemBlue) }, { try self.picture(width: 400, height: 700, color: .systemRed) }])
        let previousIDs = store.wallFrames.map(\.id)
        await store.importImages([{ try self.picture(width: 900, height: 450, color: .systemGreen) }, { Data("bad photo".utf8) }])
        XCTAssertEqual(store.wallFrames.map(\.id), previousIDs)
        XCTAssertEqual(store.photoCount, 2)
        XCTAssertEqual(store.image?.size, CGSize(width: 700, height: 400))
        XCTAssertFalse(store.loading)
        XCTAssertNotNil(store.message)
        let reopened = fixture.store(); reopened.restore()
        XCTAssertEqual(reopened.wallFrames.map(\.image.size), [CGSize(width: 700, height: 400), CGSize(width: 400, height: 700)])
        // No half-imported replacement is left alongside the saved selection.
        let copiedImages = try FileManager.default.contentsOfDirectory(at: fixture.directory.appending(path: "ambient-photos"), includingPropertiesForKeys: nil).filter { $0.pathExtension == "jpg" }
        XCTAssertEqual(copiedImages.count, 2)
    }

    @MainActor func testCancelAndBackgroundRefuseLatePickerResultsAndKeepSavedPhotos() async throws {
        for cancelByBackground in [false, true] {
            let fixture = try PhotoFixture(); defer { fixture.remove() }
            let store = fixture.store()
            await store.importImages([{ try self.picture(width: 600, height: 400, color: .systemTeal) }])
            let previousID = store.frame?.id
            let started = expectation(description: "picker is downloading")
            let gate = PhotoSelectionGate(started: started)
            let pending = Task { await store.importImages([{ try await gate.load() }]) }
            await fulfillment(of: [started], timeout: 2)
            XCTAssertTrue(store.loading)
            if cancelByBackground { store.setActive(false) } else { pending.cancel() }
            gate.finish(try picture(width: 1000, height: 500, color: .systemPink))
            await pending.value
            XCTAssertEqual(store.frame?.id, previousID)
            XCTAssertFalse(store.loading)
            XCTAssertNil(store.message)
            let reopened = fixture.store(); reopened.restore()
            XCTAssertEqual(reopened.image?.size, CGSize(width: 600, height: 400))
        }
    }

    @MainActor func testClearWhileDownloadingDoesNotResurrectAnyPhoto() async throws {
        let fixture = try PhotoFixture(); defer { fixture.remove() }
        let store = fixture.store()
        await store.importImages([{ try self.picture(width: 600, height: 400, color: .systemTeal) }])
        let started = expectation(description: "picker is downloading")
        let gate = PhotoSelectionGate(started: started)
        let pending = Task { await store.importImages([{ try await gate.load() }]) }
        await fulfillment(of: [started], timeout: 2)
        store.clear()
        gate.finish(try picture(width: 1000, height: 500, color: .systemPink))
        await pending.value
        XCTAssertNil(store.image)
        XCTAssertTrue(store.wallFrames.isEmpty)
        XCTAssertEqual(store.photoCount, 0)
        XCTAssertFalse(store.loading)
        XCTAssertNil(store.message)
        let reopened = fixture.store(); reopened.restore()
        XCTAssertNil(reopened.image)
        XCTAssertEqual(reopened.photoCount, 0)
    }

    @MainActor func testNewSelectionWinsOverAnOlderDownloadEvenWhenOlderLoaderIgnoresCancellation() async throws {
        let fixture = try PhotoFixture(); defer { fixture.remove() }
        let store = fixture.store()
        let started = expectation(description: "old picker is downloading")
        let gate = PhotoSelectionGate(started: started)
        let old = Task { await store.importImages([{ try await gate.load() }]) }
        await fulfillment(of: [started], timeout: 2)
        await store.importImages([{ try self.picture(width: 750, height: 450, color: .systemBlue) }, { try self.picture(width: 450, height: 750, color: .systemOrange) }])
        let currentIDs = store.wallFrames.map(\.id)
        gate.finish(try picture(width: 1000, height: 500, color: .systemPink))
        await old.value
        XCTAssertEqual(store.wallFrames.map(\.id), currentIDs)
        XCTAssertEqual(store.photoCount, 2)
        let reopened = fixture.store(); reopened.restore()
        XCTAssertEqual(reopened.image?.size, CGSize(width: 750, height: 450))
        XCTAssertEqual(reopened.photoCount, 2)
    }

    @MainActor func testLayoutPreferencePersistsAndSinglePhotoDoesNotDuplicateWallSlots() async throws {
        let fixture = try PhotoFixture(); defer { fixture.remove() }
        let store = fixture.store()
        await store.importImages([{ try self.picture(width: 650, height: 400, color: .systemBlue) }, { try self.picture(width: 400, height: 650, color: .systemOrange) }])
        XCTAssertEqual(store.wallFrames.count, 2)
        store.wallStyle = .single
        XCTAssertEqual(store.wallFrames.count, 1)
        XCTAssertEqual(store.photoCount, 2)
        let reopened = fixture.store(); reopened.restore()
        XCTAssertEqual(reopened.wallStyle, .single)
        XCTAssertEqual(reopened.wallFrames.count, 1)
        reopened.wallStyle = .wall
        XCTAssertEqual(reopened.wallFrames.count, 2)
        XCTAssertEqual(PhotoLibraryStore.wallPositions(start: 0, count: 1, style: .wall), [0])
        XCTAssertEqual(PhotoLibraryStore.wallPositions(start: 0, count: 0, style: .wall), [])
        XCTAssertEqual(Set(PhotoLibraryStore.wallPositions(start: 5, count: 6, style: .wall)).count, 4)
    }

    @MainActor func testEmptyPickerCancellationDoesNotChangeSelection() async throws {
        let fixture = try PhotoFixture(); defer { fixture.remove() }
        let store = fixture.store()
        await store.importImages([{ try self.picture(width: 500, height: 300, color: .systemGreen) }])
        let identifier = store.frame?.id
        await store.importImages([])
        XCTAssertEqual(store.frame?.id, identifier)
        XCTAssertEqual(store.photoCount, 1)
        XCTAssertFalse(store.loading)
        XCTAssertNil(store.message)
    }

    @MainActor func testExistingSinglePhotoRestoresAndCanBecomeAMultiPhotoSelection() async throws {
        let fixture = try PhotoFixture(); defer { fixture.remove() }
        try picture(width: 3000, height: 1500, color: .systemTeal).write(to: fixture.legacyFile)
        let store = fixture.store(); store.restore()
        XCTAssertEqual(store.image?.size, CGSize(width: 2048, height: 1024))
        XCTAssertEqual(store.photoCount, 1)
        XCTAssertEqual(store.wallFrames.count, 1)
        await store.importImages([{ try self.picture(width: 700, height: 400, color: .systemBlue) }, { try self.picture(width: 400, height: 700, color: .systemPink) }])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.legacyFile.path))
        let reopened = fixture.store(); reopened.restore()
        XCTAssertEqual(reopened.photoCount, 2)
        XCTAssertEqual(reopened.image?.size, CGSize(width: 700, height: 400))
    }

    @MainActor private func picture(width: Int, height: Int, color: UIColor) throws -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            color.setFill(); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
    }
}

@MainActor private final class LibraryQueryGate {
    var status = PHAuthorizationStatus.authorized
    private var requests: [CheckedContinuation<PhotoLibraryQueryResult, Error>?] = []
    var client: PhotoLibraryQueryClient {
        PhotoLibraryQueryClient(authorization: { self.status }, fetch: { _, _, _ in
            try await self.read()
        }, observe: { _, _ in })
    }
    private func read() async throws -> PhotoLibraryQueryResult {
        // Intentionally ignore cancellation to exercise the store's delivery guard.
        try await withCheckedThrowingContinuation { requests.append($0) }
    }
    func waitForRequests(_ count: Int) async {
        for _ in 0..<100 {
            if requests.count >= count { break }
            await Task.yield()
        }
        XCTAssertEqual(requests.count, count)
    }
    func finish(_ index: Int, albums: [PhotoAlbum]) {
        guard requests.indices.contains(index) else { return XCTFail("Query never started") }
        requests[index]?.resume(returning: PhotoLibraryQueryResult(albums: albums))
        requests[index] = nil
    }
    func drain() async { for _ in 0..<30 { await Task.yield() } }
}

@MainActor private struct PhotoFixture {
    let directory: URL
    let defaults: UserDefaults
    let suite: String
    var legacyFile: URL { directory.appending(path: "ambient-photo.jpg") }
    init() throws {
        suite = "PhotoSelectionTests.\(UUID())"
        defaults = UserDefaults(suiteName: suite)!
        directory = FileManager.default.temporaryDirectory.appending(path: suite)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    func store() -> PhotoLibraryStore { PhotoLibraryStore(defaults: defaults, fileURL: legacyFile) }
    func remove() { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
}

@MainActor private final class PhotoSelectionGate {
    private let started: XCTestExpectation
    private var continuation: CheckedContinuation<Data?, Error>?
    init(started: XCTestExpectation) { self.started = started }
    func load() async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in self.continuation = continuation; started.fulfill() }
    }
    func finish(_ data: Data) { continuation?.resume(returning: data); continuation = nil }
}
