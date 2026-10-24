import SwiftUI
import AVFoundation

struct AerialMediaClient: Sendable {
    var download: @Sendable (URL, URL, @escaping @Sendable (Double?) -> Void) async throws -> Void
    var prepare: @Sendable (URL) async throws -> Data

    static let maximumVideoBytes: Int64 = 750 * 1_024 * 1_024
    static let live = AerialMediaClient(download: { source, destination, progress in
        let configuration = URLSessionConfiguration.ephemeral
        configuration.allowsCellularAccess = false
        configuration.allowsExpensiveNetworkAccess = false
        configuration.allowsConstrainedNetworkAccess = false
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 1_800
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let delegate = AerialDownloadProgress(progress: progress)
        let (temporary, response) = try await session.download(from: source, delegate: delegate)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.url?.scheme == "https", http.url?.host == "sylvan.apple.com" else { throw URLError(.badServerResponse) }
        let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= maximumVideoBytes else { throw CocoaError(.fileReadTooLarge) }
        try Task.checkCancellation()
        try FileManager.default.moveItem(at: temporary, to: destination)
    }, prepare: { url in
        let asset = AVURLAsset(url: url)
        let playable = try await asset.load(.isPlayable)
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard playable, duration.isFinite, duration > 0, !tracks.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1_920, height: 1_920)
        let frame = try await generator.image(at: .zero).image
        guard let jpeg = UIImage(cgImage: frame).jpegData(compressionQuality: 0.85) else { throw CocoaError(.fileReadCorruptFile) }
        try Task.checkCancellation()
        return jpeg
    })
}

private final class AerialDownloadProgress: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let progress: @Sendable (Double?) -> Void
    init(progress: @escaping @Sendable (Double?) -> Void) { self.progress = progress }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > AerialMediaClient.maximumVideoBytes || totalBytesExpectedToWrite > AerialMediaClient.maximumVideoBytes {
            downloadTask.cancel()
        }
        progress(totalBytesExpectedToWrite > 0 ? min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) : nil)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url?.scheme == "https" && request.url?.host == "sylvan.apple.com" ? request : nil)
    }
}

/// Owns a single silent foreground decoder and explicit, app-local downloads.
/// A selection is committed only after a complete download and media validation.
@MainActor final class AerialStore: ObservableObject {
    @Published private(set) var selection: String
    @Published private(set) var currentID: String
    @Published private(set) var downloaded: Set<String> = []
    @Published private(set) var downloadingID: String?
    @Published private(set) var progress: Double?
    @Published private(set) var message: String?
    @Published private(set) var poster: UIImage?
    @Published private(set) var player: AVQueuePlayer?
    @Published private(set) var playbackState = "Paused"
    @Published private(set) var videoFrameReady = false
    @Published private(set) var shuffleInterval: Double
    let clips: [AerialClip]
    let isValidationFixture: Bool
    private let defaults: UserDefaults
    private let directory: URL
    private let client: AerialMediaClient
    private var request = UUID()
    private var downloadTask: Task<Void, Never>?
    private var rotationTask: Task<Void, Never>?
    private var coverageTask: Task<Void, Never>?
    private var covered = false
    private var pausedForCoverage = false
    static let musicFadeSeconds: Double = 0.8
    private var looper: AVPlayerLooper?
    private var statusObservation: NSKeyValueObservation?
    private var loopObservation: NSKeyValueObservation?
    private var playbackGeneration = UUID()
    private var visible = false
    private var foreground = true
    private var reducedMotion = false
    private var deterministic = false
    private var playingID: String?
    static let intervals: [Double] = [60, 300, 900]
    static let cacheLimit: Int64 = 1_500 * 1_024 * 1_024

