import SwiftUI
import UIKit
import CoreMotion
import AVFoundation
import Vision
import ImageIO

enum DisplayNightMode: String, CaseIterable {
    case off, automatic, on
    var title: String {
        switch self { case .off: return "Off".tr; case .automatic: return "Scheduled".tr; case .on: return "On".tr }
    }
}

enum DisplayScreenBehavior: String, CaseIterable {
    case followSystem, keepDisplay, idleClock

    var title: String {
        switch self {
        case .followSystem: return "Follow system".tr
        case .keepDisplay: return "Keep display".tr
        case .idleClock: return "Show clock when idle".tr
        }
    }
}

/// Reads legacy intent without rewriting it. Only an explicit selection stores
/// the new mode; unknown future values retain the original flags.
struct DisplayScreenBehaviorPolicy {
    static let preferenceKey = "display.screenBehaviorV1"
    let explicitMode: DisplayScreenBehavior?
    let legacyAutomaticStandby: Bool
    let legacyKeepAwake: Bool

    init(explicitMode: DisplayScreenBehavior?, legacyAutomaticStandby: Bool, legacyKeepAwake: Bool) {
        self.explicitMode = explicitMode
        self.legacyAutomaticStandby = legacyAutomaticStandby
        self.legacyKeepAwake = legacyKeepAwake
    }

    init(defaults: UserDefaults) {
        explicitMode = defaults.string(forKey: Self.preferenceKey).flatMap(DisplayScreenBehavior.init(rawValue:))
        legacyAutomaticStandby = defaults.object(forKey: "display.automaticStandby") as? Bool ?? true
        legacyKeepAwake = defaults.object(forKey: "keepAwake") as? Bool ?? false
    }

    var selection: DisplayScreenBehavior {
        explicitMode ?? (legacyAutomaticStandby ? .idleClock : legacyKeepAwake ? .keepDisplay : .followSystem)
    }

    var automaticStandby: Bool {
        explicitMode.map { $0 == .idleClock } ?? legacyAutomaticStandby
    }

    var keepAwakeIntent: Bool {
        explicitMode.map { $0 != .followSystem } ?? legacyKeepAwake
    }

    func disablesIdleTimer(active: Bool, standby: Bool, motionAvailable: Bool) -> Bool {
        active && (standby || keepAwakeIntent || (automaticStandby && motionAvailable))
    }

    // Playback/display 05 deliberately updates already explicit V1 choices.
    // Only unselected legacy flags retain the old upright-motion requirement.
    var requiresUprightForEntry: Bool { explicitMode == nil }
    var keepsCurrentPageOnEntry: Bool { explicitMode == .keepDisplay }

    func automaticEntryEnabled(active: Bool, suspended: Bool, motionAvailable: Bool) -> Bool {
        guard active, !suspended else { return false }
        if let explicitMode { return explicitMode != .followSystem }
        return legacyAutomaticStandby && motionAvailable
    }

    func shouldEnter(activity: DisplayStandbyPolicy, at date: Date, delay: TimeInterval,
                     active: Bool, suspended: Bool, motionAvailable: Bool) -> Bool {
        guard automaticEntryEnabled(active: active, suspended: suspended, motionAvailable: motionAvailable) else { return false }
        return requiresUprightForEntry ? activity.shouldEnter(at: date, delay: delay) : activity.shouldEnterAfterIdle(at: date, delay: delay)
    }

    func selecting(_ behavior: DisplayScreenBehavior, defaults: UserDefaults) -> DisplayScreenBehaviorPolicy {
        defaults.set(behavior.rawValue, forKey: Self.preferenceKey)
        return DisplayScreenBehaviorPolicy(explicitMode: behavior, legacyAutomaticStandby: legacyAutomaticStandby, legacyKeepAwake: legacyKeepAwake)
    }
}

/// A deterministic policy: no clocks, hardware, permissions or application globals.
struct DisplayStandbyPolicy {
    private(set) var lastInteraction: Date
    private(set) var uprightSince: Date?
    private(set) var lastSample: Date?
    private(set) var lastFacePresence: Date?
    private(set) var upright = false

    init(now: Date) { lastInteraction = now }

    mutating func interact(at date: Date) {
        lastInteraction = date
        uprightSince = nil
    }

    mutating func reset(at date: Date) {
        lastInteraction = date; uprightSince = nil; lastSample = nil; lastFacePresence = nil; upright = false
    }

