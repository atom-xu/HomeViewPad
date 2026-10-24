import SwiftUI
import AVKit
import HomeKit
import Combine

@MainActor final class AudioStore: ObservableObject {
    @Published var title = "Your room. Your soundtrack."
    @Published var message = "Choose an audio file, then select your HomePod with AirPlay."
    @Published var playing = false
    @Published private(set) var hasFile = false
    private var ownedPlayer: AVPlayer?
    var player: AVPlayer {
        if let ownedPlayer { return ownedPlayer }
        let player = AVPlayer()
        ownedPlayer = player
        observation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                let next = player.timeControlStatus == .playing
                if self?.playing != next { self?.playing = next }
            }
        }
        return player
    }
    private var scope: URL?
    private var observation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var interruption: NSObjectProtocol?
    init() {
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pause(); self?.message = "Playback interrupted. Tap Play to resume." }
        }
    }
    func load(_ url: URL) {
        stop()
        let scoped = url.startAccessingSecurityScopedResource()
        guard scoped || FileManager.default.isReadableFile(atPath: url.path) else { message = "Unable to open this file. Choose a downloaded audio file."; return }
        scope = scoped ? url : nil
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let item = AVPlayerItem(url: url)
            itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                Task { @MainActor in
                    if item === self?.player.currentItem, item.status == .failed { self?.message = item.error?.localizedDescription ?? "This audio file cannot be played." }
                }
            }
            player.replaceCurrentItem(with: item); hasFile = true; title = url.deletingPathExtension().lastPathComponent
            message = "Ready · use AirPlay to choose a speaker"; player.play()
        } catch { stop(); message = error.localizedDescription }
    }
    func toggle() {
        guard player.currentItem != nil else { return }
        if playing { player.pause() } else {
            if let duration = player.currentItem?.duration.seconds, duration.isFinite, player.currentTime().seconds >= duration { player.seek(to: .zero) }
            player.play()
        }
    }
    func pause() { ownedPlayer?.pause() }
    func stop() {
        ownedPlayer?.pause(); itemObservation = nil; ownedPlayer?.replaceCurrentItem(with: nil)
        scope?.stopAccessingSecurityScopedResource(); scope = nil
        if hasFile { hasFile = false }
        if playing { playing = false }
        if title != "Your room. Your soundtrack." { title = "Your room. Your soundtrack." }
        if message != "Choose an audio file, then select your HomePod with AirPlay." { message = "Choose an audio file, then select your HomePod with AirPlay." }
    }
}
struct AirPlayPicker: UIViewRepresentable {
    var lightControls = false
    var presentationChanged: (Bool) -> Void = { _ in }
    func makeCoordinator() -> Coordinator { Coordinator(presentationChanged: presentationChanged) }
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(); view.tintColor = lightControls ? .white : UIColor.label; view.activeTintColor = .systemPurple
        view.prioritizesVideoDevices = false
        view.delegate = context.coordinator
        view.accessibilityLabel = "Choose AirPlay speaker".tr; return view
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = lightControls ? .white : UIColor.label
        context.coordinator.presentationChanged = presentationChanged
    }
    static func dismantleUIView(_ uiView: AVRoutePickerView, coordinator: Coordinator) {
        uiView.delegate = nil
        if coordinator.presented { coordinator.setPresented(false) }
    }
    @MainActor final class Coordinator: NSObject, @preconcurrency AVRoutePickerViewDelegate {
        var presentationChanged: (Bool) -> Void
        private(set) var presented = false
        init(presentationChanged: @escaping (Bool) -> Void) { self.presentationChanged = presentationChanged }
        func setPresented(_ value: Bool) {
            guard presented != value else { return }
            presented = value; presentationChanged(value)
        }
        func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) { setPresented(true) }
        func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) { setPresented(false) }
    }
}

struct CameraSnapshotFrame {
    let snapshot: HMCameraSnapshot?
    let capturedAt: Date
}

@MainActor protocol HomePadCameraSnapshotClient: AnyObject {
    func takeSnapshot(_ completion: @escaping (Result<CameraSnapshotFrame, Error>) -> Void)
    func cancel()
}

/// A delivery belongs to exactly one request. Queued callbacks can never look
/// up a newer request's completion after crossing onto the main actor.
@MainActor final class CameraSnapshotRequestDelivery {
    let id: UUID
    private var completion: ((Result<CameraSnapshotFrame, Error>) -> Void)?
    init(id: UUID = UUID(), _ completion: @escaping (Result<CameraSnapshotFrame, Error>) -> Void) {
        self.id = id; self.completion = completion
    }
    nonisolated func enqueue(_ result: Result<CameraSnapshotFrame, Error>) {
        Task { @MainActor [weak self] in self?.finish(result) }
    }
    private func finish(_ result: Result<CameraSnapshotFrame, Error>) {
        let receiver = completion
        completion = nil
        receiver?(result)
    }
    func cancel() { completion = nil }
}