    init(defaults: UserDefaults = .standard,
         directory: URL = URL.applicationSupportDirectory.appending(path: "AppleAerials", directoryHint: .isDirectory),
         clips: [AerialClip] = AerialClip.catalog, client: AerialMediaClient = .live, validationFixture: Bool = false) {
        self.defaults = defaults; self.directory = directory; self.clips = clips; self.client = client
        isValidationFixture = validationFixture
        let saved = defaults.string(forKey: "background.aerialSelectionV1") ?? ""
        let initialSelection = saved == "shuffle" || clips.contains(where: { $0.id == saved }) ? saved : ""
        selection = initialSelection
        currentID = initialSelection == "shuffle" ? defaults.string(forKey: "background.aerialCurrentID") ?? "" : initialSelection
        let interval = defaults.double(forKey: "background.aerialInterval")
        shuffleInterval = Self.intervals.contains(interval) ? interval : 300
        for clip in clips where FileManager.default.fileExists(atPath: directory.appending(path: clip.id + ".mov").path)
            && UIImage(contentsOfFile: directory.appending(path: clip.id + ".jpg").path) != nil {
            downloaded.insert(clip.id)
        }
        // Incomplete transactions never count as downloaded media.
        if let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix("pending-") { try? FileManager.default.removeItem(at: file) }
        }
        if selection == "shuffle", !downloaded.contains(currentID) { currentID = clips.first(where: { downloaded.contains($0.id) })?.id ?? "" }
        if !selection.isEmpty && !downloaded.contains(currentID) {
            selection = ""; currentID = ""
            message = "The saved aerial is unavailable. Download it again to use it."
        }
        if !currentID.isEmpty { poster = UIImage(contentsOfFile: directory.appending(path: currentID + ".jpg").path) }
    }

    var enabled: Bool { !selection.isEmpty && downloaded.contains(currentID) }
    var shuffling: Bool { selection == "shuffle" }
    var currentClip: AerialClip? { clips.first { $0.id == currentID } }
    var cacheBytes: Int64 {
        downloaded.reduce(0) { $0 + Int64((try? videoURL($1).resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }
    func videoURL(_ id: String) -> URL { directory.appending(path: id + ".mov") }
    func thumbnail(_ id: String) -> UIImage? { UIImage(contentsOfFile: directory.appending(path: id + ".jpg").path) }

    func choose(_ clip: AerialClip) {
        guard clips.contains(clip) else { return }
        cancelDownload(); message = nil
        if downloaded.contains(clip.id) { commit(clip.id, shuffle: false); return }
        let token = request
        downloadingID = clip.id
        downloadTask = Task { [weak self] in await self?.download(clip, token: token) }
    }

    private func download(_ clip: AerialClip, token: UUID) async {
        let temporary = directory.appending(path: "pending-\(UUID()).mov")
        defer { try? FileManager.default.removeItem(at: temporary) }
        do {
            var folder = directory
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            try await client.download(clip.videoURL, temporary) { [weak self] fraction in
                Task { @MainActor [weak self] in
                    guard let self, self.request == token, self.downloadingID == clip.id else { return }
                    self.progress = fraction
                }
            }
            try Task.checkCancellation()
            guard request == token else { return }
            let data = try await client.prepare(temporary)
            try Task.checkCancellation()
            guard request == token, foreground else { return }
            guard let image = UIImage(data: data) else { throw CocoaError(.fileReadCorruptFile) }
            let bytes = Int64(try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
            guard bytes > 0, bytes <= AerialMediaClient.maximumVideoBytes else { throw CocoaError(.fileReadTooLarge) }
            guard cacheBytes + bytes <= Self.cacheLimit else {
                message = "Aerial storage is full. Remove a downloaded aerial and try again."
                finishDownload(); return
            }
            // Poster first, movie last: only the complete pair becomes available.
            let destination = videoURL(clip.id)
            let posterURL = directory.appending(path: clip.id + ".jpg")
            try data.write(to: posterURL, options: .atomic)
            do {
                if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                try FileManager.default.moveItem(at: temporary, to: destination)
            } catch {
                try? FileManager.default.removeItem(at: posterURL); throw error
            }
            downloaded.insert(clip.id); poster = image
            finishDownload(); commit(clip.id, shuffle: false)
        } catch {
            guard request == token else { return }
            finishDownload()
            if !Task.isCancelled { message = "This aerial could not be downloaded or played. Your previous background is unchanged. Check Wi-Fi and try again." }
        }
    }

    func cancelDownload() {
        request = UUID(); downloadTask?.cancel(); finishDownload()
    }
    private func finishDownload() { downloadingID = nil; progress = nil; downloadTask = nil }

    func useStaticBackground() {
        cancelDownload(); selection = ""; currentID = ""; poster = nil; message = nil
        defaults.removeObject(forKey: "background.aerialSelectionV1")
        defaults.removeObject(forKey: "background.aerialCurrentID")
        refreshPlayback()
    }

    func chooseShuffle() {
        guard !downloaded.isEmpty else { return }
        cancelDownload(); message = nil
        let first = downloaded.contains(currentID) ? currentID : clips.first(where: { downloaded.contains($0.id) })!.id
        commit(first, shuffle: true)
    }

    func setShuffleInterval(_ value: Double) {
        guard Self.intervals.contains(value) else { return }
        shuffleInterval = value; defaults.set(value, forKey: "background.aerialInterval"); scheduleRotation()
    }

    func remove(_ clip: AerialClip) {
        guard clips.contains(clip) else { return }
        if downloadingID == clip.id { cancelDownload() }
        if currentID == clip.id { useStaticBackground() }
        do {
            for file in [videoURL(clip.id), directory.appending(path: clip.id + ".jpg")] where FileManager.default.fileExists(atPath: file.path) {
                try FileManager.default.removeItem(at: file)
            }
            downloaded.remove(clip.id); scheduleRotation()
        } catch { message = "This aerial could not be removed. Please try again." }
    }

    func setForeground(_ value: Bool) {
        foreground = value
        if !value { cancelDownload() }
        refreshPlayback()
    }

    func setPresentation(visible: Bool, reducedMotion: Bool, deterministic: Bool, covered: Bool = false) {
        self.visible = visible; self.reducedMotion = reducedMotion; self.deterministic = deterministic; self.covered = covered
        refreshPlayback()
    }

    private func commit(_ id: String, shuffle: Bool) {
        guard downloaded.contains(id) else { return }
        currentID = id; selection = shuffle ? "shuffle" : id
        poster = thumbnail(id)
        defaults.set(selection, forKey: "background.aerialSelectionV1")
        defaults.set(id, forKey: "background.aerialCurrentID")
        refreshPlayback()
    }

    func advanceShuffle() {
        guard foreground, visible, !covered, !reducedMotion, shuffling else { return }
        let available = clips.filter { downloaded.contains($0.id) }
        guard available.count > 1 else { return }
        let candidates = available.filter { $0.id != currentID }
        let next: AerialClip?
        if deterministic, let index = available.firstIndex(where: { $0.id == currentID }) {
            next = available[(index + 1) % available.count]
        } else { next = candidates.randomElement() }
        guard let next else { return }
        commit(next.id, shuffle: true)
    }

    private func scheduleRotation() {
        rotationTask?.cancel(); rotationTask = nil
        guard foreground, visible, !covered, !reducedMotion, shuffling, downloaded.count > 1 else { return }
        let interval = shuffleInterval
        rotationTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(interval)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.advanceShuffle()
        }
    }

    private func refreshPlayback() {
        scheduleRotation()
        guard foreground, visible, !reducedMotion, enabled else { stopPlayer(); return }
        if playingID == currentID, player != nil { updateCoverage(); return }
        stopPlayer()
        // Do not create a decoder underneath an already opaque music page.
        guard !covered else { return }
        let token = playbackGeneration
        let queue = AVQueuePlayer()
        queue.isMuted = true; queue.volume = 0; queue.allowsExternalPlayback = false
        queue.preventsDisplaySleepDuringVideoPlayback = false
        queue.audiovisualBackgroundPlaybackPolicy = .pauses
        let loop = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: videoURL(currentID)))
        looper = loop; playingID = currentID; playbackState = "Starting"
        statusObservation = queue.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] queue, _ in
            let playing = queue.timeControlStatus == .playing
            Task { @MainActor [weak self] in
                guard let self, self.playbackGeneration == token else { return }
                if playing { self.videoFrameReady = true }
                self.playbackState = self.pausedForCoverage ? "Paused" : playing ? "Playing" : "Starting"
            }
        }
        loopObservation = loop.observe(\.status, options: [.new]) { [weak self] loop, _ in
            guard loop.status == .failed else { return }
            Task { @MainActor [weak self] in
                guard let self, self.playbackGeneration == token else { return }
                self.stopPlayer(); self.playbackState = "Unavailable"
                self.message = "The aerial could not play. Its saved still image is shown. Choose another aerial or download it again."
            }
        }
        player = queue; queue.play()
    }

    private func updateCoverage() {
        guard let player else { return }
        guard covered else {
            coverageTask?.cancel(); coverageTask = nil; pausedForCoverage = false
            player.play()
            return
        }
        guard coverageTask == nil, !pausedForCoverage else { return }
        let token = playbackGeneration
        coverageTask = Task { [weak self, weak player] in
            do { try await Task.sleep(for: .seconds(Self.musicFadeSeconds)) } catch { return }
            guard let self, let player, !Task.isCancelled, self.playbackGeneration == token,
                  self.foreground, self.visible, self.covered, self.player === player else { return }
            self.coverageTask = nil; self.pausedForCoverage = true
            player.pause(); self.playbackState = "Paused"
            // Keep the existing layer and its last rendered frame. Never swap
            // to the opening poster while the music overlay is fading.
        }
    }

    private func stopPlayer() {
        coverageTask?.cancel(); coverageTask = nil; pausedForCoverage = false
        videoFrameReady = false
        playbackGeneration = UUID()
        statusObservation = nil; loopObservation = nil
        player?.pause(); looper?.disableLooping(); looper = nil
        player?.removeAllItems(); player = nil; playingID = nil; playbackState = "Paused"
    }

    deinit { downloadTask?.cancel(); rotationTask?.cancel(); coverageTask?.cancel() }
}