    mutating func noteFacePresence(at date: Date) {
        // Presence counts as activity without discarding a stable orientation.
        // Never allow a delayed sample to move the activity time backwards.
        lastFacePresence = max(lastFacePresence ?? date, date)
    }

    mutating func clearFacePresence() { lastFacePresence = nil }

    mutating func sample(gravityZ: Double, acceleration: Double, rotation: Double, at date: Date) {
        guard gravityZ.isFinite, acceleration.isFinite, rotation.isFinite,
              acceleration >= 0, rotation >= 0 else {
            upright = false; uprightSince = nil; lastSample = nil; return
        }
        // z is normal to the glass, so this works in landscape AND portrait.
        // Enter within 20° of vertical; leave beyond 25° to prevent threshold chatter.
        let limit = upright ? 0.423 : 0.342
        let continuous = lastSample.map { date.timeIntervalSince($0) >= 0 && date.timeIntervalSince($0) <= 3 } ?? false
        upright = abs(gravityZ) <= limit
        let stationary = acceleration < 0.025 && rotation < 0.08
        if !upright || !stationary { uprightSince = nil }
        else if uprightSince == nil || !continuous { uprightSince = date }
        lastSample = date
    }

    /// Explicit screen choices need only foreground inactivity, not a motion
    /// sensor or orientation. Music progress and photo changes are not activity.
    func shouldEnterAfterIdle(at date: Date, delay: TimeInterval) -> Bool {
        guard delay.isFinite, delay > 0 else { return false }
        let lastActivity = max(lastInteraction, lastFacePresence ?? lastInteraction)
        let idle = date.timeIntervalSince(lastActivity)
        return idle.isFinite && idle >= delay
    }

    func shouldEnter(at date: Date, delay: TimeInterval) -> Bool {
        guard delay.isFinite, delay > 0, upright, let since = uprightSince, let sample = lastSample else { return false }
        let age = date.timeIntervalSince(sample)
        let lastActivity = max(lastInteraction, lastFacePresence ?? lastInteraction)
        return age >= 0 && age <= 3 && date.timeIntervalSince(since) >= delay && date.timeIntervalSince(lastActivity) >= delay
    }

    static func isWakeMovement(acceleration: Double, rotation: Double) -> Bool {
        acceleration.isFinite && rotation.isFinite && (acceleration > 0.12 || rotation > 0.5)
    }
}

enum DisplayNightSchedule {
    static func contains(hour: Int, start: Int, end: Int) -> Bool {
        guard (0..<24).contains(hour), (0..<24).contains(start), (0..<24).contains(end), start != end else { return false }
        return start < end ? hour >= start && hour < end : hour >= start || hour < end
    }
}

/// Camera authorization permits access to hardware; it does not grant consent
/// to expand a legacy standby-only preference into continuous foreground use.
struct DisplayFaceCapturePolicy {
    static let foregroundConsentKey = "display.faceForegroundConsentVersion"
    static let currentConsentVersion = 1
    private(set) var wakeEnabled: Bool
    private(set) var foregroundConsentVersion: Int

    init(wakeEnabled: Bool, foregroundConsentVersion: Int = 0) {
        self.wakeEnabled = wakeEnabled
        self.foregroundConsentVersion = wakeEnabled ? foregroundConsentVersion : 0
    }

    init(defaults: UserDefaults) {
        self.init(wakeEnabled: defaults.bool(forKey: "display.faceWake"),
                  foregroundConsentVersion: defaults.integer(forKey: Self.foregroundConsentKey))
    }

    var continuousAllowed: Bool { wakeEnabled && foregroundConsentVersion == Self.currentConsentVersion }

    mutating func setWakeEnabled(_ value: Bool) {
        if !value || !wakeEnabled { foregroundConsentVersion = 0 }
        wakeEnabled = value
    }

    mutating func setContinuousConsent(_ value: Bool) {
        foregroundConsentVersion = value && wakeEnabled ? Self.currentConsentVersion : 0
    }

    func permitsCapture(active: Bool, standby: Bool, suspended: Bool, cameraAvailable: Bool, cameraAuthorized: Bool) -> Bool {
        wakeEnabled && active && !suspended && cameraAvailable && cameraAuthorized && (standby || continuousAllowed)
    }
}

