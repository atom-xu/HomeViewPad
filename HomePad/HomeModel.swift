import Foundation
import HomeKit
import Combine

struct HomeTile: Identifiable, Equatable {
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
    var serviceID: UUID? = nil
    var accessoryID: UUID? = nil
    var serviceType: String? = nil
    var categoryType: String? = nil
    var characteristicType: String? = nil
    var customTitle: String? = nil
    var allowedValues: [Double]? = nil
    var permittedOptions: [HomeCharacteristicOption]? = nil
    var definition: HomeCharacteristicDefinition? { characteristicType.flatMap { HomeCharacteristicCatalog.definition(for: $0) } }
    var control: HomeCharacteristicControl {
        if definition?.control == .range, adjustment == nil, !options.isEmpty { return .choice }
        return definition?.control ?? (kind == .power ? .toggle : kind.adjustable ? .range : .readOnly)
    }
    var controlTitle: String { definition?.title.tr ?? customTitle ?? kind.title }
    var options: [HomeCharacteristicOption] { permittedOptions ?? definition?.options ?? [] }
    var rightColumnOnly: Bool {
        if categoryType == HMAccessoryCategoryTypeIPCamera || categoryType == HMAccessoryCategoryTypeVideoDoorbell { return true }
        guard let serviceType else { return false }
        return HomeServiceCatalog.definition(for: serviceType, categoryType: categoryType).rightColumnOnly
    }
    var quickToggle: Bool { kind == .power || characteristicType == HMCharacteristicTypeActive }
    var displaySymbol: String {
        guard let serviceType else { return symbol }
        return HomeServiceCatalog.symbol(for: HomeServiceCatalog.definition(for: serviceType, categoryType: categoryType), characteristicType: characteristicType, number: number)
    }
    func formatted(_ number: Double) -> String {
        if let option = options.first(where: { $0.value == number }) { return option.title }
        return definition?.format(number) ?? kind.formatted(number)
    }
    func accepts(_ value: Double) -> Bool {
        guard value.isFinite, definition?.accepts(value) ?? true,
              allowedValues.map({ $0.contains(value) }) ?? true else { return false }
        switch control {
        case .readOnly: return false
        case .toggle: return (value == 0 || value == 1) && (definition == nil || options.contains { $0.value == value })
        case .range: return adjustment?.accepts(value) == true
        case .choice, .command: return options.contains { $0.value == value }
        }
    }
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
    case power, temperature, humidity, brightness, targetTemperature, fanSpeed, hue, saturation, colorTemperature
    case state, measurement, setting, information, event
    init?(characteristicType: String) {
        switch characteristicType {
        case HMCharacteristicTypePowerState: self = .power
        case HMCharacteristicTypeCurrentTemperature: self = .temperature
        case HMCharacteristicTypeCurrentRelativeHumidity: self = .humidity
        case HMCharacteristicTypeBrightness: self = .brightness
        case HMCharacteristicTypeTargetTemperature: self = .targetTemperature
        case HMCharacteristicTypeRotationSpeed: self = .fanSpeed
        case HMCharacteristicTypeHue: self = .hue
        case HMCharacteristicTypeSaturation: self = .saturation
        case HMCharacteristicTypeColorTemperature: self = .colorTemperature
        default:
            guard let definition = HomeCharacteristicCatalog.definition(for: characteristicType) else { return nil }
            self = definition.kind
        }
    }
    var title: String {
        switch self {
        case .power: return "Power".tr
        case .temperature: return "Temperature".tr
        case .humidity: return "Humidity".tr
        case .brightness: return "Brightness".tr
        case .targetTemperature: return "Target temperature".tr
        case .fanSpeed: return "Fan speed".tr
        case .hue: return "Hue".tr
        case .saturation: return "Saturation".tr
        case .colorTemperature: return "Color temperature".tr
        case .state: return "State".tr
        case .measurement: return "Reading".tr
        case .setting: return "Setting".tr
        case .information: return "Information".tr
        case .event: return "Last event".tr
        }
    }
    var symbol: String {
        switch self {
        case .power: return "power"
        case .temperature, .targetTemperature: return "thermometer.medium"
        case .humidity: return "humidity.fill"
        case .brightness: return "lightbulb.fill"
        case .fanSpeed: return "fan.fill"
        case .hue, .saturation: return "paintpalette.fill"
        case .colorTemperature: return "sun.max.fill"
        case .state: return "sensor.fill"
        case .measurement: return "gauge.with.dots.needle.50percent"
        case .setting: return "slider.horizontal.3"
        case .information: return "info.circle"
        case .event: return "button.programmable"
        }
    }
    var adjustable: Bool { [.brightness, .targetTemperature, .fanSpeed, .hue, .saturation, .colorTemperature].contains(self) }
    func formatted(_ number: Double) -> String {
        guard number.isFinite else { return "Unavailable" }
        switch self {
        case .power: return number != 0 ? "On" : "Off"
        case .temperature, .targetTemperature: return String(format: "%.1f °C", number)
        case .hue: return String(format: "%.0f°", number)
        case .colorTemperature: return number > 0 ? String(format: "%.0f K", 1_000_000 / number) : "Unavailable"
        case .state, .measurement, .setting, .information, .event: return String(format: "%g", number)
        default: return String(format: "%.0f %%", number)
        }
    }
}

