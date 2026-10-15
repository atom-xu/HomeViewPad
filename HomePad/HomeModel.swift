import Foundation
import HomeKit
import Combine

struct HomeTile: Identifiable {
    let id: UUID
    var name: String
    var room: String
    var symbol: String
    var value: String
    var isOn: Bool
    var reachable: Bool
    var writable: Bool
    var kind: HomeValueKind = .power
    var number: Double?
    var adjustment: HomeAdjustment?
    var isClimate: Bool { kind == .temperature || kind == .humidity || kind == .targetTemperature }
    var dashboardSlot: Int {
        if isClimate { return 0 }
        if kind == .brightness || symbol == "lightbulb.fill" || symbol == "lamp.desk.fill" { return 5 }
        return 4
    }
    /// Arrows move by the accessory's advertised step, never past its limits.
    func temperatureStep(increase: Bool) -> Double? {
        guard kind == .targetTemperature, writable, reachable, let number, number.isFinite,
              let adjustment, number >= adjustment.minimum, number <= adjustment.maximum else { return nil }
        let position = (number - adjustment.minimum) / adjustment.step
        let next = increase ? floor(position + 0.000001) + 1 : ceil(position - 0.000001) - 1
        let value = adjustment.minimum + next * adjustment.step
        return adjustment.accepts(value) ? value : nil
    }
}

enum HomeValueKind: CaseIterable {
    case power, temperature, humidity, brightness, targetTemperature, fanSpeed
    init?(characteristicType: String) {
        switch characteristicType {
        case HMCharacteristicTypePowerState: self = .power
        case HMCharacteristicTypeCurrentTemperature: self = .temperature
        case HMCharacteristicTypeCurrentRelativeHumidity: self = .humidity
        case HMCharacteristicTypeBrightness: self = .brightness
        case HMCharacteristicTypeTargetTemperature: self = .targetTemperature
        case HMCharacteristicTypeRotationSpeed: self = .fanSpeed
        default: return nil
        }
    }
    var title: String {
        switch self {
        case .power: return "Power"
        case .temperature: return "Temperature"
        case .humidity: return "Humidity"
        case .brightness: return "Brightness"
        case .targetTemperature: return "Target temperature"
        case .fanSpeed: return "Fan speed"
        }
    }
    var symbol: String {
        switch self {
        case .power: return "power"
        case .temperature, .targetTemperature: return "thermometer.medium"
        case .humidity: return "humidity.fill"
        case .brightness: return "lightbulb.fill"
        case .fanSpeed: return "fan.fill"
        }
    }
    var adjustable: Bool { self == .brightness || self == .targetTemperature || self == .fanSpeed }
    func formatted(_ number: Double) -> String {
        guard number.isFinite else { return "Unavailable" }
        switch self {
        case .power: return number != 0 ? "On" : "Off"
        case .temperature, .targetTemperature: return String(format: "%.1f °C", number)
        default: return String(format: "%.0f %%", number)
        }
    }
}

struct HomeAdjustment: Equatable {
    let minimum: Double
    let maximum: Double
    let step: Double
    init?(minimum: Double?, maximum: Double?, step: Double?) {
        guard let minimum, let maximum, let step, minimum.isFinite, maximum.isFinite, step.isFinite,
              minimum < maximum, step > 0, step <= maximum - minimum else { return nil }
        self.minimum = minimum; self.maximum = maximum; self.step = step
    }
    func accepts(_ value: Double) -> Bool {
        guard value.isFinite, value >= minimum, value <= maximum else { return false }
        let increments = (value - minimum) / step
        return abs(increments - increments.rounded()) < 0.00001
    }
}
enum HomeStatus: String, CaseIterable {
    case welcome, loading, ready, denied, empty, offline
    var title: String {
        switch self {
        case .welcome: return "A little closer to home."
        case .loading: return "Finding your home…"
        case .ready: return "Your home, at a glance."
        case .denied: return "Home access is off"
        case .empty: return "Your home starts here"
        case .offline: return "Home is taking a moment"
        }
    }
    var detail: String {
        switch self {
        case .welcome: return "Connect Apple Home to see your rooms, accessories and scenes. Or explore a clearly labeled demo without sharing anything."
        case .loading: return "Waiting for Apple Home. You can retry or explore the demo."
        case .ready: return ""
        case .denied: return "Allow HomeViewPad in Settings → Privacy & Security → HomeKit, then retry."
        case .empty: return "Create a home and add accessories in Apple's Home app, then return here."
        case .offline: return "Check your home Wi-Fi, accessory power and home hub. Retry when you're connected."
        }
    }
}