private final class CameraSnapshotRequestDelegate: NSObject, HMCameraSnapshotControlDelegate {
    private let controlID: ObjectIdentifier
    private let delivery: CameraSnapshotRequestDelivery
    init(control: HMCameraSnapshotControl, delivery: CameraSnapshotRequestDelivery) {
        controlID = ObjectIdentifier(control); self.delivery = delivery; super.init()
    }
    func cameraSnapshotControl(_ cameraSnapshotControl: HMCameraSnapshotControl, didTake snapshot: HMCameraSnapshot?, error: Error?) {
        guard ObjectIdentifier(cameraSnapshotControl) == controlID else { return }
        let result: Result<CameraSnapshotFrame, Error>
        if let error { result = .failure(error) }
        else if let snapshot { result = .success(CameraSnapshotFrame(snapshot: snapshot, capturedAt: snapshot.captureDate)) }
        else { result = .failure(CameraSnapshotError.unavailable) }
        delivery.enqueue(result)
    }
}

/// Snapshot requests and rendering use HomeKit's public camera-source API.
/// No image is extracted, persisted, or replaced with a generated placeholder.
@MainActor final class NativeHomePadCameraSnapshotClient: NSObject, HomePadCameraSnapshotClient {
    private let control: HMCameraSnapshotControl?
    private var delivery: CameraSnapshotRequestDelivery?
    private var delegateProxy: CameraSnapshotRequestDelegate?

    init(profile: HMCameraProfile?) { control = profile?.snapshotControl; super.init() }
    func takeSnapshot(_ completion: @escaping (Result<CameraSnapshotFrame, Error>) -> Void) {
        guard delivery == nil else { return }
        guard let control else { completion(.failure(CameraSnapshotError.unavailable)); return }
        let requestID = UUID()
        let delivery = CameraSnapshotRequestDelivery(id: requestID) { [weak self] result in
            guard let self, self.delivery?.id == requestID, let proxy = self.delegateProxy,
                  control.delegate === proxy else { return }
            self.delivery = nil; self.delegateProxy = nil
            control.delegate = nil
            // Earlier but real HomeKit frames retain their capture date; the
            // store labels them as earlier instead of claiming freshness.
            completion(result)
        }
        self.delivery = delivery
        let proxy = CameraSnapshotRequestDelegate(control: control, delivery: delivery)
        delegateProxy = proxy; control.delegate = proxy
        control.takeSnapshot()
    }
    func cancel() {
        delivery?.cancel(); delivery = nil
        if let proxy = delegateProxy, control?.delegate === proxy { control?.delegate = nil }
        delegateProxy = nil
    }
}

enum CameraSnapshotError: Error { case unavailable, timedOut }

/// One foreground cache shared by Home's camera cards. Hiding a card stops
/// polling but retains its last authorized frame; privacy boundaries clear it.
@MainActor final class CameraSnapshotStore: ObservableObject {
    private struct Record {
        var frame: CameraSnapshotFrame?
        var failed = false
        var pending = false
    }
    private final class Entry {
        let profile: HMCameraProfile?
        let client: HomePadCameraSnapshotClient
        var consumers: Set<UUID> = []
        var lastAttempt: Date?
        var requestID = UUID()
        var loop: Task<Void, Never>?
        var timeout: Task<Void, Never>?
        init(profile: HMCameraProfile?, client: HomePadCameraSnapshotClient) { self.profile = profile; self.client = client }
    }
    @Published private(set) var allowed = false
    @Published private var records: [UUID: Record] = [:]
    private var entries: [UUID: Entry] = [:]
    private var generation = UUID()
    private let now: () -> Date
    private let automaticRefresh: Bool
    private let makeClient: (HMCameraProfile?) -> HomePadCameraSnapshotClient