/// A light has one dashboard card; its other characteristics belong in details.
/// Match the HomeKit service, never the display name or room.
enum HomeAccessoryPresentation {
    static func primaryTiles(_ tiles: [HomeTile]) -> [HomeTile] {
        let groups = Dictionary(grouping: tiles.filter { $0.serviceID != nil }, by: { $0.serviceID! })
        let primaryIDs = Set(groups.values.compactMap { group in group.min { priority($0) < priority($1) }?.id })
        let mainAccessories = Set(tiles.filter { tile in
            guard let type = tile.serviceType else { return true }
            let service = HomeServiceCatalog.definition(for: type, categoryType: tile.categoryType)
            return !service.supportService && !service.rightColumnOnly
        }.compactMap(\.accessoryID))
        return tiles.filter { tile in
            guard !tile.rightColumnOnly else { return false }
            if let type = tile.serviceType, let accessory = tile.accessoryID,
               HomeServiceCatalog.definition(for: type, categoryType: tile.categoryType).supportService,
               mainAccessories.contains(accessory) { return false }
            return tile.serviceID == nil || primaryIDs.contains(tile.id)
        }
    }

    private static func priority(_ tile: HomeTile) -> String {
        var preferred: [String] = [HMCharacteristicTypeCurrentLockMechanismState, HMCharacteristicTypeCurrentDoorState,
            HMCharacteristicTypeCurrentPosition, HMCharacteristicTypeCurrentSecuritySystemState,
            HMCharacteristicTypePowerState, HMCharacteristicTypeActive, HMCharacteristicTypeTargetTemperature,
            HMCharacteristicTypeCurrentTemperature, HMCharacteristicTypeCurrentRelativeHumidity,
            HMCharacteristicTypeMotionDetected, HMCharacteristicTypeOccupancyDetected, HMCharacteristicTypeContactState,
            HMCharacteristicTypeSmokeDetected, HMCharacteristicTypeLeakDetected, HMCharacteristicTypeCarbonMonoxideDetected,
            HMCharacteristicTypeCarbonDioxideDetected, HMCharacteristicTypeAirQuality, HMCharacteristicTypeCurrentLightLevel,
            HMCharacteristicTypeBatteryLevel, HMCharacteristicTypeInputEvent]
        if #available(iOS 18.0, *) { preferred.append(HMCharacteristicTypeCurrentMediaState) }
        var signals: [String] = []
        if let type = tile.serviceType {
            switch HomeServiceCatalog.definition(for: type, categoryType: tile.categoryType).family {
            case .thermostat: signals = [HMCharacteristicTypeTargetTemperature, HMCharacteristicTypeCurrentTemperature]
            case .motion: signals = [HMCharacteristicTypeMotionDetected]
            case .occupancy: signals = [HMCharacteristicTypeOccupancyDetected]
            case .contact: signals = [HMCharacteristicTypeContactState]
            case .smoke: signals = [HMCharacteristicTypeSmokeDetected]
            case .leak: signals = [HMCharacteristicTypeLeakDetected]
            case .carbonMonoxide: signals = [HMCharacteristicTypeCarbonMonoxideDetected, HMCharacteristicTypeCarbonMonoxideLevel]
            case .carbonDioxide: signals = [HMCharacteristicTypeCarbonDioxideDetected, HMCharacteristicTypeCarbonDioxideLevel]
            case .airQuality: signals = [HMCharacteristicTypeAirQuality]
            case .lightSensor: signals = [HMCharacteristicTypeCurrentLightLevel]
            case .battery: signals = [HMCharacteristicTypeBatteryLevel]
            default: break
            }
        }
        let index = tile.characteristicType.flatMap { signals.firstIndex(of: $0) }
            ?? tile.characteristicType.flatMap { preferred.firstIndex(of: $0).map { $0 + 10 } }
            ?? (tile.kind == .power ? 4 : tile.kind == .targetTemperature ? 6 : 100)
        return String(format: "%03d", index) + tile.id.uuidString
    }

