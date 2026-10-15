import SwiftUI
import EventKit
import AVKit
import HomeKit
import Combine

@MainActor final class PersonalStore: ObservableObject {
    @Published var events: [String] = []
    @Published var reminders: [String] = []
    @Published var calendarStatus = "Not connected"
    @Published var reminderStatus = "Not connected"
    private let store = EKEventStore()
    private var generation = UUID()
    func loadCalendar(request: Bool = false) async {
        let token = generation
        do {
            if request { guard try await store.requestFullAccessToEvents() else { calendarStatus = "Access denied — enable Calendars in Settings"; events = []; return } }
            guard token == generation else { return }
            guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { events = []; calendarStatus = "Not connected"; return }
            let start = Date(), end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
            events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil)).prefix(5).map {
                "\($0.isAllDay ? "All day" : $0.startDate.formatted(date: .omitted, time: .shortened)) · \($0.title ?? "Untitled event")"
            }
            calendarStatus = events.isEmpty ? "Nothing in the next 24 hours" : "Next 24 hours"
        } catch { guard token == generation else { return }; calendarStatus = error.localizedDescription }
    }
    func loadReminders(request: Bool = false) async {
        let token = generation
        do {
            if request { guard try await store.requestFullAccessToReminders() else { reminderStatus = "Access denied — enable Reminders in Settings"; reminders = []; return } }
            guard token == generation else { return }
            guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { reminders = []; reminderStatus = "Not connected"; return }
            let result: [EKReminder] = await withCheckedContinuation { continuation in
                store.fetchReminders(matching: store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)) { continuation.resume(returning: $0 ?? []) }
            }
            guard token == generation else { return }
            reminders = result.sorted { ($0.dueDateComponents?.date ?? .distantFuture) < ($1.dueDateComponents?.date ?? .distantFuture) }.prefix(5).map { $0.title ?? "Untitled reminder" }
            reminderStatus = reminders.isEmpty ? "All caught up" : "Open reminders"
        } catch { guard token == generation else { return }; reminderStatus = error.localizedDescription }
    }
    func clear() { generation = UUID(); events = []; reminders = []; calendarStatus = "Not connected"; reminderStatus = "Not connected" }
}

@MainActor final class AudioStore: ObservableObject {
    @Published var title = "Your room. Your soundtrack."
    @Published var message = "Choose an audio file, then select your HomePod with AirPlay."
    @Published var playing = false
    let player = AVPlayer()
    private var scope: URL?
    private var observation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var interruption: NSObjectProtocol?
    init() {
        observation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in self?.playing = player.timeControlStatus == .playing }
        }
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.player.pause(); self?.message = "Playback interrupted. Tap Play to resume." }
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
            player.replaceCurrentItem(with: item); title = url.deletingPathExtension().lastPathComponent
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
    func stop() {
        player.pause(); itemObservation = nil; player.replaceCurrentItem(with: nil)
        scope?.stopAccessingSecurityScopedResource(); scope = nil
        playing = false; title = "Your room. Your soundtrack."
        message = "Choose an audio file, then select your HomePod with AirPlay."
    }
}
struct AirPlayPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(); view.tintColor = UIColor.label; view.activeTintColor = .systemPurple
        view.accessibilityLabel = "Choose AirPlay speaker"; return view
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

@MainActor final class CameraSession: NSObject, ObservableObject, HMCameraStreamControlDelegate {
    @Published var stream: HMCameraStream?
    @Published var message = "Connecting to camera…"
    private var control: HMCameraStreamControl?
    private var timeout: Task<Void, Never>?
    func start(_ profile: HMCameraProfile?) {
        stop()
        guard let control = profile?.streamControl else { message = "This camera does not expose a live stream."; return }
        self.control = control; control.delegate = self; message = "Connecting to camera…"; control.startStream()
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self, self.stream == nil else { return }
            self.stop(); self.message = "Camera unavailable. Check its connection and try again."
        }
    }
    nonisolated func cameraStreamControlDidStartStream(_ cameraStreamControl: HMCameraStreamControl) {
        Task { @MainActor in
            guard cameraStreamControl === self.control, let stream = cameraStreamControl.cameraStream else { return }
            stream.updateAudioStreamSetting(.muted) { [weak self] error in
                Task { @MainActor in
                    guard let self, cameraStreamControl === self.control else { return }
                    if let error { self.stop(); self.message = "Unable to mute camera audio: \(error.localizedDescription)" }
                    else { self.timeout?.cancel(); self.stream = stream; self.message = "Live · audio muted" }
                }
            }
        }
    }
    nonisolated func cameraStreamControl(_ cameraStreamControl: HMCameraStreamControl, didStopStreamWithError error: Error?) {
        Task { @MainActor in
            guard cameraStreamControl === self.control else { return }; self.stream = nil; self.message = error?.localizedDescription ?? "Stream stopped. Tap Retry to reconnect."
        }
    }
    func stop() { timeout?.cancel(); control?.delegate = nil; control?.stopStream(); control = nil; stream = nil }
}
struct HomeCameraView: UIViewRepresentable {
    let stream: HMCameraStream
    func makeUIView(context: Context) -> HMCameraView { HMCameraView() }
    func updateUIView(_ uiView: HMCameraView, context: Context) { uiView.cameraSource = stream }
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
                HStack { Text(demo ? "Front entrance" : (accessory?.name ?? "Camera")).font(.title2.weight(.semibold)); Spacer(); Text(demo ? "DEMO" : "Foreground only").font(.caption.bold()) }
                Spacer()
                if demo || camera.stream == nil {
                    Image(systemName: "video.slash.fill").font(.system(size: 64)).foregroundStyle(.white.opacity(0.6))
                    Text(demo ? "Demo camera" : camera.message).font(.title3).multilineTextAlignment(.center)
                    if demo { Text("No video is being captured. Connect Apple Home to view a compatible camera.").multilineTextAlignment(.center) }
                    else { Button("Retry camera") { camera.start(accessory?.cameraProfiles?.first) }.buttonStyle(.borderedProminent) }
                }
                Spacer()
                Label("Audio muted · stream stops when closed or in background", systemImage: "speaker.slash.fill").font(.footnote).multilineTextAlignment(.center).padding(16).background(.white.opacity(0.14), in: Capsule())
            }.padding(28)
        }.foregroundStyle(.white)
        .onAppear { if !demo { camera.start(accessory?.cameraProfiles?.first) } }
        .onDisappear { camera.stop() }
        .onChange(of: phase) { _, value in if value != .active { camera.stop() } }
    }
}