/// Injectable access keeps restoration tests away from a device's actual global
/// brightness and idle timer. Production remains backed by the public UIKit APIs.
struct DisplaySystemAccess: Sendable {
    let brightness: @MainActor @Sendable () -> CGFloat
    let setBrightness: @MainActor @Sendable (CGFloat) -> Void
    let idleTimerDisabled: @MainActor @Sendable () -> Bool
    let setIdleTimerDisabled: @MainActor @Sendable (Bool) -> Void

    @MainActor static var live: DisplaySystemAccess {
        DisplaySystemAccess(brightness: { UIScreen.main.brightness },
                            setBrightness: { UIScreen.main.brightness = $0 },
                            idleTimerDisabled: { UIApplication.shared.isIdleTimerDisabled },
                            setIdleTimerDisabled: { UIApplication.shared.isIdleTimerDisabled = $0 })
    }
}

/// Sole owner of the app's idle timer and temporary standby brightness adjustment.
@MainActor final class DisplayCoordinator: ObservableObject {
    @Published private(set) var automaticStandby: Bool
    @Published private var explicitScreenBehavior: DisplayScreenBehavior?
    @Published private(set) var standbyDelay: Double
    @Published private(set) var motionWake: Bool
    @Published private var faceCapturePolicy: DisplayFaceCapturePolicy
    var faceWake: Bool { faceCapturePolicy.wakeEnabled }
    var faceForegroundConsent: Bool { faceCapturePolicy.continuousAllowed }
    @Published private(set) var proximityWake: Bool
    @Published private(set) var nightMode: DisplayNightMode
    @Published private(set) var nightStartHour: Int
    @Published private(set) var nightEndHour: Int
    @Published private(set) var nightActive = false
    @Published private(set) var isStandby = false
    /// Snapshotted only for an automatic Keep display entry. A manual preview
    /// always presents the selected clock/photos instead of retaining the page.
    @Published private(set) var standbyKeepsCurrentPage = false
    @Published private var motionStatusKey = "Motion detection is paused."
    var motionStatus: String { motionStatusKey.tr }
    @Published private var faceStatusKey = "Face presence detection is off."
    var faceStatus: String { faceStatusKey.tr }
    @Published private var proximityStatusKey = "Proximity detection is off."
    var proximityStatus: String { proximityStatusKey.tr }

    private let defaults: UserDefaults
    private let system: DisplaySystemAccess
    private let clock: @MainActor @Sendable () -> Date
    private let motion = CMMotionManager()
    private var timer: Timer?
    private var active = false
    private var suspended = false
    @Published private var keepAwake = false
    private var policy: DisplayStandbyPolicy
    private var faceSensor: DisplayFacePresenceSensor?
    private var faceGeneration = 0
    private var motionGeneration = 0
    private var proximityObserver: NSObjectProtocol?
    private var proximityAvailable: Bool?
    private var priorProximity: Bool?
    private var originalBrightness: CGFloat?
    private var originalIdleDisabled: Bool?
    private var previewGeneration = 0

    private var screenBehaviorPolicy: DisplayScreenBehaviorPolicy {
        DisplayScreenBehaviorPolicy(explicitMode: explicitScreenBehavior,
                                    legacyAutomaticStandby: automaticStandby,
                                    legacyKeepAwake: keepAwake)
    }
    var screenBehaviorSelection: DisplayScreenBehavior { screenBehaviorPolicy.selection }
    var effectiveAutomaticStandby: Bool { screenBehaviorPolicy.automaticStandby }
    var effectiveKeepAwakeIntent: Bool { screenBehaviorPolicy.keepAwakeIntent }
    var hasExplicitScreenBehavior: Bool { explicitScreenBehavior != nil }
    var usesLegacyMotionStandby: Bool { !hasExplicitScreenBehavior && automaticStandby }