    init(now: @escaping () -> Date = Date.init, automaticRefresh: Bool = true,
         makeClient: ((HMCameraProfile?) -> HomePadCameraSnapshotClient)? = nil) {
        self.now = now; self.automaticRefresh = automaticRefresh
        self.makeClient = makeClient ?? { NativeHomePadCameraSnapshotClient(profile: $0) }
    }
    func snapshot(for id: UUID) -> HMCameraSnapshot? { records[id]?.frame?.snapshot }
    func lastUpdated(for id: UUID) -> Date? { records[id]?.frame?.capturedAt }
    func isStale(for id: UUID) -> Bool {
        guard let record = records[id], let frame = record.frame else { return false }
        return record.failed || now().timeIntervalSince(frame.capturedAt) > 15
    }
    func message(for id: UUID) -> String {
        let record = records[id]
        if record?.failed == true {
            return record?.frame == nil ? "Snapshot unavailable. Tap to open the camera." : "Snapshot update failed · showing earlier image"
        }
        if record?.frame != nil { return isStale(for: id) ? "Earlier snapshot" : "Snapshot · updates every 10 seconds" }
        return "Updating snapshot…"
    }
    func setAccess(allowed value: Bool) {
        guard allowed != value else { return }
        allowed = value
        if value {
            for (id, entry) in entries where !entry.consumers.isEmpty { activate(id, entry: entry) }
        } else {
            generation = UUID()
            for entry in entries.values { stop(entry) }
            records = [:]
        }
    }
    /// A household switch also discards registrations/profile references. The
    /// new household's cards must register again under their own identities.
    func clear() {
        generation = UUID()
        for entry in entries.values { stop(entry) }
        entries = [:]; records = [:]
    }
    func setVisible(cameraID: UUID, profile: HMCameraProfile?, consumerID: UUID, visible: Bool) {
        if !visible {
            guard let entry = entries[cameraID] else { return }
            entry.consumers.remove(consumerID)
            if entry.consumers.isEmpty { entry.loop?.cancel(); entry.loop = nil }
            return
        }
        let entry: Entry
        if let existing = entries[cameraID] { entry = existing }
        else { entry = Entry(profile: profile, client: makeClient(profile)); entries[cameraID] = entry }
        entry.consumers.insert(consumerID)
        guard allowed else { return }
        activate(cameraID, entry: entry)
    }
    /// Kept separate from scheduling so interval/single-flight and privacy
    /// behavior can be verified with a controlled clock and adapter.
    func refreshVisibleCameras() {
        guard allowed else { return }
        for (id, entry) in entries where !entry.consumers.isEmpty { requestIfDue(id, entry: entry) }
    }
    private func activate(_ id: UUID, entry: Entry) {
        requestIfDue(id, entry: entry)
        guard automaticRefresh, entry.loop == nil else { return }
        entry.loop = Task { [weak self, weak entry] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self, let entry, self.allowed, !entry.consumers.isEmpty, self.entries[id] === entry else { return }
                self.requestIfDue(id, entry: entry)
            }
        }
    }
    private func requestIfDue(_ id: UUID, entry: Entry) {
        guard allowed, !entry.consumers.isEmpty, records[id]?.pending != true,
              entry.lastAttempt.map({ now().timeIntervalSince($0) >= 10 }) ?? true else { return }
        let token = generation, requestID = UUID()
        entry.requestID = requestID; entry.lastAttempt = now()
        var record = records[id] ?? Record(); record.pending = true; records[id] = record
        // Install the timeout before the adapter; a deterministic adapter may
        // complete synchronously, just as HomeKit may return an immediate error.
        entry.timeout = Task { [weak self, weak entry] in
            do { try await Task.sleep(for: .seconds(20)) } catch { return }
            guard let self, let entry else { return }
            self.finish(.failure(CameraSnapshotError.timedOut), id: id, entry: entry, token: token, requestID: requestID)
        }
        entry.client.takeSnapshot { [weak self, weak entry] result in
            guard let self, let entry else { return }
            self.finish(result, id: id, entry: entry, token: token, requestID: requestID)
        }
    }
    private func finish(_ result: Result<CameraSnapshotFrame, Error>, id: UUID, entry: Entry, token: UUID, requestID: UUID) {
        guard allowed, token == generation, entries[id] === entry, entry.requestID == requestID,
              records[id]?.pending == true else { return }
        entry.timeout?.cancel(); entry.timeout = nil
        var record = records[id] ?? Record(); record.pending = false
        switch result {
        case .success(let frame): record.frame = frame; record.failed = false
        case .failure: record.failed = true
        }
        records[id] = record
        // Settle pending before cleanup: an adapter may synchronously report
        // its cancellation, which must not re-enter this completion again.
        if case .failure = result { entry.client.cancel() }
    }
    private func stop(_ entry: Entry) {
        entry.requestID = UUID(); entry.loop?.cancel(); entry.loop = nil
        entry.timeout?.cancel(); entry.timeout = nil
        entry.lastAttempt = nil; entry.client.cancel()
    }
}