    static func details(for id: UUID, in tiles: [HomeTile]) -> [HomeTile] {
        guard let selected = tiles.first(where: { $0.id == id }) else { return [] }
        guard let service = selected.serviceID else { return [selected] }
        return tiles.filter { tile in
            if tile.serviceID == service { return true }
            guard let accessory = selected.accessoryID, tile.accessoryID == accessory, let type = tile.serviceType else { return false }
            if selected.rightColumnOnly && tile.rightColumnOnly { return true }
            return [HMServiceTypeAccessoryInformation, HMServiceTypeBattery, HMServiceTypeFilterMaintenance].contains(type)
        }.sorted { lhs, rhs in
            let a = HomeValueKind.allCases.firstIndex(of: lhs.kind) ?? 0
            let b = HomeValueKind.allCases.firstIndex(of: rhs.kind) ?? 0
            return a == b ? lhs.id.uuidString < rhs.id.uuidString : a < b
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
    func snapped(_ value: Double) -> Double {
        guard value.isFinite else { return minimum }
        let count = floor((maximum - minimum) / step + 0.000001)
        let index = min(count, max(0, ((value - minimum) / step).rounded()))
        return minimum + index * step
    }
}
enum HomeStatus: String, CaseIterable {
    case welcome, loading, ready, denied, empty, offline
    var title: String {
        switch self {
        case .welcome: return "A little closer to home.".tr
        case .loading: return "Finding your home…".tr
        case .ready: return "Your home, at a glance.".tr
        case .denied: return "Home access is off".tr
        case .empty: return "Your home starts here".tr
        case .offline: return "Home is taking a moment".tr
        }
    }
    var detail: String {
        switch self {
        case .welcome: return "Connect Apple Home to see your rooms, accessories and scenes. Or explore a clearly labeled demo without sharing anything.".tr
        case .loading: return "Waiting for Apple Home. You can retry or explore the demo.".tr
        case .ready: return "".tr
        case .denied: return "Allow HomePad in Settings → Privacy & Security → HomeKit, then retry.".tr
        case .empty: return "Create a home and add accessories in Apple's Home app, then return here.".tr
        case .offline: return "Check your home Wi-Fi, accessory power and home hub. Retry when you're connected.".tr
        }
    }
}

enum HomeTileUpdates {
    static func replacing(_ updates: [UUID: HomeTile], in tiles: [HomeTile]) -> [HomeTile] {
        guard !updates.isEmpty else { return tiles }
        return tiles.map { updates[$0.id] ?? $0 }
    }
}

/// A fixed window groups a burst without indefinitely postponing updates.
@MainActor final class HomeRefreshScheduler {
    private var pending: Task<Void, Never>?
    private var needsRead = false
    private var generation = UUID()
    func schedule(read: Bool, perform: @escaping @MainActor (Bool) -> Void) {
        needsRead = needsRead || read
        guard pending == nil else { return }
        let token = generation
        pending = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            guard let self, self.generation == token else { return }
            let read = self.needsRead
            self.pending = nil; self.needsRead = false
            perform(read)
        }
    }
    func cancel() {
        generation = UUID(); pending?.cancel(); pending = nil; needsRead = false
    }
}

@MainActor final class HomeStore: NSObject, ObservableObject, HMHomeManagerDelegate, HMHomeDelegate, HMAccessoryDelegate {
    var keepsDashboard: Bool { status == .ready || (status == .offline && (selectedHomeID != nil || !tiles.isEmpty)) }
    @Published var demo = false
    @Published var status: HomeStatus = .welcome
    @Published var tiles: [HomeTile] = [] {
        didSet { primaryTiles = HomeAccessoryPresentation.primaryTiles(tiles) }
    }
    private(set) var primaryTiles: [HomeTile] = []
    @Published var scenes: [String] = []
    @Published var cameras: [HMAccessory] = []
    @Published var homes: [HMHome] = []
    @Published var homeName = "HomePad"
    @Published private(set) var selectedHomeID: UUID?
    @Published var error: String?
    @Published var busy = Set<UUID>()
    @Published var sceneBusy = false
    @Published var notice: String?
    private var manager: HMHomeManager?
    private var home: HMHome?
    private var characteristics: [UUID: HMCharacteristic] = [:]
    private var characteristicContexts: [UUID: (accessory: HMAccessory, service: HMService)] = [:]
    private var pendingValueUpdates = Set<UUID>()
    private var needsStructureRefresh = false
    private var generation = UUID()
    private let refreshScheduler = HomeRefreshScheduler()
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
    #if DEBUG
    func configureControlValidation(offline: Bool) {
        guard demo, status == .ready, !tiles.isEmpty else { return }
        let service = UUID(uuidString: "00000000-0000-0000-0001-000000000001")!
        tiles[0].serviceID = service
        tiles.append(HomeTile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!, name: "Pendant brightness", room: "Kitchen", symbol: "lightbulb.fill", value: "60 %", isOn: false, reachable: true, writable: true, kind: .brightness, number: 60, adjustment: HomeAdjustment(minimum: 0, maximum: 100, step: 1), serviceID: service))
        if offline {
            for index in tiles.indices { tiles[index].reachable = false; tiles[index].writable = false; tiles[index].value = "Offline"; tiles[index].number = nil }
            status = .offline
        }
    }
    #endif
    func clearUnavailableHome(_ newStatus: HomeStatus) {
        refreshScheduler.cancel()
        characteristicContexts = [:]; pendingValueUpdates = []; needsStructureRefresh = false
        generation = UUID(); timeout?.cancel()
        home?.delegate = nil; home?.accessories.forEach { $0.delegate = nil }
        home = nil; selectedHomeID = nil; homes = []; characteristics = [:]; failedReads = []
        tiles = []; cameras = []; scenes = []; busy = []; sceneBusy = false
        notice = nil; error = nil; homeName = "HomePad"; status = newStatus
    }
    func disconnect() {
        refreshScheduler.cancel()
        characteristicContexts = [:]; pendingValueUpdates = []; needsStructureRefresh = false
        generation = UUID(); timeout?.cancel()
        manager?.delegate = nil
        home?.delegate = nil
        home?.accessories.forEach { $0.delegate = nil }
        manager = nil; home = nil; selectedHomeID = nil; homes = []; cameras = []; characteristics = [:]; failedReads = []
        busy = []; sceneBusy = false; tiles = []; scenes = []; error = nil; notice = nil
        UserDefaults.standard.set("welcome", forKey: "homeMode")
        demo = false; status = .welcome; homeName = "HomePad"
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
        refreshScheduler.cancel()
        characteristicContexts = [:]; pendingValueUpdates = []; needsStructureRefresh = false
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
        refreshScheduler.cancel()
        pendingValueUpdates = []; needsStructureRefresh = false
        let token = generation
        characteristics = [:]; characteristicContexts = [:]
        let nextTiles = home.accessories.flatMap { accessory in
            accessory.services.flatMap { service -> [HomeTile] in
                let serviceDefinition = HomeServiceCatalog.definition(for: service.serviceType, categoryType: accessory.category.categoryType)
                let values = service.characteristics.compactMap { c -> HomeTile? in
                    let definition = HomeCharacteristicCatalog.definition(for: c.characteristicType)
                    guard !HomeCharacteristicCatalog.excludedCharacteristicTypes.contains(c.characteristicType),
                          c.properties.contains(HMCharacteristicPropertyReadable) || definition?.control == .command || (definition?.kind == .event && c.properties.contains(HMCharacteristicPropertySupportsEventNotification)),
                          c.value == nil || c.value is NSNumber || c.value is String else { return nil }
                    let snapshot = characteristicSnapshot(c, service: service)
                    guard let tile = HomeTileFactory.make(snapshot, serviceID: service.uniqueIdentifier,
                        serviceType: service.serviceType, name: service.name, room: accessory.room?.name ?? "Home",
                        accessoryID: accessory.uniqueIdentifier, categoryType: accessory.category.categoryType,
                        reachable: accessory.isReachable) else { return nil }
                    characteristics[c.uniqueIdentifier] = c
                    characteristicContexts[c.uniqueIdentifier] = (accessory, service)
                    if read, accessory.isReachable, snapshot.readable {
                        c.readValue { [weak self] error in Task { @MainActor in
                            guard let self, self.generation == token, !self.demo else { return }
                            if error != nil { self.failedReads.insert(c.uniqueIdentifier) } else { self.failedReads.remove(c.uniqueIdentifier) }
                            self.scheduleRefresh(read: false, characteristicID: c.uniqueIdentifier)
                        }}
                    }
                    if read, accessory.isReachable, c.properties.contains(HMCharacteristicPropertySupportsEventNotification) {
                        c.enableNotification(true) { _ in }
                    }
                    return tile
                }
                guard values.isEmpty else { return values }
                // A public service without readable/control values still has an honest
                // type card. Infrastructure never masquerades as a power switch.
                return [HomeTile(id: service.uniqueIdentifier, name: service.name, room: accessory.room?.name ?? "Home",
                    symbol: serviceDefinition.symbol, value: accessory.isReachable ? "No controls exposed" : "Offline",
                    isOn: false, reachable: accessory.isReachable, writable: false, kind: .information,
                    serviceID: service.uniqueIdentifier, accessoryID: accessory.uniqueIdentifier,
                    serviceType: service.serviceType, categoryType: accessory.category.categoryType)]
            }
        }
        // Sorting is a topology operation. Generate UUID strings once, not in
        // every comparison; value readbacks below preserve this stable order.
        let sortedTiles = nextTiles.map { (tile: $0, key: ($0.room, $0.name, $0.id.uuidString)) }
            .sorted { $0.key < $1.key }.map(\.tile)
        if tiles != sortedTiles { tiles = sortedTiles }
        let nextScenes = home.actionSets.map(\.name).sorted()
        if scenes != nextScenes { scenes = nextScenes }
        let nextCameras = home.accessories.filter { !($0.cameraProfiles ?? []).isEmpty }
        if cameras.map(\.uniqueIdentifier) != nextCameras.map(\.uniqueIdentifier) { cameras = nextCameras }
        let nextStatus: HomeStatus = home.accessories.isEmpty ? .empty : (home.accessories.allSatisfy { !$0.isReachable } ? .offline : .ready)
        if status != nextStatus { status = nextStatus }
    }
    private func characteristicSnapshot(_ c: HMCharacteristic, service: HMService) -> HomeCharacteristicSnapshot {
        HomeCharacteristicSnapshot(id: c.uniqueIdentifier, type: c.characteristicType,
            title: c.localizedDescription, number: (c.value as? NSNumber)?.doubleValue, text: c.value as? String,
            readable: c.properties.contains(HMCharacteristicPropertyReadable),
            eventCapable: c.properties.contains(HMCharacteristicPropertySupportsEventNotification),
            writable: c.properties.contains(HMCharacteristicPropertyWritable), readFailed: failedReads.contains(c.uniqueIdentifier),
            minimum: c.metadata?.minimumValue?.doubleValue, maximum: c.metadata?.maximumValue?.doubleValue,
            step: c.metadata?.stepValue?.doubleValue, validValues: c.metadata?.validValues?.map(\.doubleValue),
            dynamicOptions: Self.inputOptions(for: c, service: service))
    }
    private func scheduleRefresh(read: Bool, characteristicID: UUID? = nil) {
        let token = generation
        if let characteristicID, characteristicContexts[characteristicID] != nil { pendingValueUpdates.insert(characteristicID) }
        else { needsStructureRefresh = true }
        refreshScheduler.schedule(read: read) { [weak self] needsRead in
            guard let self, self.generation == token, !self.demo else { return }
            if needsRead || self.needsStructureRefresh { self.refresh(read: needsRead) }
            else { self.applyPendingValueUpdates() }
        }
    }
    private func applyPendingValueUpdates() {
        guard let home, manager?.authorizationStatus.contains(.authorized) == true else {
            clearUnavailableHome(.denied); return
        }
        var ids = pendingValueUpdates; pendingValueUpdates = []
        if #available(iOS 18.0, *) {
            // A television's input selector derives its names/values from
            // linked Input Source services, whose readbacks arrive separately.
            let inputServiceIDs = Set(ids.compactMap { id -> UUID? in
                guard let context = characteristicContexts[id], context.service.serviceType == HMServiceTypeInputSource else { return nil }
                return context.service.uniqueIdentifier
            })
            if !inputServiceIDs.isEmpty {
                for (id, context) in characteristicContexts where characteristics[id]?.characteristicType == HMCharacteristicTypeActiveIdentifier {
                    if (context.service.linkedServices ?? []).contains(where: { inputServiceIDs.contains($0.uniqueIdentifier) }) { ids.insert(id) }
                }
            }
        }
        let currentAccessoryIDs = Set(home.accessories.map(\.uniqueIdentifier))
        var updated: [UUID: HomeTile] = [:]
        for id in ids {
            guard let c = characteristics[id], let context = characteristicContexts[id] else { continue }
            let accessory = context.accessory, service = context.service
            guard currentAccessoryIDs.contains(accessory.uniqueIdentifier),
                  c.value == nil || c.value is NSNumber || c.value is String,
                  let tile = HomeTileFactory.make(characteristicSnapshot(c, service: service),
                      serviceID: service.uniqueIdentifier, serviceType: service.serviceType,
                      name: service.name, room: accessory.room?.name ?? "Home",
                      accessoryID: accessory.uniqueIdentifier, categoryType: accessory.category.categoryType,
                      reachable: accessory.isReachable) else {
                refresh(read: false); return
            }
            updated[id] = tile
        }
        // Readback does not rename/reorder services or re-enumerate the house.
        // Publish at most one changed array for this batch.
        let next = HomeTileUpdates.replacing(updated, in: tiles)
        if next != tiles { tiles = next }
    }
    private static func inputOptions(for characteristic: HMCharacteristic, service: HMService) -> [HomeCharacteristicOption] {
        guard #available(iOS 18.0, *), characteristic.characteristicType == HMCharacteristicTypeActiveIdentifier else { return [] }
        return (service.linkedServices ?? []).filter { $0.serviceType == HMServiceTypeInputSource }.compactMap { input in
            guard let number = input.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeIdentifier })?.value as? NSNumber else { return nil }
            let name = input.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeConfiguredName })?.value as? String
            return HomeCharacteristicOption(value: number.doubleValue, title: name ?? input.name)
        }.sorted { $0.value < $1.value }
    }
    func quickToggle(for tile: HomeTile) -> HomeTile? {
        if let type = tile.serviceType {
            let family = HomeServiceCatalog.definition(for: type, categoryType: tile.categoryType).family
            guard [.light, .switchDevice, .outlet, .fan, .thermostat, .heaterCooler, .humidifier,
                   .airPurifier, .valve, .faucet, .irrigation, .speaker, .microphone, .television,
                   .programmableSwitch, .other].contains(family) else { return nil }
        }
        let values = HomeAccessoryPresentation.details(for: tile.id, in: tiles)
        return values.first { $0.kind == .power } ?? values.first { $0.characteristicType == HMCharacteristicTypeActive }
    }
    func canToggle(_ tile: HomeTile) -> Bool {
        tile.control == .toggle && tile.writable && tile.reachable && !busy.contains(tile.id)
            && tile.accepts(tile.isOn ? 0 : 1)
    }
    func toggle(_ tile: HomeTile) {
        guard let current = tiles.first(where: { $0.id == tile.id }), canToggle(current) else { return }
        setValue(current.id, to: current.isOn ? 0 : 1)
    }
    func adjust(_ id: UUID, to value: Double) {
        guard let tile = tiles.first(where: { $0.id == id }), tile.control == .range else { return }
        setValue(id, to: value)
    }
    func setValue(_ id: UUID, to value: Double) {
        guard let tile = tiles.first(where: { $0.id == id }), tile.writable, tile.reachable,
              !busy.contains(id), tile.accepts(value) else { return }
        if demo {
            guard let index = tiles.firstIndex(where: { $0.id == id }) else { return }
            if tile.control == .command { notice = "Demo action sent".tr; return }
            tiles[index].number = value
            tiles[index].isOn = tile.control == .toggle && value == 1
            tiles[index].value = tile.formatted(value)
            updateDemoCurrentState(for: tile, value: value)
            return
        }
        write(tile.control == .toggle ? NSNumber(value: value == 1) : NSNumber(value: value), to: tile)
    }
    private func updateDemoCurrentState(for tile: HomeTile, value: Double) {
        let pairs = [HMCharacteristicTypeTargetLockMechanismState: HMCharacteristicTypeCurrentLockMechanismState,
            HMCharacteristicTypeTargetDoorState: HMCharacteristicTypeCurrentDoorState,
            HMCharacteristicTypeTargetPosition: HMCharacteristicTypeCurrentPosition,
            HMCharacteristicTypeTargetSecuritySystemState: HMCharacteristicTypeCurrentSecuritySystemState]
        guard let type = tile.characteristicType, let current = pairs[type], let service = tile.serviceID else { return }
        for index in tiles.indices where tiles[index].serviceID == service && tiles[index].characteristicType == current {
            tiles[index].number = value; tiles[index].value = tiles[index].formatted(value)
        }
    }
    private func write(_ value: Any, to tile: HomeTile) {
        guard manager?.authorizationStatus.contains(.authorized) == true, let c = characteristics[tile.id],
              c.service?.accessory?.isReachable == true, c.properties.contains(HMCharacteristicPropertyWritable) else { return }
        error = nil; notice = nil; busy.insert(tile.id); let token = generation
        let payload: Any
        if c.metadata?.format == HMCharacteristicMetadataFormatBool, let number = value as? NSNumber {
            payload = NSNumber(value: number.boolValue)
        } else { payload = value }
        c.writeValue(payload) { [weak self] failure in Task { @MainActor in
            guard let self, self.generation == token else { return }
            if let failure {
                self.busy.remove(tile.id); self.error = failure.localizedDescription; self.refresh(); return
            }
            guard c.properties.contains(HMCharacteristicPropertyReadable) else {
                self.busy.remove(tile.id)
                self.notice = "Command sent. Waiting for the accessory state.".tr
                self.refresh(read: true)
                return
            }
            // Keep the control busy until read-back finishes so a second tap cannot use an old value.
            c.readValue { [weak self] readError in Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.busy.remove(tile.id)
                if let readError {
                    self.failedReads.insert(tile.id)
                    self.error = L10n.format("The command was sent, but its current state could not be read: %@", readError.localizedDescription)
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
                if tiles[index].number != nil { tiles[index].number = tiles[index].isOn ? 1 : 0 }
            }
            notice = L10n.format("Demo scene: %@", name.tr); return
        }
        guard manager?.authorizationStatus.contains(.authorized) == true, let scene = home?.actionSets.first(where: { $0.name == name }), let home else { return }
        error = nil; sceneBusy = true; let token = generation
        home.executeActionSet(scene) { [weak self] failure in Task { @MainActor in
            guard let self, self.generation == token else { return }
            self.sceneBusy = false
            if let failure { self.error = failure.localizedDescription } else { self.notice = L10n.format("Scene completed: %@", name) }
            self.refresh()
        }}
    }
    nonisolated func accessoryDidUpdateReachability(_ accessory: HMAccessory) { Task { @MainActor in
        guard self.home?.accessories.contains(where: { $0 === accessory }) == true else { return }
        self.scheduleRefresh(read: true)
    } }
    nonisolated func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) { Task { @MainActor in
        guard self.home?.accessories.contains(where: { $0 === accessory }) == true else { return }
        self.failedReads.remove(characteristic.uniqueIdentifier); self.scheduleRefresh(read: false, characteristicID: characteristic.uniqueIdentifier)
    } }
    nonisolated func accessoryDidUpdateServices(_ accessory: HMAccessory) { Task { @MainActor in
        guard self.home?.accessories.contains(where: { $0 === accessory }) == true else { return }
        self.scheduleRefresh(read: true)
    } }
    nonisolated func accessoryDidUpdateName(_ accessory: HMAccessory) { Task { @MainActor in
        guard self.home?.accessories.contains(where: { $0 === accessory }) == true else { return }
        self.scheduleRefresh(read: false)
    } }
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
    case overview, home, clock, photos, settings, music
    // Preserve saved/test page identifiers while placing Music before Settings.
    static let allCases: [DashboardPage] = [.overview, .home, .clock, .photos, .music, .settings]
    var position: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    var title: String { ["Overview", "Home", "Clock", "Photos", "Settings", "Music"][rawValue].tr }
    var symbol: String { ["square.grid.2x2.fill", "square.grid.2x2", "clock", "photo.on.rectangle.angled", "slider.horizontal.3", "music.note"][rawValue] }
    func adjacent(forward: Bool) -> DashboardPage {
        Self.allCases[min(Self.allCases.count - 1, max(0, position + (forward ? 1 : -1)))]
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
        case 1: return [.clock]
        case 2: return [.empty(2)]
        case 3: return scenes.isEmpty ? [.empty(3)] : scenes.map { .scene($0) }
        default:
            let controls = tiles.filter { $0.dashboardSlot == slot }.map { DashboardWidget.accessory($0.id) }
            return controls.isEmpty ? [.empty(slot)] : controls
        }
    }
}