    var motionAvailable: Bool { motion.isDeviceMotionAvailable }
    var faceAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
        #endif
    }

    init(defaults: UserDefaults = .standard, now: Date = Date(), system: DisplaySystemAccess? = nil,
         clock: (@MainActor @Sendable () -> Date)? = nil) {
        self.defaults = defaults
        self.system = system ?? .live
        self.clock = clock ?? { Date() }
        automaticStandby = defaults.object(forKey: "display.automaticStandby") as? Bool ?? true
        explicitScreenBehavior = defaults.string(forKey: DisplayScreenBehaviorPolicy.preferenceKey).flatMap(DisplayScreenBehavior.init(rawValue:))
        let savedDelay = defaults.object(forKey: "display.standbyDelay") as? Double ?? 60
        standbyDelay = [30.0, 60, 120, 300].contains(savedDelay) ? savedDelay : 60
        motionWake = defaults.object(forKey: "display.motionWake") as? Bool ?? true
        faceCapturePolicy = DisplayFaceCapturePolicy(defaults: defaults)
        proximityWake = defaults.bool(forKey: "display.proximityWake")
        nightMode = DisplayNightMode(rawValue: defaults.string(forKey: "display.nightMode") ?? "automatic") ?? .automatic
        nightStartHour = defaults.object(forKey: "display.nightStartHour") as? Int ?? 22
        nightEndHour = defaults.object(forKey: "display.nightEndHour") as? Int ?? 7
        policy = DisplayStandbyPolicy(now: now)
        keepAwake = defaults.bool(forKey: "keepAwake")
        if !(0..<24).contains(nightStartHour) { nightStartHour = 22 }
        if !(0..<24).contains(nightEndHour) { nightEndHour = 7 }
        refreshNight(at: now)
        if !motionAvailable { motionStatusKey = "Motion sensors are unavailable on this device." }
        if !faceAvailable { faceStatusKey = "Front camera detection is unavailable on this device." }
    }

    deinit {
        timer?.invalidate()
        motion.stopDeviceMotionUpdates()
        faceSensor?.stop()
        if let observer = proximityObserver { NotificationCenter.default.removeObserver(observer) }
        // SwiftUI calls setActive(false) on disappearance. Also restore globals if
        // the owner is released unexpectedly; deinit cannot assume the main actor.
        let brightness = originalBrightness
        let idle = originalIdleDisabled
        let proximity = priorProximity
        let system = system
        if brightness != nil || idle != nil || proximity != nil {
            Task { @MainActor in
                if let brightness { system.setBrightness(brightness) }
                if let idle { system.setIdleTimerDisabled(idle) }
                if let proximity { UIDevice.current.isProximityMonitoringEnabled = proximity }
            }
        }
    }

    func setActive(_ value: Bool) {
        guard active != value else { return }
        active = value
        policy.reset(at: clock())
        if value {
            originalIdleDisabled = system.idleTimerDisabled()
            refreshNight(at: clock())
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.evaluateIdle(at: self.clock())
                }
            }
        } else {
            timer?.invalidate(); timer = nil
            cancelPreview()
            if isStandby { isStandby = false }
            standbyKeepsCurrentPage = false
            stopFaceSensor(); stopMotion(); stopProximity()
            restoreBrightness()
        }
        updateMotion(); updateFaceSensor(); updateProximity(); updateIdleTimer()
    }

    // The Dashboard can keep supplying its legacy AppStorage value. It never
    // replaces a user's explicit new screen behavior.
    func setKeepAwake(_ value: Bool) {
        if keepAwake != value { keepAwake = value }
        updateIdleTimer()
    }

    func selectScreenBehavior(_ value: DisplayScreenBehavior) {
        let selected = screenBehaviorPolicy.selecting(value, defaults: defaults)
        explicitScreenBehavior = selected.explicitMode
        cancelPreview()
        policy.reset(at: clock())
        if isStandby { wake() }
        updateMotion(); updateIdleTimer()
    }

    func setPresentationSuspended(_ value: Bool) {
        guard suspended != value else { return }
        suspended = value
        policy.interact(at: clock())
        if value {
            cancelPreview()
            if isStandby { wake() }
        }
        updateFaceSensor(); updateProximity()
    }

    func noteInteraction() {
        policy.interact(at: clock())
        if isStandby { wake() }
    }

    func previewStandby() {
        previewGeneration += 1
        let generation = previewGeneration
        // SwiftUI may deliver the parent gesture after the button action across
        // several run-loop passes. Wait for the touch transaction to settle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.active, self.previewGeneration == generation else { return }
            self.enterStandby()
        }
    }

    private func cancelPreview() {
        previewGeneration += 1
    }

    func setAutomaticStandby(_ value: Bool) {
        automaticStandby = value; defaults.set(value, forKey: "display.automaticStandby")
        policy.reset(at: clock())
        if !effectiveAutomaticStandby {
            cancelPreview()
            if isStandby { wake() }
        }
        updateMotion(); updateIdleTimer()
    }

    func setStandbyDelay(_ value: Double) {
        guard [30.0, 60, 120, 300].contains(value) else { return }
        standbyDelay = value; defaults.set(value, forKey: "display.standbyDelay"); policy.interact(at: clock())
    }

    func setMotionWake(_ value: Bool) {
        motionWake = value; defaults.set(value, forKey: "display.motionWake"); updateMotion()
    }

    func setFaceWake(_ value: Bool) {
        faceCapturePolicy.setWakeEnabled(value)
        defaults.set(value, forKey: "display.faceWake")
        defaults.set(faceCapturePolicy.foregroundConsentVersion, forKey: DisplayFaceCapturePolicy.foregroundConsentKey)
        if !value {
            policy.clearFacePresence()
        }
        guard value, faceAvailable else { updateFaceSensor(); return }
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            faceStatusKey = "Waiting for camera permission."
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                Task { @MainActor in self?.updateFaceSensor() }
            }
        } else { updateFaceSensor() }
    }

    /// Only this explicit settings operation can grant the versioned expansion.
    func setFaceForegroundConsent(_ value: Bool) {
        faceCapturePolicy.setContinuousConsent(value)
        defaults.set(faceCapturePolicy.foregroundConsentVersion, forKey: DisplayFaceCapturePolicy.foregroundConsentKey)
        policy.clearFacePresence()
        updateFaceSensor()
    }

    func setProximityWake(_ value: Bool) {
        proximityWake = value; defaults.set(value, forKey: "display.proximityWake"); updateProximity()
    }

    func setNightMode(_ value: DisplayNightMode) {
        nightMode = value; defaults.set(value.rawValue, forKey: "display.nightMode"); refreshNight(at: clock())
    }

    func setNightStartHour(_ value: Int) {
        guard (0..<24).contains(value) else { return }
        nightStartHour = value; defaults.set(value, forKey: "display.nightStartHour"); refreshNight(at: clock())
    }

    func setNightEndHour(_ value: Int) {
        guard (0..<24).contains(value) else { return }
        nightEndHour = value; defaults.set(value, forKey: "display.nightEndHour"); refreshNight(at: clock())
    }

    /// The foreground timer calls this with the current time. A deterministic
    /// date also lets tests exercise entry and restoration without waiting.
    func evaluateIdle(at date: Date) {
        guard active else { return }
        refreshNight(at: date)
        if !isStandby, screenBehaviorPolicy.shouldEnter(activity: policy, at: date, delay: standbyDelay,
                                                       active: active, suspended: suspended, motionAvailable: motionAvailable) {
            enterStandby(keepingCurrentPage: screenBehaviorPolicy.keepsCurrentPageOnEntry)
        }
    }

    private func refreshNight(at date: Date) {
        let hour = Calendar.current.component(.hour, from: date)
        let next = nightMode == .on || (nightMode == .automatic && DisplayNightSchedule.contains(hour: hour, start: nightStartHour, end: nightEndHour))
        // @Published emits even for the same value. Publishing every timer tick
        // invalidates the complete Dashboard while menus and popovers are open.
        guard nightActive != next else { return }
        nightActive = next
        updateBrightness()
    }

    private func enterStandby(keepingCurrentPage: Bool = false) {
        guard !isStandby else { return }
        standbyKeepsCurrentPage = keepingCurrentPage
        isStandby = true
        updateBrightness(); updateIdleTimer(); updateFaceSensor(); updateProximity()
    }

    private func wake() {
        isStandby = false; standbyKeepsCurrentPage = false; policy.interact(at: clock())
        restoreBrightness(); updateIdleTimer(); updateFaceSensor(); updateProximity()
    }

    private func updateIdleTimer() {
        if active {
            // App-managed dimming/standby must remain in the foreground.
            // This does not wake or unlock a system-locked iPad.
            system.setIdleTimerDisabled(screenBehaviorPolicy.disablesIdleTimer(active: active, standby: isStandby, motionAvailable: motionAvailable))
        } else if let prior = originalIdleDisabled {
            system.setIdleTimerDisabled(prior); originalIdleDisabled = nil
        }
    }

    private func updateBrightness() {
        guard active, isStandby else { return }
        if originalBrightness == nil { originalBrightness = system.brightness() }
        system.setBrightness(min(originalBrightness ?? 0.5, nightActive ? 0.08 : 0.24))
    }

    private func restoreBrightness() {
        if let originalBrightness { system.setBrightness(originalBrightness) }
        originalBrightness = nil
    }

    private func updateMotion() {
        guard motionAvailable else { motionStatusKey = "Motion sensors are unavailable on this device."; return }
        let legacyOrientation = screenBehaviorPolicy.requiresUprightForEntry && effectiveAutomaticStandby
        guard active, legacyOrientation || motionWake else { stopMotion(); return }
        guard !motion.isDeviceMotionActive else { return }
        motionGeneration += 1
        let generation = motionGeneration
        motion.deviceMotionUpdateInterval = 0.5
        motionStatusKey = "Watching orientation and movement."
        motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, error in
            Task { @MainActor in
                guard let self, self.active, self.motionGeneration == generation else { return }
                guard error == nil, let sample else {
                    self.motionStatusKey = "Motion detection failed. Reopen the app to retry."
                    self.stopMotion(preserveStatus: true); return
                }
                let a = sample.userAcceleration; let r = sample.rotationRate
                let acceleration = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
                let rotation = sqrt(r.x * r.x + r.y * r.y + r.z * r.z)
                let now = self.clock()
                self.policy.sample(gravityZ: sample.gravity.z, acceleration: acceleration, rotation: rotation, at: now)
                if !self.isStandby, !self.screenBehaviorPolicy.requiresUprightForEntry, self.motionWake,
                   DisplayStandbyPolicy.isWakeMovement(acceleration: acceleration, rotation: rotation) {
                    self.policy.interact(at: now)
                }
                if self.isStandby && self.motionWake && DisplayStandbyPolicy.isWakeMovement(acceleration: acceleration, rotation: rotation) { self.wake() }
            }
        }
    }

    private func stopMotion(preserveStatus: Bool = false) {
        motionGeneration += 1; motion.stopDeviceMotionUpdates()
        if !preserveStatus { motionStatusKey = "Motion detection is paused." }
    }

    private func stopFaceSensor() {
        faceGeneration += 1; faceSensor?.stop(); faceSensor = nil
    }

    private func updateFaceSensor() {
        guard faceWake else { stopFaceSensor(); faceStatusKey = "Face presence detection is off."; return }
        guard faceAvailable else { stopFaceSensor(); faceStatusKey = "Front camera detection is unavailable on this device."; return }
        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        guard authorization == .authorized else {
            stopFaceSensor()
            faceStatusKey = authorization == .notDetermined ? "Enable camera permission using the face presence switch." : "Camera access is denied. Change it in iPad Settings."
            return
        }
        guard faceCapturePolicy.permitsCapture(active: active, standby: isStandby, suspended: suspended,
                                              cameraAvailable: true, cameraAuthorized: true) else {
            stopFaceSensor()
            faceStatusKey = active && !suspended ? "Camera runs only during foreground standby." : "Face detection pauses outside the foreground or while a panel is open."
            return
        }
        guard faceSensor == nil else { return }
        faceGeneration += 1
        let generation = faceGeneration
        faceStatusKey = "Starting face presence detection."
        let sensor = DisplayFacePresenceSensor { [weak self] event in
            Task { @MainActor in
                guard let self, self.faceGeneration == generation,
                      self.faceCapturePolicy.permitsCapture(active: self.active, standby: self.isStandby, suspended: self.suspended,
                                                           cameraAvailable: true, cameraAuthorized: AVCaptureDevice.authorizationStatus(for: .video) == .authorized) else { return }
                switch event {
                case .ready:
                    self.faceStatusKey = self.faceForegroundConsent ? "Continuous foreground camera detection is active." : "Camera is active during standby only."
                case .face:
                    if self.faceForegroundConsent { self.policy.noteFacePresence(at: self.clock()) }
                    if self.isStandby { self.wake() }
                case .failed:
                    self.stopFaceSensor(); self.faceStatusKey = "Camera detection is unavailable. Tap to wake."
                }
            }
        }
        faceSensor = sensor; sensor.start()
    }

    private func updateProximity() {
        guard proximityWake else { stopProximity(); proximityStatusKey = "Proximity detection is off."; return }
        if active, proximityAvailable == nil {
            // UIKit has no separate capability query. Probe only after explicit
            // opt-in, then immediately restore the prior monitoring state.
            let device = UIDevice.current
            let prior = device.isProximityMonitoringEnabled
            device.isProximityMonitoringEnabled = true
            proximityAvailable = device.isProximityMonitoringEnabled
            device.isProximityMonitoringEnabled = prior
        }
        guard proximityAvailable != false else {
            stopProximity(); proximityStatusKey = "No proximity sensor is exposed on this device."; return
        }
        guard active, isStandby, !suspended else {
            stopProximity(); proximityStatusKey = "Proximity detection runs only during foreground standby."; return
        }
        guard proximityObserver == nil else { return }
        let device = UIDevice.current
        priorProximity = device.isProximityMonitoringEnabled
        device.isProximityMonitoringEnabled = true
        guard device.isProximityMonitoringEnabled else {
            priorProximity = nil; proximityStatusKey = "No proximity sensor is exposed on this device."; return
        }
        proximityStatusKey = "Watching the supported proximity sensor."
        proximityObserver = NotificationCenter.default.addObserver(forName: UIDevice.proximityStateDidChangeNotification, object: device, queue: .main) { [weak self] _ in
            Task { @MainActor in
                // Uncovering a supported sensor restores the screen; do not
                // fight the system's screen-off behavior while it is covered.
                guard let self, self.active, self.isStandby, self.proximityWake, !self.suspended, !UIDevice.current.proximityState else { return }
                self.wake()
            }
        }
    }

    private func stopProximity() {
        if let proximityObserver { NotificationCenter.default.removeObserver(proximityObserver) }
        proximityObserver = nil
        if let priorProximity { UIDevice.current.isProximityMonitoringEnabled = priorProximity }
        priorProximity = nil
    }
}