@MainActor final class HomeStore: NSObject, ObservableObject, HMHomeManagerDelegate, HMHomeDelegate, HMAccessoryDelegate {
    @Published var demo = false
    @Published var status: HomeStatus = .welcome
    @Published var tiles: [HomeTile] = []
    @Published var scenes: [String] = []
    @Published var cameras: [HMAccessory] = []
    @Published var homes: [HMHome] = []
    @Published var homeName = "HomeViewPad"
    @Published private(set) var selectedHomeID: UUID?
    @Published var error: String?
    @Published var busy = Set<UUID>()
    @Published var sceneBusy = false
    @Published var notice: String?
    private var manager: HMHomeManager?
    private var home: HMHome?
    private var characteristics: [UUID: HMCharacteristic] = [:]
    private var generation = UUID()
    private var failedReads = Set<UUID>()
    private var timeout: Task<Void, Never>?

    func startDemo(state: HomeStatus = .ready) {
        disconnect()
        demo = true
        UserDefaults.standard.set("demo", forKey: "homeMode")
        status = state
        homeName = "Juniper House"
        scenes = state == .ready ? ["Good morning", "Evening glow", "Good night"] : []
        tiles = state == .ready ? [
            HomeTile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Pendant lights", room: "Kitchen", symbol: "lightbulb.fill", value: "On", isOn: true, reachable: true, writable: true),
            HomeTile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Reading lamp", room: "Living room", symbol: "lamp.desk.fill", value: "Off", isOn: false, reachable: true, writable: true),
            HomeTile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "Ceiling fan", room: "Bedroom", symbol: "fan.fill", value: "Off", isOn: false, reachable: true, writable: true),
            HomeTile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, name: "Temperature", room: "Living room", symbol: "thermometer.medium", value: "21.5 °C", isOn: false, reachable: true, writable: false, kind: .temperature, number: 21.5),
            HomeTile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!, name: "Thermostat", room: "Living room", symbol: "thermometer.medium", value: "22.0 °C", isOn: false, reachable: true, writable: true, kind: .targetTemperature, number: 22, adjustment: HomeAdjustment(minimum: 10, maximum: 30, step: 0.5))
        ] : []
    }
    func clearUnavailableHome(_ newStatus: HomeStatus) {
        generation = UUID(); timeout?.cancel()
        home?.delegate = nil; home?.accessories.forEach { $0.delegate = nil }
        home = nil; selectedHomeID = nil; homes = []; characteristics = [:]; failedReads = []
        tiles = []; cameras = []; scenes = []; busy = []; sceneBusy = false
        notice = nil; error = nil; homeName = "HomeViewPad"; status = newStatus
    }
    func disconnect() {
        generation = UUID(); timeout?.cancel()
        manager?.delegate = nil
        home?.delegate = nil
        home?.accessories.forEach { $0.delegate = nil }
        manager = nil; home = nil; selectedHomeID = nil; homes = []; cameras = []; characteristics = [:]; failedReads = []
        busy = []; sceneBusy = false; tiles = []; scenes = []; error = nil; notice = nil
        UserDefaults.standard.set("welcome", forKey: "homeMode")
        demo = false; status = .welcome; homeName = "HomeViewPad"
    }
    func connect() {
        disconnect(); status = .loading
        UserDefaults.standard.set("live", forKey: "homeMode")
        manager = HMHomeManager(); manager?.delegate = self
        let token = generation
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled, let self, self.generation == token, self.status == .loading else { return }
            self.status = .offline
        }
    }
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) { Task { @MainActor in self.resolve(manager) } }
    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) { Task { @MainActor in self.resolve(manager) } }
    private func resolve(_ manager: HMHomeManager) {
        guard manager === self.manager, !demo else { return }
        if manager.authorizationStatus.contains(.restricted) || (manager.authorizationStatus.contains(.determined) && !manager.authorizationStatus.contains(.authorized)) {
            clearUnavailableHome(.denied); return
        }
        guard manager.authorizationStatus.contains(.authorized) else { return }
        timeout?.cancel(); homes = manager.homes
        let preferredID = home?.uniqueIdentifier ?? UserDefaults.standard.string(forKey: "selectedHomeID").flatMap(UUID.init(uuidString:))
        guard let selected = homes.first(where: { $0.uniqueIdentifier == preferredID }) ?? homes.first else {
            clearUnavailableHome(.empty); return
        }
        select(selected)
    }
    func select(_ selected: HMHome) {
        guard !demo, manager?.authorizationStatus.contains(.authorized) == true,
              homes.contains(where: { $0.uniqueIdentifier == selected.uniqueIdentifier }) else { return }
        generation = UUID(); failedReads = []; busy = []; sceneBusy = false; notice = nil; error = nil
        home?.delegate = nil; home?.accessories.forEach { $0.delegate = nil }
        home = selected; selectedHomeID = selected.uniqueIdentifier; homeName = selected.name; selected.delegate = self
        UserDefaults.standard.set(selected.uniqueIdentifier.uuidString, forKey: "selectedHomeID")
        selected.accessories.forEach { $0.delegate = self }
        refresh(read: true)
    }
    func refresh(read: Bool = true) {
        guard !demo, let home else { return }
        guard manager?.authorizationStatus.contains(.authorized) == true else { clearUnavailableHome(.denied); return }
        let token = generation
        characteristics = [:]
        tiles = home.accessories.flatMap { accessory in
            accessory.services.flatMap { service in
                service.characteristics.compactMap { c -> HomeTile? in
                guard c.properties.contains(HMCharacteristicPropertyReadable), let kind = HomeValueKind(characteristicType: c.characteristicType) else { return nil }
                characteristics[c.uniqueIdentifier] = c
                if read, accessory.isReachable {
                    c.readValue { [weak self] error in Task { @MainActor in
                        guard let self, self.generation == token, !self.demo else { return }
                        if error != nil { self.failedReads.insert(c.uniqueIdentifier) } else { self.failedReads.remove(c.uniqueIdentifier) }
                        self.refresh(read: false)
                    }}
                    if c.properties.contains(HMCharacteristicPropertySupportsEventNotification) { c.enableNotification(true) { _ in } }
                }
                let number = (c.value as? NSNumber)?.doubleValue
                let valid = number?.isFinite == true && !failedReads.contains(c.uniqueIdentifier) && accessory.isReachable
                let isOn = kind == .power && valid && number != 0
                let value: String
                if !accessory.isReachable { value = "Offline" }
                else if failedReads.contains(c.uniqueIdentifier) { value = "Unavailable" }
                else if let number { value = kind.formatted(number) } else { value = "Unavailable" }
                let adjustment = kind.adjustable ? HomeAdjustment(minimum: c.metadata?.minimumValue?.doubleValue, maximum: c.metadata?.maximumValue?.doubleValue, step: c.metadata?.stepValue?.doubleValue) : nil
                let canWrite = valid && c.properties.contains(HMCharacteristicPropertyWritable) && (kind == .power || adjustment != nil)
                var symbol = kind.symbol
                if kind == .power {
                    if service.serviceType == HMServiceTypeLightbulb { symbol = "lightbulb.fill" }
                    else if service.serviceType == HMServiceTypeFan || service.serviceType == HMServiceTypeVentilationFan { symbol = "fan.fill" }
                    else if service.serviceType == HMServiceTypeOutlet { symbol = "powerplug.fill" }
                }
                return HomeTile(id: c.uniqueIdentifier, name: kind == .power ? service.name : "\(service.name) · \(kind.title)", room: accessory.room?.name ?? "Home", symbol: symbol, value: value, isOn: isOn, reachable: accessory.isReachable, writable: canWrite, kind: kind, number: valid ? number : nil, adjustment: adjustment)
                }
            }
        }.sorted { ($0.room, $0.name) < ($1.room, $1.name) }
        scenes = home.actionSets.map(\.name).sorted()
        cameras = home.accessories.filter { !($0.cameraProfiles ?? []).isEmpty }
        status = home.accessories.isEmpty ? .empty : (home.accessories.allSatisfy { !$0.isReachable } ? .offline : .ready)
    }
    func toggle(_ tile: HomeTile) {
        guard let tile = tiles.first(where: { $0.id == tile.id }), tile.kind == .power, tile.writable, tile.reachable, !busy.contains(tile.id) else { return }
        if demo {
            guard let index = tiles.firstIndex(where: { $0.id == tile.id }) else { return }
            tiles[index].isOn.toggle(); tiles[index].value = tiles[index].isOn ? "On" : "Off"; return
        }
        write(!tile.isOn, to: tile)
    }
    func adjust(_ id: UUID, to value: Double) {
        guard let tile = tiles.first(where: { $0.id == id }), tile.kind.adjustable,
              tile.writable, tile.reachable, !busy.contains(id), tile.adjustment?.accepts(value) == true else { return }
        if demo {
            guard let index = tiles.firstIndex(where: { $0.id == id }) else { return }
            tiles[index].number = value; tiles[index].value = tile.kind.formatted(value)
            return
        }
        write(NSNumber(value: value), to: tile)
    }
    private func write(_ value: Any, to tile: HomeTile) {
        guard manager?.authorizationStatus.contains(.authorized) == true, let c = characteristics[tile.id],
              c.service?.accessory?.isReachable == true, c.properties.contains(HMCharacteristicPropertyWritable) else { return }
        error = nil; busy.insert(tile.id); let token = generation
        c.writeValue(value) { [weak self] failure in Task { @MainActor in
            guard let self, self.generation == token else { return }
            if let failure {
                self.busy.remove(tile.id); self.error = failure.localizedDescription; self.refresh(); return
            }
            // Keep the control busy until read-back finishes so a second tap cannot use an old value.
            c.readValue { [weak self] readError in Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.busy.remove(tile.id)
                if let readError {
                    self.failedReads.insert(tile.id)
                    self.error = "The command was sent, but its current state could not be read: \(readError.localizedDescription)"
                } else { self.failedReads.remove(tile.id) }
                self.refresh(read: false)
            } }
        }}
    }
    func runScene(_ name: String) {
        guard !sceneBusy else { return }
        if demo {
            for index in tiles.indices where tiles[index].writable && tiles[index].kind == .power {
                tiles[index].isOn = name != "Good night"; tiles[index].value = tiles[index].isOn ? "On" : "Off"
            }
            notice = "Demo scene: \(name)"; return
        }
        guard manager?.authorizationStatus.contains(.authorized) == true, let scene = home?.actionSets.first(where: { $0.name == name }), let home else { return }
        error = nil; sceneBusy = true; let token = generation
        home.executeActionSet(scene) { [weak self] failure in Task { @MainActor in
            guard let self, self.generation == token else { return }
            self.sceneBusy = false
            if let failure { self.error = failure.localizedDescription } else { self.notice = "Scene completed: \(name)" }
            self.refresh()
        }}
    }
    nonisolated func accessoryDidUpdateReachability(_ accessory: HMAccessory) { Task { @MainActor in self.refresh() } }
    nonisolated func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) { Task { @MainActor in
        guard self.home?.accessories.contains(where: { $0 === accessory }) == true else { return }
        self.failedReads.remove(characteristic.uniqueIdentifier); self.refresh(read: false)
    } }
    nonisolated func accessoryDidUpdateServices(_ accessory: HMAccessory) { Task { @MainActor in self.refresh() } }
    nonisolated func accessoryDidUpdateName(_ accessory: HMAccessory) { Task { @MainActor in self.refresh(read: false) } }
    nonisolated func home(_ home: HMHome, didAdd accessory: HMAccessory) { Task { @MainActor in guard home === self.home else { return }; accessory.delegate = self; self.refresh() } }
    nonisolated func home(_ home: HMHome, didRemove accessory: HMAccessory) { Task { @MainActor in self.refresh() } }
    nonisolated func homeDidUpdateName(_ home: HMHome) { Task { @MainActor in guard home === self.home else { return }; self.homeName = home.name } }
    nonisolated func home(_ home: HMHome, didAdd actionSet: HMActionSet) { Task { @MainActor in self.refresh() } }
    nonisolated func home(_ home: HMHome, didRemove actionSet: HMActionSet) { Task { @MainActor in self.refresh() } }
}