@MainActor final class CameraSession: NSObject, ObservableObject, HMCameraStreamControlDelegate {
    @Published var stream: HMCameraStream?
    @Published var message = "Connecting to camera…"
    private var control: HMCameraStreamControl?
    private var timeout: Task<Void, Never>?
    private var starting = false
    func start(_ profile: HMCameraProfile?) {
        if let proposed = profile?.streamControl, proposed === control,
           proposed.delegate === self, starting || stream != nil { return }
        stop()
        guard let control = profile?.streamControl else { message = "This camera does not expose a live stream."; return }
        self.control = control; starting = true; control.delegate = self; message = "Connecting to camera…"; control.startStream()
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self, self.stream == nil else { return }
            self.stop(); self.message = "Camera unavailable. Check its connection and try again."
        }
    }
    nonisolated func cameraStreamControlDidStartStream(_ cameraStreamControl: HMCameraStreamControl) {
        Task { @MainActor in
            guard cameraStreamControl === self.control, cameraStreamControl.delegate === self, let stream = cameraStreamControl.cameraStream else { return }
            stream.updateAudioStreamSetting(.muted) { [weak self] error in
                Task { @MainActor in
                    guard let self, cameraStreamControl === self.control, cameraStreamControl.delegate === self else { return }
                    if let error { self.stop(); self.message = L10n.format("Unable to mute camera audio: %@", error.localizedDescription) }
                    else { self.timeout?.cancel(); self.starting = false; self.stream = stream; self.message = "Live · audio muted" }
                }
            }
        }
    }
    nonisolated func cameraStreamControl(_ cameraStreamControl: HMCameraStreamControl, didStopStreamWithError error: Error?) {
        Task { @MainActor in
            guard cameraStreamControl === self.control, cameraStreamControl.delegate === self else { return }
            self.timeout?.cancel(); self.starting = false; self.stream = nil; self.message = error?.localizedDescription ?? "Stream stopped. Tap Retry to reconnect."
        }
    }
    func stop() {
        timeout?.cancel()
        if let control, control.delegate === self { control.delegate = nil; control.stopStream() }
        control = nil; starting = false; stream = nil
    }
}
struct HomeCameraView: UIViewRepresentable {
    let source: HMCameraSource
    init(stream: HMCameraStream) { source = stream }
    init(snapshot: HMCameraSnapshot) { source = snapshot }
    func makeUIView(context: Context) -> HMCameraView { HMCameraView() }
    func updateUIView(_ uiView: HMCameraView, context: Context) { uiView.cameraSource = source }
    static func dismantleUIView(_ uiView: HMCameraView, coordinator: ()) { uiView.cameraSource = nil }
}
struct CameraSheet: View {
    let accessory: HMAccessory?
    let demo: Bool
    @StateObject private var camera = CameraSession()
    @Environment(\.scenePhase) private var phase
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let stream = camera.stream, !demo { HomeCameraView(stream: stream).aspectRatio(16/9, contentMode: .fit) }
            VStack(spacing: 20) {
                HStack { Text(demo ? "Front entrance".tr : (accessory?.name ?? "Camera".tr)).font(.title2.weight(.semibold)); Spacer(); Text((demo ? "DEMO" : "Foreground only").tr).font(.caption.bold()) }
                Spacer()
                if demo || camera.stream == nil {
                    Image(systemName: "video.slash.fill").font(.system(size: 64)).foregroundStyle(.white.opacity(0.6))
                    Text((demo ? "Demo camera" : camera.message).tr).font(.title3).multilineTextAlignment(.center)
                    if demo { Text("No video is being captured. Connect Apple Home to view a compatible camera.".tr).multilineTextAlignment(.center) }
                    else { Button("Retry camera".tr) { camera.start(accessory?.cameraProfiles?.first) }.buttonStyle(.borderedProminent) }
                }
                Spacer()
                Label("Audio muted · stream stops when closed or in background".tr, systemImage: "speaker.slash.fill").font(.footnote).multilineTextAlignment(.center).padding(16).background(.white.opacity(0.14), in: Capsule())
            }.padding(28)
        }.foregroundStyle(.white)
        .onAppear { if !demo { camera.start(accessory?.cameraProfiles?.first) } }
        .onDisappear { camera.stop() }
        .onChange(of: phase) { _, value in
            if value != .active { camera.stop() }
            else if !demo { camera.start(accessory?.cameraProfiles?.first) }
        }
    }
}