/// Captures low-resolution frames for Vision face rectangles only. Nothing is
/// encoded, retained, written, sent over the network, or used for identity.
private final class DisplayFacePresenceSensor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum Event { case ready, face, failed }
    private let queue = DispatchQueue(label: "HomePad.FacePresence")
    private let session = AVCaptureSession()
    private let onEvent: (Event) -> Void
    private var lastFrameTime = -Double.infinity
    private var orientation: CGImagePropertyOrientation = .leftMirrored
    private var observers: [NSObjectProtocol] = []

    init(onEvent: @escaping (Event) -> Void) { self.onEvent = onEvent }

    func start() {
        // Fetch UI orientation on the main actor; capture/analysis stays serial.
        let orientation: CGImagePropertyOrientation
        switch UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.interfaceOrientation {
        case .landscapeLeft: orientation = .downMirrored
        case .landscapeRight: orientation = .upMirrored
        case .portraitUpsideDown: orientation = .rightMirrored
        default: orientation = .leftMirrored
        }
        queue.async { [self] in
            self.orientation = orientation
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
                  let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: camera) else { onEvent(.failed); return }
            session.beginConfiguration()
            session.sessionPreset = .low
            guard session.canAddInput(input) else { session.commitConfiguration(); onEvent(.failed); return }
            session.addInput(input)
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            guard session.canAddOutput(output) else { session.commitConfiguration(); onEvent(.failed); return }
            session.addOutput(output)
            output.setSampleBufferDelegate(self, queue: queue)
            session.commitConfiguration()
            for name in [Notification.Name.AVCaptureSessionRuntimeError, .AVCaptureSessionWasInterrupted] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: nil) { [weak self] _ in self?.onEvent(.failed) })
            }
            session.startRunning()
            onEvent(session.isRunning ? .ready : .failed)
        }
    }

    func stop() {
        queue.async { [self] in
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            for output in session.outputs { (output as? AVCaptureVideoDataOutput)?.setSampleBufferDelegate(nil, queue: nil) }
            if session.isRunning { session.stopRunning() }
            session.beginConfiguration()
            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }
            session.commitConfiguration()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard timestamp.isFinite, timestamp - lastFrameTime >= 1.5,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrameTime = timestamp
        autoreleasepool {
            let request = VNDetectFaceRectanglesRequest()
            do {
                try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation).perform([request])
                if request.results?.contains(where: { $0.confidence >= 0.7 && $0.boundingBox.width >= 0.05 }) == true { onEvent(.face) }
            } catch { onEvent(.failed) }
        }
    }
}
