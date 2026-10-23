import Foundation
import HomeKit

/// Pure discovery boundary: tests exercise real characteristic domains without
/// constructing fake HMCharacteristic objects or contacting a home manager.
struct HomeCharacteristicSnapshot {
    var id: UUID
    var type: String
    var title: String
    var number: Double?
    var text: String? = nil
    var readable = true
    var eventCapable = false
    var writable = false
    var readFailed = false
    var minimum: Double? = nil
    var maximum: Double? = nil
    var step: Double? = nil
    var validValues: [Double]? = nil
    var dynamicOptions: [HomeCharacteristicOption] = []
}

enum HomeTileFactory {
    static func make(_ snapshot: HomeCharacteristicSnapshot, serviceID: UUID, serviceType: String,
                     name: String, room: String, accessoryID: UUID, categoryType: String,
                     reachable: Bool) -> HomeTile? {
        guard !HomeCharacteristicCatalog.excludedCharacteristicTypes.contains(snapshot.type) else { return nil }
        let definition = HomeCharacteristicCatalog.definition(for: snapshot.type)
        guard snapshot.readable || definition?.control == .command || (definition?.kind == .event && snapshot.eventCapable) else { return nil }
        let service = HomeServiceCatalog.definition(for: serviceType, categoryType: categoryType)
        let control = definition?.control ?? .readOnly
        let adjustment = control == .range ? HomeAdjustment(minimum: snapshot.minimum, maximum: snapshot.maximum, step: snapshot.step) : nil
        func inMetadata(_ value: Double) -> Bool {
            value.isFinite && (definition?.accepts(value) ?? true)
                && (snapshot.validValues.map { $0.contains(value) } ?? true)
                && (snapshot.minimum.map { $0.isFinite && value >= $0 } ?? true)
                && (snapshot.maximum.map { $0.isFinite && value <= $0 } ?? true)
        }
        let finite = snapshot.number.flatMap { value in
            inMetadata(value) && (control != .range || adjustment?.accepts(value) != false) ? value : nil
        }
        let number = reachable && !snapshot.readFailed ? finite : nil
        var choices = snapshot.dynamicOptions.isEmpty ? (definition?.options ?? []) : snapshot.dynamicOptions
        if choices.isEmpty, let valid = snapshot.validValues {
            choices = valid.filter { $0.isFinite && (definition?.accepts($0) ?? true) }
                .map { HomeCharacteristicOption(value: $0, title: definition?.format($0) ?? String(format: "%g", $0)) }
        }
        var seen = Set<Double>()
        choices = choices.filter { choice in
            inMetadata(choice.value) && seen.insert(choice.value).inserted
        }
        let isKnown = number != nil && reachable && !snapshot.readFailed
        let usable: Bool
        switch control {
        case .readOnly: usable = false
        case .command: usable = reachable && !choices.isEmpty
        case .toggle: usable = isKnown
        case .choice: usable = isKnown && !choices.isEmpty
        case .range: usable = isKnown && (adjustment != nil || !choices.isEmpty)
        }
        let value: String
        if !reachable { value = "Offline" }
        else if snapshot.readFailed { value = "Unavailable" }
        else if control == .command { value = "Action" }
        else if definition?.kind == .event, snapshot.number == nil { value = "No event received" }
        else if let number { value = choices.first(where: { $0.value == number })?.title ?? definition?.format(number) ?? String(format: "%g", number) }
        else if let text = snapshot.text, !text.isEmpty, control == .readOnly { value = text }
        else { value = "Unavailable" }
        return HomeTile(id: snapshot.id, name: name, room: room, symbol: service.symbol,
                        value: value, isOn: number == 1 && control == .toggle,
                        reachable: reachable, writable: snapshot.writable && usable,
                        kind: definition?.kind ?? .information, number: number, adjustment: adjustment,
                        serviceID: serviceID, accessoryID: accessoryID, serviceType: serviceType,
                        categoryType: categoryType, characteristicType: snapshot.type, customTitle: snapshot.title,
                        allowedValues: snapshot.validValues, permittedOptions: choices)
    }
}

extension HomeTile {
    /// Neutral and alert states remain distinct from an accessory's power state.
    var needsAttention: Bool {
        guard reachable, let number, let type = characteristicType else { return false }
        switch type {
        case HMCharacteristicTypeSmokeDetected, HMCharacteristicTypeLeakDetected,
             HMCharacteristicTypeCarbonMonoxideDetected, HMCharacteristicTypeCarbonDioxideDetected,
             HMCharacteristicTypeStatusFault, HMCharacteristicTypeStatusJammed, HMCharacteristicTypeStatusTampered,
             HMCharacteristicTypeStatusLowBattery, HMCharacteristicTypeFilterChangeIndication, HMCharacteristicTypeObstructionDetected:
            return number != 0
        case HMCharacteristicTypeCurrentLockMechanismState: return number == 0 || number == 2
        case HMCharacteristicTypeCurrentSecuritySystemState: return number == 4
        case HMCharacteristicTypeCurrentSlatState: return number == 1
        case HMCharacteristicTypeAirQuality: return number >= 4
        case HMCharacteristicTypeBatteryLevel: return number <= 20
        default: return false
        }
    }

    var hasActiveState: Bool {
        guard reachable, let number, let type = characteristicType else { return kind == .power && isOn }
        switch type {
        case HMCharacteristicTypePowerState, HMCharacteristicTypeActive, HMCharacteristicTypeMotionDetected,
             HMCharacteristicTypeOccupancyDetected, HMCharacteristicTypeContactState, HMCharacteristicTypeInUse,
             HMCharacteristicTypeOutletInUse: return number == 1
        case HMCharacteristicTypeCurrentPosition: return number > 0
        case HMCharacteristicTypeCurrentDoorState: return number != 1
        default: return false
        }
    }
}
