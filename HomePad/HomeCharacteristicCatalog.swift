import Foundation
import HomeKit

struct HomeCharacteristicOption: Identifiable, Equatable {
    let value: Double
    let title: String
    var id: Double { value }
}

enum HomeCharacteristicControl: Equatable {
    case readOnly, toggle, range, choice, command
}

/// Semantic presentation is separate from the permissions and metadata of a device.
/// A descriptor never grants write permission; HomeStore also validates the actual
/// characteristic's writable flag, metadata domain and household generation.
struct HomeCharacteristicDefinition {
    let type: String
    let title: String
    let control: HomeCharacteristicControl
    let options: [HomeCharacteristicOption]
    let unit: String?
    let kind: HomeValueKind
    fileprivate var domain: ClosedRange<Double>?
    fileprivate var integerOnly = false
    fileprivate var fractionDigits = 0
    fileprivate var reciprocalKelvin = false

    func accepts(_ value: Double) -> Bool {
        guard value.isFinite else { return false }
        if let domain, !domain.contains(value) { return false }
        if integerOnly, value.rounded() != value { return false }
        if !options.isEmpty, !options.contains(where: { $0.value == value }) { return false }
        return true
    }

    /// State words are localization keys; numbers retain the characteristic's unit.
    /// String information (manufacturer/model/etc.) is displayed as a raw string by
    /// the model and is never interpreted as a numeric control.
    func format(_ value: Double) -> String {
        guard accepts(value) else { return "Unavailable" }
        if let option = options.first(where: { $0.value == value }) { return option.title }
        if reciprocalKelvin { return String(format: "%.0f K", 1_000_000 / value) }
        let number = String(format: "%.*f", fractionDigits, value)
        if let unit, !unit.isEmpty { return unit == "°" ? number + unit : number + " " + unit }
        return number
    }
}

/// Based on Xcode 27's public HMCharacteristicTypes.h / HMCharacteristicDefines.h.
/// Explicit state tables below use those SDK enum values (not truthiness): e.g.
/// contact 0 means closed, a lock's 0 means unlocked, a garage door's 0 means open.
/// No private Home app icon sets, characteristic IDs or command formats are used.
enum HomeCharacteristicCatalog {
    static func definition(for type: String) -> HomeCharacteristicDefinition? { definitionsByType[type] }

