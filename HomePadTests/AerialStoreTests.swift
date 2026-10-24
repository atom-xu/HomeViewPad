import XCTest
import AVFoundation
import UIKit
@testable import HomePad

final class AerialStoreTests: XCTestCase {
    private let clips = Array(AerialClip.catalog.prefix(3))

    @MainActor private func environment(client: AerialMediaClient? = nil) throws -> (AerialStore, URL, UserDefaults, String) {
        let directory = FileManager.default.temporaryDirectory.appending(path: "AerialTests-\(UUID())")
        let suite = "AerialTests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        let jpeg = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 18)).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.systemTeal.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 18))
        }
        let fake = AerialMediaClient(download: { _, destination, progress in
            try await AerialValidationMovie.write(to: destination); progress(1)
        }, prepare: { _ in jpeg })
        return (AerialStore(defaults: defaults, directory: directory, clips: clips, client: client ?? fake), directory, defaults, suite)
    }
    @MainActor private func waitForDownload(_ store: AerialStore) async {
        let deadline = Date.now.addingTimeInterval(5)
        while store.downloadingID != nil && Date.now < deadline { try? await Task.sleep(for: .milliseconds(20)) }
        XCTAssertNil(store.downloadingID)
    }

    @MainActor func testSuccessfulDownloadCommitsAndRestoresWithoutChangingPhotoOrLegacyPreferences() async throws {
        let (store, directory, defaults, suite) = try environment()
        defer { try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "tealWallpaper")
        XCTAssertFalse(store.enabled)
        store.choose(clips[0]); await waitForDownload(store)
        XCTAssertTrue(store.enabled); XCTAssertEqual(store.currentID, clips[0].id)
        XCTAssertNil(store.message); XCTAssertNotNil(store.poster)
        let reopened = AerialStore(defaults: defaults, directory: directory, clips: clips)
        XCTAssertEqual(reopened.currentID, clips[0].id); XCTAssertTrue(reopened.enabled)
        XCTAssertEqual(reopened.downloaded, [clips[0].id]); XCTAssertTrue(defaults.bool(forKey: "tealWallpaper"))
        store.useStaticBackground()
        XCTAssertFalse(store.enabled); XCTAssertTrue(store.downloaded.contains(clips[0].id))
        XCTAssertFalse(AerialStore(defaults: defaults, directory: directory, clips: clips).enabled)
        XCTAssertTrue(defaults.bool(forKey: "tealWallpaper"))
    }

    @MainActor func testFailedDownloadAndInvalidMediaPreservePreviousSelection() async throws {
        let gate = AerialFailureGate()
        let jpeg = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).jpegData(withCompressionQuality: 1) { _ in UIColor.blue.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 8, height: 8)) }
        let client = AerialMediaClient(download: { _, target, _ in
            if await gate.shouldFail { throw URLError(.notConnectedToInternet) }
            try Data("movie".utf8).write(to: target)
        }, prepare: { _ in
            if await gate.invalid { throw CocoaError(.fileReadCorruptFile) }
            return jpeg
        })
        let (store, directory, defaults, suite) = try environment(client: client)
        defer { try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        store.choose(clips[0]); await waitForDownload(store)
        await gate.failNetwork()
        store.choose(clips[1]); await waitForDownload(store)
        XCTAssertEqual(store.currentID, clips[0].id); XCTAssertNotNil(store.message)
        await gate.failMedia()
        store.choose(clips[2]); await waitForDownload(store)
        XCTAssertEqual(store.currentID, clips[0].id); XCTAssertEqual(store.downloaded, [clips[0].id])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.videoURL(clips[2].id).path))
        let leftovers = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        XCTAssertFalse(leftovers.contains { $0.lastPathComponent.hasPrefix("pending-") })
    }

    @MainActor func testCancellationAndBackgroundRejectAnUncooperativeLateDownload() async throws {
        for background in [false, true] {
            let gate = AerialDownloadGate()
            let client = AerialMediaClient(download: { _, target, _ in
                await gate.wait(); try Data("late-video".utf8).write(to: target)
            }, prepare: { _ in Data() })
            let (store, directory, defaults, suite) = try environment(client: client)
            store.choose(clips[0])
            while !(await gate.started) { await Task.yield() }
            if background { store.setForeground(false) } else { store.useStaticBackground() }
            await gate.release()
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertFalse(store.enabled); XCTAssertTrue(store.downloaded.isEmpty); XCTAssertNil(store.message)
            XCTAssertNil(store.downloadingID)
            XCTAssertFalse(FileManager.default.fileExists(atPath: store.videoURL(clips[0].id).path))
            try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite)
        }
    }

    @MainActor func testReplacingPendingSelectionRejectsOldCompletion() async throws {
        let gate = AerialDownloadGate()
        let jpeg = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).jpegData(withCompressionQuality: 1) { _ in UIColor.orange.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 8, height: 8)) }
        let first = clips[0].videoURL
        let client = AerialMediaClient(download: { source, target, _ in
            if source == first { await gate.wait() }
            try Data("movie".utf8).write(to: target)
        }, prepare: { _ in jpeg })
        let (store, directory, defaults, suite) = try environment(client: client)
        defer { try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        store.choose(clips[0]); while !(await gate.started) { await Task.yield() }
        store.choose(clips[1]); await waitForDownload(store)
        await gate.release(); try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(store.currentID, clips[1].id); XCTAssertEqual(store.downloaded, [clips[1].id])
        XCTAssertNil(store.message)
    }

    @MainActor func testShuffleUsesDownloadedOnlyAvoidsImmediateRepeatsAndRespectsVisibilityAndMotion() async throws {
        let (store, directory, defaults, suite) = try environment()
        defer { try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        for clip in clips { store.choose(clip); await waitForDownload(store) }
        store.chooseShuffle()
        store.setPresentation(visible: false, reducedMotion: false, deterministic: true)
        let initial = store.currentID; store.advanceShuffle(); XCTAssertEqual(store.currentID, initial)
        store.setPresentation(visible: true, reducedMotion: true, deterministic: true)
        store.advanceShuffle(); XCTAssertEqual(store.currentID, initial); XCTAssertNil(store.player)
        store.setPresentation(visible: true, reducedMotion: false, deterministic: true)
        var prior = store.currentID
        var visited: Set<String> = []
        for _ in 0..<6 {
            store.advanceShuffle(); XCTAssertNotEqual(store.currentID, prior)
            XCTAssertTrue(store.downloaded.contains(store.currentID)); prior = store.currentID; visited.insert(prior)
        }
        XCTAssertEqual(visited, store.downloaded, "The deterministic demo rotation reaches every downloaded clip")
        store.setForeground(false); store.advanceShuffle(); XCTAssertEqual(store.currentID, prior)
        XCTAssertNil(store.player)
    }

    @MainActor func testShuffleOrderIsDeterministicForTheSameDemoStateAndIntervalPersists() async throws {
        let (store, directory, defaults, suite) = try environment()
        defer { try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        for clip in clips { store.choose(clip); await waitForDownload(store) }
        store.chooseShuffle(); store.setShuffleInterval(60); store.setShuffleInterval(2)
        XCTAssertEqual(store.shuffleInterval, 60)
        let other = AerialStore(defaults: defaults, directory: directory, clips: clips)
        XCTAssertTrue(other.shuffling); XCTAssertEqual(other.shuffleInterval, 60)
        store.setPresentation(visible: true, reducedMotion: false, deterministic: true)
        other.setPresentation(visible: true, reducedMotion: false, deterministic: true)
        for _ in 0..<4 { store.advanceShuffle(); other.advanceShuffle(); XCTAssertEqual(store.currentID, other.currentID) }
        store.setForeground(false); other.setForeground(false)
    }

    @MainActor func testMissingCacheUnknownPreferenceAndPartialDownloadsFallBackWithoutClaimingAerial() throws {
        let (_, directory, defaults, suite) = try environment()
        defer { try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        defaults.set(clips[0].id, forKey: "background.aerialSelectionV1")
        let missing = AerialStore(defaults: defaults, directory: directory, clips: clips)
        XCTAssertFalse(missing.enabled); XCTAssertNotNil(missing.message)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("interrupted".utf8).write(to: directory.appending(path: "pending-test.mov"))
        try Data("no-poster".utf8).write(to: directory.appending(path: clips[0].id + ".mov"))
        defaults.set("unknown-version", forKey: "background.aerialSelectionV1")
        let restored = AerialStore(defaults: defaults, directory: directory, clips: clips)
        XCTAssertFalse(restored.enabled); XCTAssertTrue(restored.downloaded.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appending(path: "pending-test.mov").path))
        XCTAssertEqual(defaults.string(forKey: "background.aerialSelectionV1"), "unknown-version", "Reading unknown preferences never migrates them")
    }

    @MainActor func testAerialChoiceAbandonsALatePhotoImportWithoutDeletingTheSavedPhoto() async throws {
        let (store, directory, defaults, suite) = try environment()
        defer { try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let wallpaper = WallpaperStore(fileURL: directory.appending(path: "background.jpg"))
        func image(_ color: UIColor) -> Data {
            UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).jpegData(withCompressionQuality: 1) { _ in
                color.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 16, height: 16))
            }
        }
        let prior = image(.blue), replacement = image(.orange)
        await wallpaper.importImage { prior }
        let priorID = wallpaper.imageID
        let gate = AerialDownloadGate()
        let importing = Task {
            if await wallpaper.importImage(loadData: { await gate.wait(); return replacement }) { store.useStaticBackground() }
        }
        while !(await gate.started) { await Task.yield() }
        wallpaper.cancelImport(); store.choose(clips[0]); await waitForDownload(store)
        await gate.release(); await importing.value
        XCTAssertTrue(store.enabled); XCTAssertEqual(store.currentID, clips[0].id)
        XCTAssertEqual(wallpaper.imageID, priorID); XCTAssertFalse(wallpaper.loading)
        let restored = WallpaperStore(fileURL: directory.appending(path: "background.jpg"))
        await restored.restore(); XCTAssertEqual(restored.imageID, priorID)
    }

    @MainActor func testRemovingCurrentAerialReleasesPlayerAndPreservesOtherDownloads() async throws {
        let (store, directory, defaults, suite) = try environment()
        defer { try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        for clip in clips.prefix(2) { store.choose(clip); await waitForDownload(store) }
        store.remove(clips[1])
        XCTAssertFalse(store.enabled); XCTAssertNil(store.player)
        XCTAssertEqual(store.downloaded, [clips[0].id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.videoURL(clips[0].id).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.videoURL(clips[1].id).path))
    }

    @MainActor func testNativeVideoValidationSilentPlaybackLoopAndForegroundCleanup() async throws {
        let client = AerialMediaClient(download: { _, target, _ in try await AerialValidationMovie.write(to: target) }, prepare: AerialMediaClient.live.prepare)
        let (store, directory, defaults, suite) = try environment(client: client)
        defer { store.setForeground(false); try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        store.choose(clips[0]); await waitForDownload(store)
        XCTAssertNil(store.message); XCTAssertTrue(store.enabled)
        store.setPresentation(visible: true, reducedMotion: false, deterministic: false)
        let player = try XCTUnwrap(store.player)
        XCTAssertTrue(player.isMuted); XCTAssertEqual(player.volume, 0); XCTAssertFalse(player.allowsExternalPlayback)
        XCTAssertFalse(player.preventsDisplaySleepDuringVideoPlayback)
        let deadline = Date.now.addingTimeInterval(6)
        while !(player.currentTime().seconds.isFinite && player.currentTime().seconds > 0.5) && Date.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertGreaterThan(player.currentTime().seconds, 0.5)
        try await Task.sleep(for: .seconds(3.2))
        XCTAssertEqual(player.timeControlStatus, .playing, "Playback continues beyond the three-second movie duration")
        store.setPresentation(visible: true, reducedMotion: true, deterministic: false)
        XCTAssertNil(store.player); XCTAssertNotNil(store.poster); XCTAssertTrue(player.items().isEmpty)
        store.setPresentation(visible: true, reducedMotion: false, deterministic: false)
        XCTAssertNotNil(store.player)
        store.setForeground(false); XCTAssertNil(store.player); XCTAssertNotNil(store.poster)
    }

    @MainActor private func startNativePlayback(_ store: AerialStore) async throws -> AVQueuePlayer {
        store.choose(clips[0]); await waitForDownload(store)
        store.setPresentation(visible: true, reducedMotion: false, deterministic: true)
        let player = try XCTUnwrap(store.player)
        let deadline = Date.now.addingTimeInterval(6)
        while (!store.videoFrameReady || !player.currentTime().seconds.isFinite || player.currentTime().seconds < 0.6) && Date.now < deadline {
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTAssertTrue(store.videoFrameReady); XCTAssertGreaterThan(player.currentTime().seconds, 0.5)
        return player
    }

    @MainActor func testMusicCoverageKeepsMovingVideoThroughFadeThenResumesTheSamePausedFrame() async throws {
        let (store, directory, defaults, suite) = try environment()
        defer { store.setForeground(false); try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        let player = try await startNativePlayback(store)
        let before = player.currentTime().seconds
        store.setPresentation(visible: true, reducedMotion: false, deterministic: true, covered: true)
        XCTAssertTrue(store.player === player); XCTAssertTrue(store.videoFrameReady)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertGreaterThan(player.currentTime().seconds, before + 0.1, "The fading-out aerial still moves, rather than reverting to its opening poster")
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertEqual(store.playbackState, "Paused"); XCTAssertTrue(store.videoFrameReady)
        XCTAssertTrue(store.player === player); XCTAssertFalse(player.items().isEmpty)
        let frozen = player.currentTime().seconds
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(player.currentTime().seconds, frozen, accuracy: 0.04)
        store.setPresentation(visible: true, reducedMotion: false, deterministic: true, covered: false)
        XCTAssertTrue(store.player === player); XCTAssertTrue(store.videoFrameReady)
        XCTAssertEqual(player.currentTime().seconds, frozen, accuracy: 0.06, "Uncover does not seek to zero or construct a replacement queue")
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertGreaterThan(player.currentTime().seconds, frozen + 0.1)
    }

    @MainActor func testUncoverCancelsThePendingPauseAndActualHidingStillReleasesImmediately() async throws {
        let (store, directory, defaults, suite) = try environment()
        defer { store.setForeground(false); try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        let player = try await startNativePlayback(store)
        store.setPresentation(visible: true, reducedMotion: false, deterministic: true, covered: true)
        try await Task.sleep(for: .milliseconds(150))
        store.setPresentation(visible: true, reducedMotion: false, deterministic: true)
        try await Task.sleep(for: .milliseconds(850))
        XCTAssertTrue(store.player === player); XCTAssertEqual(player.timeControlStatus, .playing)
        XCTAssertTrue(store.videoFrameReady)
        store.setPresentation(visible: true, reducedMotion: false, deterministic: true, covered: true)
        store.setPresentation(visible: false, reducedMotion: false, deterministic: true, covered: true)
        XCTAssertNil(store.player); XCTAssertFalse(store.videoFrameReady); XCTAssertTrue(player.items().isEmpty)
        try await Task.sleep(for: .milliseconds(900))
        XCTAssertNil(store.player, "A cancelled coverage task cannot restore an offscreen decoder")
    }

    @MainActor func testAlreadyCoveredBackgroundDoesNotCreateAPlayerAndBackgroundCancelsCoverage() async throws {
        let (store, directory, defaults, suite) = try environment()
        defer { store.setForeground(false); try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: suite) }
        store.choose(clips[0]); await waitForDownload(store)
        store.setPresentation(visible: true, reducedMotion: false, deterministic: true, covered: true)
        XCTAssertNil(store.player)
        store.setPresentation(visible: true, reducedMotion: false, deterministic: true)
        let player = try XCTUnwrap(store.player)
        store.setPresentation(visible: true, reducedMotion: false, deterministic: true, covered: true)
        store.setForeground(false)
        XCTAssertNil(store.player); XCTAssertTrue(player.items().isEmpty)
        try await Task.sleep(for: .milliseconds(900))
        XCTAssertNil(store.player); XCTAssertFalse(store.videoFrameReady)
    }

    func testNativeValidationRejectsNonVideoWithoutCreatingAPoster() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "invalid-\(UUID()).mov")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not a video".utf8).write(to: url)
        do { _ = try await AerialMediaClient.live.prepare(url); XCTFail("Invalid content cannot become an available aerial") } catch {}
    }
}

private actor AerialFailureGate {
    var shouldFail = false
    var invalid = false
    func failNetwork() { shouldFail = true }
    func failMedia() { shouldFail = false; invalid = true }
}
private actor AerialDownloadGate {
    private var continuation: CheckedContinuation<Void, Never>?
    var started = false
    func wait() async { await withCheckedContinuation { continuation = $0; started = true } }
    func release() { continuation?.resume(); continuation = nil }
}
