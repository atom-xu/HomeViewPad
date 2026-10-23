import Foundation
import HomeKit

/// Public HomeKit service identity is separate from the accessory's category.
/// The SF Symbols below describe a device without importing Apple's private Home artwork.
enum HomeServiceFamily: String {
    case light, switchDevice, outlet, fan, thermostat, heaterCooler, humidifier, airPurifier
    case lock, door, window, windowCovering, slats, garage, security
    case sensor, motion, occupancy, contact, smoke, leak, airQuality, carbonMonoxide, carbonDioxide, lightSensor
    case battery, valve, faucet, irrigation, programmableSwitch, speaker, microphone, television, inputSource
    case camera, doorbell, bridge, router, accessoryInformation, filterMaintenance, other
}

struct HomeServiceDefinition: Equatable {
    let type: String
    let title: String
    let family: HomeServiceFamily
    let symbol: String
    let supportService: Bool
    let rightColumnOnly: Bool

    init(type: String, title: String, family: HomeServiceFamily, symbol: String,
         supportService: Bool = false, rightColumnOnly: Bool = false) {
        self.type = type; self.title = title; self.family = family; self.symbol = symbol
        self.supportService = supportService; self.rightColumnOnly = rightColumnOnly
    }
}

enum HomeServiceCatalog {
    /// Every service exported by Xcode 27's public HMServiceTypes.h is represented.
    /// iOS 18 additions are appended only on systems where those API constants exist.
    static let allServices: [HomeServiceDefinition] = {
        var result = [
            service(HMServiceTypeSwitch, "Switch", .switchDevice, "switch.2"),
            service(HMServiceTypeThermostat, "Thermostat", .thermostat, "thermometer.medium"),
            service(HMServiceTypeOutlet, "Outlet", .outlet, "powerplug.fill"),
            service(HMServiceTypeLockManagement, "Lock settings", .lock, "key.fill", support: true),
            service(HMServiceTypeAirQualitySensor, "Air quality", .airQuality, "aqi.medium"),
            service(HMServiceTypeCarbonDioxideSensor, "Carbon dioxide sensor", .carbonDioxide, "carbon.dioxide.cloud.fill"),
            service(HMServiceTypeCarbonMonoxideSensor, "Carbon monoxide sensor", .carbonMonoxide, "carbon.monoxide.cloud.fill"),
            service(HMServiceTypeContactSensor, "Contact sensor", .contact, "door.left.hand.closed"),
            service(HMServiceTypeDoor, "Door", .door, "door.left.hand.closed"),
            service(HMServiceTypeHumiditySensor, "Humidity sensor", .sensor, "humidity.fill"),
            service(HMServiceTypeLeakSensor, "Leak sensor", .leak, "drop.fill"),
            service(HMServiceTypeLightSensor, "Light sensor", .lightSensor, "sun.max.fill"),
            service(HMServiceTypeMotionSensor, "Motion sensor", .motion, "figure.walk"),
            service(HMServiceTypeOccupancySensor, "Occupancy sensor", .occupancy, "person.fill"),
            service(HMServiceTypeSecuritySystem, "Security system", .security, "shield.fill"),
            service(HMServiceTypeStatefulProgrammableSwitch, "Programmable switch", .programmableSwitch, "switch.2"),
            service(HMServiceTypeStatelessProgrammableSwitch, "Programmable button", .programmableSwitch, "hand.tap.fill"),
            service(HMServiceTypeSmokeSensor, "Smoke sensor", .smoke, "smoke.fill"),
            service(HMServiceTypeTemperatureSensor, "Temperature sensor", .sensor, "thermometer.medium"),
            service(HMServiceTypeWindow, "Window", .window, "window.vertical.closed"),
            service(HMServiceTypeWindowCovering, "Window covering", .windowCovering, "window.shade.closed"),
            service(HMServiceTypeCameraRTPStreamManagement, "Camera stream", .camera, "video.fill", support: true, rightOnly: true),
            service(HMServiceTypeCameraControl, "Camera", .camera, "video.fill", support: true, rightOnly: true),
            service(HMServiceTypeMicrophone, "Microphone", .microphone, "mic.fill", support: true),
            service(HMServiceTypeSpeaker, "Speaker", .speaker, "hifispeaker.fill"),
            service(HMServiceTypeAirPurifier, "Air purifier", .airPurifier, "air.purifier.fill"),
            service(HMServiceTypeFilterMaintenance, "Filter", .filterMaintenance, "line.3.horizontal.decrease.circle", support: true),
            service(HMServiceTypeSlats, "Slats", .slats, "window.horizontal"),
            service(HMServiceTypeLabel, "Service label", .accessoryInformation, "tag.fill", support: true),
            service(HMServiceTypeIrrigationSystem, "Irrigation system", .irrigation, "sprinkler.and.droplets.fill"),
            service(HMServiceTypeValve, "Valve", .valve, "spigot.fill"),
            service(HMServiceTypeFaucet, "Faucet", .faucet, "spigot.fill"),
            service(HMServiceTypeAccessoryInformation, "Accessory information", .accessoryInformation, "info.circle", support: true),
            service(HMServiceTypeFan, "Fan", .fan, "fan.fill"),
            service(HMServiceTypeGarageDoorOpener, "Garage door", .garage, "door.garage.closed"),
            service(HMServiceTypeLightbulb, "Light", .light, "lightbulb.fill"),
            service(HMServiceTypeLockMechanism, "Door lock", .lock, "key.fill"),
            service(HMServiceTypeBattery, "Battery", .battery, "battery.100", support: true),
            service(HMServiceTypeVentilationFan, "Ventilation fan", .fan, "fan.fill"),
            service(HMServiceTypeHeaterCooler, "Heater and cooler", .heaterCooler, "air.conditioner.horizontal.fill"),
            service(HMServiceTypeHumidifierDehumidifier, "Humidifier and dehumidifier", .humidifier, "humidifier.fill"),
            service(HMServiceTypeDoorbell, "Doorbell", .doorbell, "video.doorbell.fill", rightOnly: true)
        ]
        if #available(iOS 18, *) {
            result += [
                service(HMServiceTypeTelevision, "Television", .television, "tv.fill"),
                service(HMServiceTypeInputSource, "Input source", .inputSource, "rectangle.connected.to.line.below", support: true),
                service(HMServiceTypeWiFiRouter, "Wi-Fi router", .router, "wifi.router.fill"),
                service(HMServiceTypeWiFiSatellite, "Wi-Fi satellite", .router, "wifi.router.fill")
            ]
        }
        return result
    }()

    /// Every accessory category exported by the public Xcode 27 SDK.
    static let allCategories: [HomeServiceDefinition] = {
        var result = [
            service(HMAccessoryCategoryTypeOther, "Accessory", .other, "square.grid.2x2.fill"),
            service(HMAccessoryCategoryTypeSecuritySystem, "Security system", .security, "shield.fill"),
            service(HMAccessoryCategoryTypeBridge, "Bridge", .bridge, "network"),
            service(HMAccessoryCategoryTypeDoor, "Door", .door, "door.left.hand.closed"),
            service(HMAccessoryCategoryTypeDoorLock, "Door lock", .lock, "key.fill"),
            service(HMAccessoryCategoryTypeFan, "Fan", .fan, "fan.fill"),
            service(HMAccessoryCategoryTypeGarageDoorOpener, "Garage door", .garage, "door.garage.closed"),
            service(HMAccessoryCategoryTypeIPCamera, "Camera", .camera, "video.fill", rightOnly: true),
            service(HMAccessoryCategoryTypeLightbulb, "Light", .light, "lightbulb.fill"),
            service(HMAccessoryCategoryTypeOutlet, "Outlet", .outlet, "powerplug.fill"),
            service(HMAccessoryCategoryTypeProgrammableSwitch, "Programmable switch", .programmableSwitch, "switch.2"),
            service(HMAccessoryCategoryTypeRangeExtender, "Range extender", .router, "wifi.router.fill"),
            service(HMAccessoryCategoryTypeSensor, "Sensor", .sensor, "sensor.fill"),
            service(HMAccessoryCategoryTypeSwitch, "Switch", .switchDevice, "switch.2"),
            service(HMAccessoryCategoryTypeThermostat, "Thermostat", .thermostat, "thermometer.medium"),
            service(HMAccessoryCategoryTypeVideoDoorbell, "Video doorbell", .doorbell, "video.doorbell.fill", rightOnly: true),
            service(HMAccessoryCategoryTypeWindow, "Window", .window, "window.vertical.closed"),
            service(HMAccessoryCategoryTypeWindowCovering, "Window covering", .windowCovering, "window.shade.closed"),
            service(HMAccessoryCategoryTypeAirPurifier, "Air purifier", .airPurifier, "air.purifier.fill"),
            service(HMAccessoryCategoryTypeAirHeater, "Heater", .heaterCooler, "heater.vertical.fill"),
            service(HMAccessoryCategoryTypeAirConditioner, "Air conditioner", .heaterCooler, "air.conditioner.horizontal.fill"),
            service(HMAccessoryCategoryTypeAirHumidifier, "Humidifier", .humidifier, "humidifier.fill"),
            service(HMAccessoryCategoryTypeAirDehumidifier, "Dehumidifier", .humidifier, "dehumidifier.fill"),
            service(HMAccessoryCategoryTypeSprinkler, "Sprinkler", .irrigation, "sprinkler.and.droplets.fill"),
            service(HMAccessoryCategoryTypeFaucet, "Faucet", .faucet, "spigot.fill"),
            service(HMAccessoryCategoryTypeShowerHead, "Shower", .faucet, "shower.fill")
        ]
        if #available(iOS 18, *) {
            result += [
                service(HMAccessoryCategoryTypeTelevision, "Television", .television, "tv.fill"),
                service(HMAccessoryCategoryTypeTelevisionSetTopBox, "Set-top box", .television, "tv.and.mediabox.fill"),
                service(HMAccessoryCategoryTypeTelevisionStreamingStick, "Streaming device", .television, "tv.fill"),
                service(HMAccessoryCategoryTypeWiFiRouter, "Wi-Fi router", .router, "wifi.router.fill"),
                service(HMAccessoryCategoryTypeSpeaker, "Speaker", .speaker, "hifispeaker.fill"),
                service(HMAccessoryCategoryTypeAudioReceiver, "Audio receiver", .speaker, "hifispeaker.2.fill"),
                service(HMAccessoryCategoryTypeAirPort, "AirPort", .router, "wifi.router.fill")
            ]
        }
        return result
    }()

    static var categorySymbols: [String: String] {
        Dictionary(uniqueKeysWithValues: allCategories.map { ($0.type, $0.symbol) })
    }
    private static let serviceLookup = Dictionary(uniqueKeysWithValues: allServices.map { ($0.type, $0) })
    private static let categoryLookup = Dictionary(uniqueKeysWithValues: allCategories.map { ($0.type, $0) })

    static func definition(for serviceType: String, categoryType: String? = nil) -> HomeServiceDefinition {
        if let known = serviceLookup[serviceType] {
            // Camera microphones/speakers belong to the existing right-column camera surface.
            if isCameraCategory(categoryType), known.family == .speaker || known.family == .microphone {
                return HomeServiceDefinition(type: known.type, title: known.title, family: known.family,
                                             symbol: known.symbol, supportService: true, rightColumnOnly: true)
            }
            if serviceType == HMServiceTypeAccessoryInformation,
               let categoryType, let category = categoryLookup[categoryType] {
                // When no primary service is exposed, the remaining information card
                // keeps the actual accessory form (e.g. bridge/router), not a power glyph.
                return HomeServiceDefinition(type: known.type, title: known.title, family: known.family,
                                             symbol: category.symbol, supportService: true,
                                             rightColumnOnly: category.rightColumnOnly)
            }
            if let categoryType, let category = categoryLookup[categoryType],
               category.family == known.family || (known.family == .valve && category.family == .faucet) {
                // A shared heater/cooler or humidifier service can still have a precise accessory form.
                // This affects its glyph only; capability/write decisions never follow category alone.
                return HomeServiceDefinition(type: known.type, title: known.title, family: known.family,
                                             symbol: category.symbol, supportService: known.supportService,
                                             rightColumnOnly: known.rightColumnOnly)
            }
            return known
        }
        if let categoryType, let category = categoryLookup[categoryType] {
            return HomeServiceDefinition(type: serviceType, title: category.title, family: category.family,
                                         symbol: category.symbol, rightColumnOnly: category.rightColumnOnly)
        }
        return HomeServiceDefinition(type: serviceType, title: "Accessory", family: .other, symbol: "square.grid.2x2.fill")
    }

    /// Changes the glyph only for actual reported states, never guessed targets or non-finite values.
    /// Target characteristics keep a category glyph; a target is not evidence of physical state.
    static func symbol(for service: HomeServiceDefinition, characteristicType: String?, number: Double?) -> String {
        guard let type = characteristicType else { return service.symbol }
        if type == HMCharacteristicTypeCurrentLockMechanismState {
            switch integer(number) {
            case 0: return "lock.open.fill"
            case 1: return "lock.fill"
            case 2: return "exclamationmark.triangle.fill"
            default: return "questionmark.circle"
            }
        }
        if type == HMCharacteristicTypeCurrentDoorState {
            switch integer(number) {
            case 0, 2, 3, 4: return service.family == .garage ? "door.garage.open" : "door.left.hand.open"
            case 1: return service.family == .garage ? "door.garage.closed" : "door.left.hand.closed"
            default: return "questionmark.circle"
            }
        }
        if type == HMCharacteristicTypeCurrentPosition {
            guard let number, number.isFinite, (0...100).contains(number) else { return "questionmark.circle" }
            switch service.family {
            case .windowCovering, .slats: return number == 0 ? "window.shade.closed" : "window.shade.open"
            case .window: return number == 0 ? "window.vertical.closed" : "window.vertical.open"
            case .garage: return number == 0 ? "door.garage.closed" : "door.garage.open"
            default: return number == 0 ? "door.left.hand.closed" : "door.left.hand.open"
            }
        }
        if type == HMCharacteristicTypeContactState {
            switch integer(number) {
            case 0: return "door.left.hand.closed"
            case 1: return "door.left.hand.open"
            default: return "questionmark.circle"
            }
        }
        if type == HMCharacteristicTypeCurrentSecuritySystemState {
            switch integer(number) {
            case 0: return "house.fill"
            case 1: return "shield.fill"
            case 2: return "moon.fill"
            case 3: return "shield.slash.fill"
            case 4: return "exclamationmark.triangle.fill"
            default: return "questionmark.circle"
            }
        }
        if type == HMCharacteristicTypeMotionDetected {
            switch integer(number) {
            case 0: return "figure.stand"
            case 1: return "figure.walk"
            default: return "questionmark.circle"
            }
        }
        if type == HMCharacteristicTypeOccupancyDetected {
            switch integer(number) {
            case 0: return "person"
            case 1: return "person.fill"
            default: return "questionmark.circle"
            }
        }
        if [HMCharacteristicTypeSmokeDetected, HMCharacteristicTypeLeakDetected,
            HMCharacteristicTypeCarbonMonoxideDetected, HMCharacteristicTypeCarbonDioxideDetected].contains(type) {
            guard let state = integer(number), state == 0 || state == 1 else { return "questionmark.circle" }
            if type == HMCharacteristicTypeSmokeDetected { return state == 0 ? "smoke" : "smoke.fill" }
            if type == HMCharacteristicTypeLeakDetected { return state == 0 ? "drop" : "drop.fill" }
            if type == HMCharacteristicTypeCarbonMonoxideDetected { return state == 0 ? "carbon.monoxide.cloud" : "carbon.monoxide.cloud.fill" }
            return state == 0 ? "carbon.dioxide.cloud" : "carbon.dioxide.cloud.fill"
        }
        if type == HMCharacteristicTypeAirQuality {
            switch integer(number) {
            case 1, 2: return "aqi.low"
            case 3: return "aqi.medium"
            case 4, 5: return "aqi.high"
            default: return "questionmark.circle"
            }
        }
        if type == HMCharacteristicTypeBatteryLevel {
            guard let number, number.isFinite, (0...100).contains(number) else { return "questionmark.circle" }
            if number == 0 { return "battery.0" }
            if number <= 25 { return "battery.25" }
            if number <= 50 { return "battery.50" }
            if number <= 75 { return "battery.75" }
            return "battery.100"
        }
        if type == HMCharacteristicTypeMute {
            switch integer(number) {
            case 0: return "speaker.wave.2.fill"
            case 1: return "speaker.slash.fill"
            default: return "questionmark.circle"
            }
        }
        if #available(iOS 18, *), type == HMCharacteristicTypeCurrentMediaState {
            switch integer(number) {
            case 0: return "play.fill"
            case 1: return "pause.fill"
            case 2: return "stop.fill"
            case 4: return "arrow.triangle.2.circlepath"
            case 5: return "exclamationmark.triangle.fill"
            default: return "questionmark.circle"
            }
        }
        return service.symbol
    }

    private static func integer(_ value: Double?) -> Int? {
        guard let value, value.isFinite, value >= 0, value <= 100, value.rounded() == value else { return nil }
        return Int(value)
    }
    private static func isCameraCategory(_ type: String?) -> Bool {
        type == HMAccessoryCategoryTypeIPCamera || type == HMAccessoryCategoryTypeVideoDoorbell
    }
    private static func service(_ type: String, _ title: String, _ family: HomeServiceFamily, _ symbol: String,
                                support: Bool = false, rightOnly: Bool = false) -> HomeServiceDefinition {
        HomeServiceDefinition(type: type, title: title, family: family, symbol: symbol,
                              supportService: support, rightColumnOnly: rightOnly)
    }
}