    static let allDefinitions: [HomeCharacteristicDefinition] = {
        var definitions: [HomeCharacteristicDefinition] = [
            toggle(HMCharacteristicTypePowerState, "Power", kind: .power, off: "Off", on: "On"),
            numeric(HMCharacteristicTypeCurrentTemperature, "Temperature", kind: .temperature, unit: "°C", digits: 1, domain: -273.15...10000),
            numeric(HMCharacteristicTypeCurrentRelativeHumidity, "Humidity", kind: .humidity, unit: "%", domain: 0...100),
            numeric(HMCharacteristicTypeBrightness, "Brightness", kind: .brightness, control: .range, unit: "%", domain: 0...100, integer: true),
            numeric(HMCharacteristicTypeTargetTemperature, "Target temperature", kind: .targetTemperature, control: .range, unit: "°C", digits: 1, domain: -273.15...10000),
            numeric(HMCharacteristicTypeRotationSpeed, "Fan speed", kind: .fanSpeed, control: .range, unit: "%", domain: 0...100),
            numeric(HMCharacteristicTypeHue, "Hue", kind: .hue, control: .range, unit: "°", domain: 0...360),
            numeric(HMCharacteristicTypeSaturation, "Saturation", kind: .saturation, control: .range, unit: "%", domain: 0...100),
            kelvin(HMCharacteristicTypeColorTemperature),

            // Locks and doors: current state is never confused with requested state.
            states(HMCharacteristicTypeCurrentLockMechanismState, "Lock state", ["Unlocked", "Locked", "Jammed", "Unknown"]),
            states(HMCharacteristicTypeTargetLockMechanismState, "Lock", ["Unlock", "Lock"], control: .choice),
            states(HMCharacteristicTypeLockMechanismLastKnownAction, "Last lock action", [
                "Locked from inside", "Unlocked from inside", "Locked from outside", "Unlocked from outside",
                "Locked with keypad", "Unlocked with keypad", "Locked remotely", "Unlocked remotely",
                "Locked automatically", "Locked manually", "Unlocked manually"
            ]),
            numeric(HMCharacteristicTypeLockManagementAutoSecureTimeout, "Auto-lock delay", kind: .setting, control: .range, unit: "s", domain: 0...Double(UInt32.max), integer: true),
            states(HMCharacteristicTypeCurrentDoorState, "Door state", ["Open", "Closed", "Opening", "Closing", "Stopped"]),
            states(HMCharacteristicTypeTargetDoorState, "Door", ["Open", "Close"], control: .choice),
            numeric(HMCharacteristicTypeCurrentPosition, "Position", unit: "%", domain: 0...100, integer: true),
            numeric(HMCharacteristicTypeTargetPosition, "Target position", kind: .setting, control: .range, unit: "%", domain: 0...100, integer: true),
            states(HMCharacteristicTypePositionState, "Movement", ["Closing", "Opening", "Stopped"]),
            states(HMCharacteristicTypeObstructionDetected, "Obstruction", ["Clear", "Obstructed"]),
            command(HMCharacteristicTypeHoldPosition, "Position control", [(1, "Stop")]),
            numeric(HMCharacteristicTypeCurrentHorizontalTilt, "Horizontal tilt", unit: "°", domain: -90...90),
            numeric(HMCharacteristicTypeTargetHorizontalTilt, "Target horizontal tilt", kind: .setting, control: .range, unit: "°", domain: -90...90),
            numeric(HMCharacteristicTypeCurrentVerticalTilt, "Vertical tilt", unit: "°", domain: -90...90),
            numeric(HMCharacteristicTypeTargetVerticalTilt, "Target vertical tilt", kind: .setting, control: .range, unit: "°", domain: -90...90),
            numeric(HMCharacteristicTypeCurrentTilt, "Tilt", unit: "°", domain: -90...90),
            numeric(HMCharacteristicTypeTargetTilt, "Target tilt", kind: .setting, control: .range, unit: "°", domain: -90...90),
            states(HMCharacteristicTypeCurrentSlatState, "Slat state", ["Stationary", "Jammed", "Oscillating"]),
            states(HMCharacteristicTypeSlatType, "Slat orientation", ["Horizontal", "Vertical"]),

            // Security and dedicated sensors use their own states, not On / Off.
            states(HMCharacteristicTypeCurrentSecuritySystemState, "Security state", ["Armed: home", "Armed: away", "Armed: night", "Disarmed", "Alarm triggered"]),
            states(HMCharacteristicTypeTargetSecuritySystemState, "Security mode", ["Arm: home", "Arm: away", "Arm: night", "Disarm"], control: .choice),
            states(HMCharacteristicTypeSecuritySystemAlarmType, "Alarm", ["No alarm", "Alarm active"]),
            states(HMCharacteristicTypeMotionDetected, "Motion", ["No motion", "Motion detected"]),
            states(HMCharacteristicTypeOccupancyDetected, "Presence", ["No presence", "Presence detected"]),
            states(HMCharacteristicTypeContactState, "Contact", ["Closed", "Open"]),
            states(HMCharacteristicTypeSmokeDetected, "Smoke", ["No smoke", "Smoke detected"]),
            states(HMCharacteristicTypeLeakDetected, "Water leak", ["No leak", "Leak detected"]),
            states(HMCharacteristicTypeCarbonMonoxideDetected, "Carbon monoxide", ["Normal", "Carbon monoxide detected"]),
            states(HMCharacteristicTypeCarbonDioxideDetected, "Carbon dioxide", ["Normal", "Carbon dioxide detected"]),
            numeric(HMCharacteristicTypeCurrentLightLevel, "Illuminance", unit: "lx", digits: 1, domain: 0...Double.greatestFiniteMagnitude),
            states(HMCharacteristicTypeAirQuality, "Air quality", ["Unknown", "Excellent", "Good", "Fair", "Inferior", "Poor"]),
            states(HMCharacteristicTypeAirParticulateSize, "Particle size", ["2.5 µm", "10 µm"]),
            numeric(HMCharacteristicTypeAirParticulateDensity, "Particle density", unit: "µg/m³", digits: 1, domain: 0...Double.greatestFiniteMagnitude),
            numeric(HMCharacteristicTypePM2_5Density, "PM2.5", unit: "µg/m³", digits: 1, domain: 0...Double.greatestFiniteMagnitude),
            numeric(HMCharacteristicTypePM10Density, "PM10", unit: "µg/m³", digits: 1, domain: 0...Double.greatestFiniteMagnitude),
            numeric(HMCharacteristicTypeOzoneDensity, "Ozone", unit: "µg/m³", digits: 1, domain: 0...Double.greatestFiniteMagnitude),
            numeric(HMCharacteristicTypeNitrogenDioxideDensity, "Nitrogen dioxide", unit: "µg/m³", digits: 1, domain: 0...Double.greatestFiniteMagnitude),
            numeric(HMCharacteristicTypeSulphurDioxideDensity, "Sulphur dioxide", unit: "µg/m³", digits: 1, domain: 0...Double.greatestFiniteMagnitude),
            numeric(HMCharacteristicTypeVolatileOrganicCompoundDensity, "Volatile organic compounds", unit: "µg/m³", digits: 1, domain: 0...Double.greatestFiniteMagnitude),
            numeric(HMCharacteristicTypeCarbonDioxideLevel, "Carbon dioxide level", unit: "ppm", digits: 1, domain: 0...Double.greatestFiniteMagnitude),
            numeric(HMCharacteristicTypeCarbonDioxidePeakLevel, "Peak carbon dioxide", unit: "ppm", digits: 1, domain: 0...Double.greatestFiniteMagnitude),
            numeric(HMCharacteristicTypeCarbonMonoxideLevel, "Carbon monoxide level", unit: "ppm", digits: 1, domain: 0...Double.greatestFiniteMagnitude),
            numeric(HMCharacteristicTypeCarbonMonoxidePeakLevel, "Peak carbon monoxide", unit: "ppm", digits: 1, domain: 0...Double.greatestFiniteMagnitude),

            // Active is an enum-backed on/off control used by newer HVAC/valves.
            toggle(HMCharacteristicTypeActive, "Power", kind: .power, off: "Off", on: "On"),
            states(HMCharacteristicTypeCurrentHeatingCooling, "Heating / cooling", ["Off", "Heating", "Cooling"]),
            states(HMCharacteristicTypeTargetHeatingCooling, "Mode", ["Off", "Heat", "Cool", "Automatic"], control: .choice),
            numeric(HMCharacteristicTypeHeatingThreshold, "Heating threshold", kind: .setting, control: .range, unit: "°C", digits: 1, domain: -273.15...10000),
            numeric(HMCharacteristicTypeCoolingThreshold, "Cooling threshold", kind: .setting, control: .range, unit: "°C", digits: 1, domain: -273.15...10000),
            states(HMCharacteristicTypeTemperatureUnits, "Temperature unit", ["Celsius", "Fahrenheit"], control: .choice),
            numeric(HMCharacteristicTypeTargetRelativeHumidity, "Target humidity", kind: .setting, control: .range, unit: "%", domain: 0...100),
            states(HMCharacteristicTypeCurrentFanState, "Fan state", ["Inactive", "Idle", "Blowing air"]),
            states(HMCharacteristicTypeTargetFanState, "Fan mode", ["Manual", "Automatic"], control: .choice),
            states(HMCharacteristicTypeRotationDirection, "Rotation direction", ["Clockwise", "Counterclockwise"], control: .choice),
            states(HMCharacteristicTypeSwingMode, "Oscillation", ["Disabled", "Enabled"], control: .choice),
            states(HMCharacteristicTypeLockPhysicalControls, "Physical controls", ["Unlocked", "Locked"], control: .choice),
            states(HMCharacteristicTypeCurrentHeaterCoolerState, "Heater / cooler state", ["Inactive", "Idle", "Heating", "Cooling"]),
            states(HMCharacteristicTypeTargetHeaterCoolerState, "Heater / cooler mode", ["Automatic", "Heat", "Cool"], control: .choice),
            states(HMCharacteristicTypeCurrentAirPurifierState, "Air purifier state", ["Inactive", "Idle", "Purifying"]),
            states(HMCharacteristicTypeTargetAirPurifierState, "Air purifier mode", ["Manual", "Automatic"], control: .choice),
            states(HMCharacteristicTypeCurrentHumidifierDehumidifierState, "Humidity control state", ["Inactive", "Idle", "Humidifying", "Dehumidifying"]),
            states(HMCharacteristicTypeTargetHumidifierDehumidifierState, "Humidity control mode", ["Automatic", "Humidify", "Dehumidify"], control: .choice),
            numeric(HMCharacteristicTypeHumidifierThreshold, "Humidifying threshold", kind: .setting, control: .range, unit: "%", domain: 0...100),
            numeric(HMCharacteristicTypeDehumidifierThreshold, "Dehumidifying threshold", kind: .setting, control: .range, unit: "%", domain: 0...100),
            numeric(HMCharacteristicTypeWaterLevel, "Water level", unit: "%", domain: 0...100),

            // Valves / irrigation and maintenance.
            states(HMCharacteristicTypeInUse, "Usage", ["Not in use", "In use"]),
            states(HMCharacteristicTypeOutletInUse, "Outlet usage", ["Not in use", "In use"]),
            states(HMCharacteristicTypeProgramMode, "Program", ["Not scheduled", "Scheduled", "Manual override"]),
            states(HMCharacteristicTypeValveType, "Valve type", ["Valve", "Irrigation", "Shower head", "Faucet"]),
            numeric(HMCharacteristicTypeSetDuration, "Duration", kind: .setting, control: .range, unit: "s", domain: 0...Double(Int32.max), integer: true),
            numeric(HMCharacteristicTypeRemainingDuration, "Remaining duration", unit: "s", domain: 0...Double(Int32.max), integer: true),
            numeric(HMCharacteristicTypeBatteryLevel, "Battery", unit: "%", domain: 0...100, integer: true),
            states(HMCharacteristicTypeStatusLowBattery, "Battery status", ["Normal", "Low battery"]),
            states(HMCharacteristicTypeChargingState, "Charging", ["Not charging", "Charging", "Not rechargeable"]),
            numeric(HMCharacteristicTypeFilterLifeLevel, "Filter life", unit: "%", domain: 0...100),
            states(HMCharacteristicTypeFilterChangeIndication, "Filter", ["Replacement not needed", "Replace filter"]),
            command(HMCharacteristicTypeFilterResetChangeIndication, "Filter maintenance", [(1, "Reset filter")]),
            states(HMCharacteristicTypeStatusActive, "Service status", ["Inactive", "Active"]),
            states(HMCharacteristicTypeStatusFault, "Fault", ["No fault", "Fault detected"]),
            states(HMCharacteristicTypeStatusJammed, "Jammed", ["Not jammed", "Jammed"]),
            states(HMCharacteristicTypeStatusTampered, "Tamper", ["No tampering", "Tampering detected"]),
            states(HMCharacteristicTypeIsConfigured, "Configuration", ["Not configured", "Configured"]),
            states(HMCharacteristicTypeOutputState, "Switch state", ["Off", "On"], control: .toggle, kind: .power),
            states(HMCharacteristicTypeInputEvent, "Button event", ["Single press", "Double press", "Long press"], kind: .event),
            states(HMCharacteristicTypeLabelNamespace, "Label style", ["Dots", "Numbers"], kind: .information),
            numeric(HMCharacteristicTypeLabelIndex, "Label index", kind: .information, domain: 1...Double(UInt32.max), integer: true),

            // Public camera controls; stream negotiation remains camera-session owned.
            numeric(HMCharacteristicTypeOpticalZoom, "Optical zoom", kind: .setting, control: .range, unit: "×", digits: 1, domain: 0...Double.greatestFiniteMagnitude),
            numeric(HMCharacteristicTypeDigitalZoom, "Digital zoom", kind: .setting, control: .range, unit: "×", digits: 1, domain: 0...Double.greatestFiniteMagnitude),
            customStates(HMCharacteristicTypeImageRotation, "Image rotation", [(0, "0°"), (90, "90°"), (180, "180°"), (270, "270°")], control: .choice),
            toggle(HMCharacteristicTypeImageMirroring, "Mirror image", off: "Off", on: "On"),
            toggle(HMCharacteristicTypeNightVision, "Night vision", off: "Off", on: "On"),
            numeric(HMCharacteristicTypeVolume, "Volume", kind: .setting, control: .range, unit: "%", domain: 0...100, integer: true),
            toggle(HMCharacteristicTypeMute, "Mute", off: "Sound on", on: "Muted"),
            toggle(HMCharacteristicTypeAudioFeedback, "Audio feedback", off: "Off", on: "On"),
            states(HMCharacteristicTypeAdminOnlyAccess, "Access", ["All home members", "Administrators only"]),
            command(HMCharacteristicTypeIdentify, "Identify", [(1, "Identify accessory")]),

            // Informational strings stay read-only, including names: no implicit rename.
            information(HMCharacteristicTypeName, "Name"),
            information(HMCharacteristicTypeManufacturer, "Manufacturer"),
            information(HMCharacteristicTypeModel, "Model"),
            information(HMCharacteristicTypeSerialNumber, "Serial number"),
            information(HMCharacteristicTypeVersion, "Version"),
            information(HMCharacteristicTypeFirmwareVersion, "Firmware version"),
            information(HMCharacteristicTypeHardwareVersion, "Hardware version"),
            information(HMCharacteristicTypeSoftwareVersion, "Software version")
        ]
        if #available(iOS 18.0, *) {
            definitions += [
                states(HMCharacteristicTypeVolumeControlType, "Volume control", ["None", "Relative", "Relative with current value", "Absolute"]),
                command(HMCharacteristicTypeVolumeSelector, "Volume buttons", [(0, "Volume up"), (1, "Volume down")]),
                states(HMCharacteristicTypeInputSourceType, "Input source type", ["Other", "Home screen", "Tuner", "HDMI", "Composite video", "S-Video", "Component video", "DVI", "AirPlay", "USB", "Application"]),
                states(HMCharacteristicTypeInputDeviceType, "Input device type", ["Other", "TV", "Recording", "Tuner", "Playback", "Audio system", "None"]),
                states(HMCharacteristicTypeClosedCaptions, "Closed captions", ["Disabled", "Enabled"], control: .choice),
                command(HMCharacteristicTypePowerModeSelection, "TV settings", [(0, "Show settings"), (1, "Hide settings")]),
                states(HMCharacteristicTypeCurrentMediaState, "Playback state", ["Playing", "Paused", "Stopped", "Unknown", "Loading", "Interrupted"]),
                command(HMCharacteristicTypeRemoteKey, "Remote", [
                    (0, "Rewind"), (1, "Fast forward"), (2, "Next track"), (3, "Previous track"),
                    (4, "Up"), (5, "Down"), (6, "Left"), (7, "Right"), (8, "Select"),
                    (9, "Back"), (10, "Exit"), (11, "Play / pause"), (12, "Play"), (13, "Pause"),
                    (14, "Menu"), (15, "Info"), (16, "Home")
                ]),
                states(HMCharacteristicTypePictureMode, "Picture mode", ["Standard", "Movie", "Sport", "Game", "Photo", "Vivid", "Dark", "Bright", "Computer", "Night", "Calibrated", "Custom 1", "Custom 2", "Custom 3"], control: .choice),
                information(HMCharacteristicTypeConfiguredName, "Configured name"),
                numeric(HMCharacteristicTypeIdentifier, "Input identifier", kind: .information, domain: 0...Double(UInt32.max), integer: true),
                // Actual input IDs/names come from linked InputSource services. No
                // fabricated list or free numeric slider is supplied for this choice.
                numeric(HMCharacteristicTypeActiveIdentifier, "Input", kind: .setting, control: .choice, domain: 0...Double(UInt32.max), integer: true),
                states(HMCharacteristicTypeTargetVisibilityState, "Input visibility", ["Show", "Hide"], control: .choice),
                states(HMCharacteristicTypeCurrentVisibilityState, "Input visibility state", ["Shown", "Hidden", "Connected", "Always shown"]),
                states(HMCharacteristicTypeTargetMediaState, "Playback", ["Play", "Pause", "Stop"], control: .choice),
                states(HMCharacteristicTypeRouterStatus, "Router status", ["Ready", "Not ready"]),
                states(HMCharacteristicTypeWiFiSatelliteStatus, "Wi-Fi satellite", ["Unknown", "Connected", "Not connected"])
            ]
        }
        return definitions
    }()

    /// These public characteristics are binary management/stream negotiation data,
    /// not dashboard states or arbitrary controls. Camera negotiation uses the
    /// public camera APIs; secret/TLV payloads are not exposed or editable here.
    static let excludedCharacteristicTypes: Set<String> = {
        var types: Set<String> = [
            HMCharacteristicTypeLogs, HMCharacteristicTypeLockManagementControlPoint,
            HMCharacteristicTypeStreamingStatus, HMCharacteristicTypeSetupStreamEndpoint,
            HMCharacteristicTypeSupportedVideoStreamConfiguration, HMCharacteristicTypeSupportedRTPConfiguration,
            HMCharacteristicTypeSelectedStreamConfiguration, HMCharacteristicTypeSupportedAudioStreamConfiguration
        ]
        if #available(iOS 18.0, *) { types.insert(HMCharacteristicTypeWANStatusList) }
        return types
    }()

    private static let definitionsByType = Dictionary(uniqueKeysWithValues: allDefinitions.map { ($0.type, $0) })

    private static func options(_ labels: [String]) -> [HomeCharacteristicOption] {
        labels.enumerated().map { HomeCharacteristicOption(value: Double($0.offset), title: $0.element) }
    }

    private static func states(_ type: String, _ title: String, _ labels: [String], control: HomeCharacteristicControl = .readOnly, kind: HomeValueKind = .state) -> HomeCharacteristicDefinition {
        HomeCharacteristicDefinition(type: type, title: title, control: control, options: options(labels), unit: nil, kind: kind, domain: nil, integerOnly: true)
    }

    private static func customStates(_ type: String, _ title: String, _ values: [(Double, String)], control: HomeCharacteristicControl) -> HomeCharacteristicDefinition {
        HomeCharacteristicDefinition(type: type, title: title, control: control, options: values.map { HomeCharacteristicOption(value: $0.0, title: $0.1) }, unit: nil, kind: .setting, domain: nil, integerOnly: true)
    }

    private static func toggle(_ type: String, _ title: String, kind: HomeValueKind = .setting, off: String, on: String) -> HomeCharacteristicDefinition {
        states(type, title, [off, on], control: .toggle, kind: kind)
    }

    private static func command(_ type: String, _ title: String, _ values: [(Double, String)]) -> HomeCharacteristicDefinition {
        customStates(type, title, values, control: .command)
    }

    private static func numeric(_ type: String, _ title: String, kind: HomeValueKind = .measurement, control: HomeCharacteristicControl = .readOnly, unit: String? = nil, digits: Int = 0, domain: ClosedRange<Double>? = nil, integer: Bool = false) -> HomeCharacteristicDefinition {
        HomeCharacteristicDefinition(type: type, title: title, control: control, options: [], unit: unit, kind: kind, domain: domain, integerOnly: integer, fractionDigits: digits)
    }

    private static func kelvin(_ type: String) -> HomeCharacteristicDefinition {
        var value = numeric(type, "Color temperature", kind: .colorTemperature, control: .range, unit: "K", domain: Double.leastNonzeroMagnitude...Double.greatestFiniteMagnitude, integer: true)
        value.reciprocalKelvin = true
        return value
    }

    private static func information(_ type: String, _ title: String) -> HomeCharacteristicDefinition {
        numeric(type, title, kind: .information)
    }
}