/// Direction locking keeps vertical widget changes from also changing the page.
enum DashboardSwipe {
    case left, right, up, down
    static func classify(x: Double, y: Double) -> DashboardSwipe? {
        guard max(abs(x), abs(y)) >= 50 else { return nil }
        if abs(x) > abs(y) * 1.25 { return x < 0 ? .left : .right }
        if abs(y) > abs(x) * 1.25 { return y < 0 ? .up : .down }
        return nil
    }
}
enum DashboardPage: Int, CaseIterable {
    case overview, home, clock, photos, settings
    var title: String { ["Overview", "Home", "Clock", "Photos", "Settings"][rawValue] }
    var symbol: String { ["square.grid.2x2.fill", "square.grid.2x2", "clock", "photo.on.rectangle.angled", "slider.horizontal.3"][rawValue] }
    func adjacent(forward: Bool) -> DashboardPage {
        DashboardPage(rawValue: min(Self.allCases.count - 1, max(0, rawValue + (forward ? 1 : -1))))!
    }
}

/// Each category belongs to exactly one position in the reference composition.
/// Missing devices have their own placeholders instead of borrowing another stack's content.
enum DashboardWidget: Hashable {
    case climate(UUID), clock, photo, camera, agenda, scene(String), accessory(UUID), empty(Int)
    static func options(for slot: Int, tiles: [HomeTile], scenes: [String]) -> [DashboardWidget] {
        switch slot {
        case 0:
            let climate = tiles.filter { $0.dashboardSlot == 0 }
            let ordered = climate.filter { $0.kind == .targetTemperature } + climate.filter { $0.kind != .targetTemperature }
            return ordered.isEmpty ? [.empty(0)] : ordered.map { .climate($0.id) }
        case 1: return [.clock, .agenda]
        case 2: return [.photo, .camera]
        case 3: return scenes.isEmpty ? [.empty(3)] : scenes.map { .scene($0) }
        default:
            let controls = tiles.filter { $0.dashboardSlot == slot }.map { DashboardWidget.accessory($0.id) }
            return controls.isEmpty ? [.empty(slot)] : controls
        }
    }
}
