import XCTest
import HomeKit
@testable import HomePad

final class HomeCharacteristicCatalogTests: XCTestCase {
    private func definition(_ type: String, file: StaticString = #filePath, line: UInt = #line) throws -> HomeCharacteristicDefinition {
        try XCTUnwrap(HomeCharacteristicCatalog.definition(for: type), file: file, line: line)
    }

    func testRegistryHasUniqueDefinitionsAndNoBinaryManagementControls() {
        let values = HomeCharacteristicCatalog.allDefinitions
        XCTAssertEqual(Set(values.map(\.type)).count, values.count)
        XCTAssertTrue(Set(values.map(\.type)).isDisjoint(with: HomeCharacteristicCatalog.excludedCharacteristicTypes))
        for type in HomeCharacteristicCatalog.excludedCharacteristicTypes {
            XCTAssertNil(HomeCharacteristicCatalog.definition(for: type))
        }
        for value in values {
            XCTAssertFalse(value.title.isEmpty)
            XCTAssertEqual(Set(value.options.map(\.value)).count, value.options.count, value.title)
            for option in value.options {
                XCTAssertFalse(option.title.isEmpty, value.title)
                XCTAssertTrue(value.accepts(option.value), value.title)
                XCTAssertEqual(value.format(option.value), option.title, value.title)
            }
            XCTAssertFalse(value.accepts(.nan), value.title)
            XCTAssertFalse(value.accepts(.infinity), value.title)
            XCTAssertEqual(value.format(.nan), "Unavailable", value.title)
        }
        XCTAssertNil(HomeCharacteristicCatalog.definition(for: "vendor-private-characteristic"))
    }

    func testLockAndDoorEnumsDoNotUseBooleanTruthiness() throws {
        let lock = try definition(HMCharacteristicTypeCurrentLockMechanismState)
        XCTAssertEqual(lock.control, .readOnly)
        XCTAssertEqual(lock.format(0), "Unlocked")
        XCTAssertEqual(lock.format(1), "Locked")
        XCTAssertEqual(lock.format(2), "Jammed")
        XCTAssertEqual(lock.format(3), "Unknown")
        XCTAssertEqual(lock.format(4), "Unavailable")
        XCTAssertEqual(lock.format(0.5), "Unavailable")
        let targetLock = try definition(HMCharacteristicTypeTargetLockMechanismState)
        XCTAssertEqual(targetLock.control, .choice)
        XCTAssertEqual(targetLock.options.map(\.value), [0, 1])
        XCTAssertFalse(targetLock.accepts(2))

        let door = try definition(HMCharacteristicTypeCurrentDoorState)
        XCTAssertEqual(door.format(0), "Open")
        XCTAssertEqual(door.format(1), "Closed")
        XCTAssertEqual(door.format(2), "Opening")
        XCTAssertEqual(door.format(3), "Closing")
        XCTAssertEqual(door.format(4), "Stopped")
        let targetDoor = try definition(HMCharacteristicTypeTargetDoorState)
        XCTAssertEqual(targetDoor.options.map(\.title), ["Open", "Close"])
        XCTAssertFalse(targetDoor.accepts(2))
    }

    func testDedicatedDetectionStatesRemainReadOnly() throws {
        let tests: [(String, String, String)] = [
            (HMCharacteristicTypeContactState, "Closed", "Open"),
            (HMCharacteristicTypeMotionDetected, "No motion", "Motion detected"),
            (HMCharacteristicTypeOccupancyDetected, "No presence", "Presence detected"),
            (HMCharacteristicTypeSmokeDetected, "No smoke", "Smoke detected"),
            (HMCharacteristicTypeLeakDetected, "No leak", "Leak detected"),
            (HMCharacteristicTypeCarbonMonoxideDetected, "Normal", "Carbon monoxide detected"),
            (HMCharacteristicTypeCarbonDioxideDetected, "Normal", "Carbon dioxide detected"),
            (HMCharacteristicTypeStatusJammed, "Not jammed", "Jammed"),
            (HMCharacteristicTypeStatusTampered, "No tampering", "Tampering detected"),
            (HMCharacteristicTypeStatusLowBattery, "Normal", "Low battery")
        ]
        for (type, zero, one) in tests {
            let value = try definition(type)
            XCTAssertEqual(value.control, .readOnly, type)
            XCTAssertEqual(value.format(0), zero, type)
            XCTAssertEqual(value.format(1), one, type)
            XCTAssertEqual(value.format(2), "Unavailable", type)
        }
        let air = try definition(HMCharacteristicTypeAirQuality)
        XCTAssertEqual(air.format(0), "Unknown")
        XCTAssertEqual(air.format(5), "Poor")
        XCTAssertFalse(air.accepts(6))
    }

    func testActiveControlIsDistinctFromReadOnlyStatusActive() throws {
        let active = try definition(HMCharacteristicTypeActive)
        XCTAssertEqual(active.control, .toggle)
        XCTAssertEqual(active.kind, .power)
        XCTAssertEqual(active.format(0), "Off")
        XCTAssertEqual(active.format(1), "On")
        XCTAssertFalse(active.accepts(2))
        let status = try definition(HMCharacteristicTypeStatusActive)
        XCTAssertEqual(status.control, .readOnly)
        XCTAssertEqual(status.format(1), "Active")
    }

    func testSecurityTargetsExcludeTriggeredStateAndHVACModesKeepTheirOwnDomain() throws {
        let security = try definition(HMCharacteristicTypeCurrentSecuritySystemState)
        XCTAssertEqual(security.format(4), "Alarm triggered")
        let target = try definition(HMCharacteristicTypeTargetSecuritySystemState)
        XCTAssertEqual(target.control, .choice)
        XCTAssertEqual(target.format(3), "Disarm")
        XCTAssertFalse(target.accepts(4))
        XCTAssertEqual(try definition(HMCharacteristicTypeTargetHeatingCooling).format(3), "Automatic")
        XCTAssertEqual(try definition(HMCharacteristicTypeTargetHeaterCoolerState).format(0), "Automatic")
        XCTAssertFalse(try definition(HMCharacteristicTypeTargetHeaterCoolerState).accepts(3))
        XCTAssertEqual(try definition(HMCharacteristicTypeCurrentHumidifierDehumidifierState).format(3), "Dehumidifying")
        XCTAssertFalse(try definition(HMCharacteristicTypeTargetHumidifierDehumidifierState).accepts(3))
    }

    func testPositionTiltAndMeasurementFormattingUsesRealUnits() throws {
        let position = try definition(HMCharacteristicTypeTargetPosition)
        XCTAssertEqual(position.control, .range)
        XCTAssertTrue(position.accepts(0)); XCTAssertTrue(position.accepts(100))
        XCTAssertFalse(position.accepts(-1)); XCTAssertFalse(position.accepts(101))
        XCTAssertFalse(position.accepts(25.5))
        XCTAssertEqual(position.format(25), "25 %")
        let tilt = try definition(HMCharacteristicTypeTargetHorizontalTilt)
        XCTAssertTrue(tilt.accepts(-90)); XCTAssertTrue(tilt.accepts(90))
        XCTAssertFalse(tilt.accepts(-91)); XCTAssertFalse(tilt.accepts(91))
        XCTAssertEqual(tilt.format(-45), "-45°")
        XCTAssertEqual(try definition(HMCharacteristicTypeCurrentTemperature).format(-5), "-5.0 °C")
        XCTAssertEqual(try definition(HMCharacteristicTypeCurrentLightLevel).format(12.5), "12.5 lx")
        XCTAssertEqual(try definition(HMCharacteristicTypeCarbonDioxideLevel).format(850), "850.0 ppm")
        XCTAssertEqual(try definition(HMCharacteristicTypePM2_5Density).format(8.2), "8.2 µg/m³")
        XCTAssertEqual(try definition(HMCharacteristicTypeRemainingDuration).format(30), "30 s")
        XCTAssertFalse(try definition(HMCharacteristicTypeBatteryLevel).accepts(101))
        XCTAssertFalse(try definition(HMCharacteristicTypePM10Density).accepts(-1))
    }

    func testLegacyNineDefinitionsRetainTheirExpectedKindsAndUnits() throws {
        let expected: [(String, HomeValueKind)] = [
            (HMCharacteristicTypePowerState, .power), (HMCharacteristicTypeCurrentTemperature, .temperature),
            (HMCharacteristicTypeCurrentRelativeHumidity, .humidity), (HMCharacteristicTypeBrightness, .brightness),
            (HMCharacteristicTypeTargetTemperature, .targetTemperature), (HMCharacteristicTypeRotationSpeed, .fanSpeed),
            (HMCharacteristicTypeHue, .hue), (HMCharacteristicTypeSaturation, .saturation),
            (HMCharacteristicTypeColorTemperature, .colorTemperature)
        ]
        for (type, kind) in expected { XCTAssertEqual(try definition(type).kind, kind) }
        XCTAssertEqual(try definition(HMCharacteristicTypeHue).format(90), "90°")
        XCTAssertEqual(try definition(HMCharacteristicTypeColorTemperature).format(250), "4000 K")
        XCTAssertEqual(try definition(HMCharacteristicTypeColorTemperature).format(0), "Unavailable")
    }

    func testCommandsAreExplicitActionsWithoutAToggleState() throws {
        for type in [HMCharacteristicTypeHoldPosition, HMCharacteristicTypeFilterResetChangeIndication, HMCharacteristicTypeIdentify] {
            let value = try definition(type)
            XCTAssertEqual(value.control, .command)
            XCTAssertEqual(value.options.map(\.value), [1])
            XCTAssertFalse(value.accepts(0))
            XCTAssertFalse(value.accepts(2))
        }
        let image = try definition(HMCharacteristicTypeImageRotation)
        XCTAssertEqual(image.options.map(\.value), [0, 90, 180, 270])
        XCTAssertFalse(image.accepts(45)); XCTAssertFalse(image.accepts(360))
    }

    func testInformationDoesNotBecomeWritableOrASecretManagementControl() throws {
        for type in [HMCharacteristicTypeManufacturer, HMCharacteristicTypeModel, HMCharacteristicTypeName, HMCharacteristicTypeFirmwareVersion] {
            let value = try definition(type)
            XCTAssertEqual(value.control, .readOnly)
            XCTAssertEqual(value.kind, .information)
        }
        XCTAssertEqual(try definition(HMCharacteristicTypeAdminOnlyAccess).control, .readOnly)
    }

    func testPublicMediaAndRouterDefinitionsUseSDKDomainsOnSupportedSystems() throws {
        guard #available(iOS 18.0, *) else { return }
        let remote = try definition(HMCharacteristicTypeRemoteKey)
        XCTAssertEqual(remote.control, .command)
        XCTAssertEqual(remote.options.count, 17)
        XCTAssertEqual(remote.format(11), "Play / pause")
        XCTAssertEqual(remote.format(16), "Home")
        XCTAssertFalse(remote.accepts(-1)); XCTAssertFalse(remote.accepts(17))
        let input = try definition(HMCharacteristicTypeActiveIdentifier)
        XCTAssertEqual(input.control, .choice)
        XCTAssertTrue(input.options.isEmpty, "Real TV source IDs must be supplied by linked services, never invented by the static registry.")
        XCTAssertTrue(input.accepts(5)); XCTAssertFalse(input.accepts(5.5)); XCTAssertFalse(input.accepts(-1))
        XCTAssertEqual(try definition(HMCharacteristicTypeVolumeSelector).options.map(\.title), ["Volume up", "Volume down"])
        XCTAssertEqual(try definition(HMCharacteristicTypeCurrentMediaState).format(4), "Loading")
        XCTAssertFalse(try definition(HMCharacteristicTypeTargetMediaState).accepts(3))
        XCTAssertEqual(try definition(HMCharacteristicTypeRouterStatus).format(0), "Ready")
        XCTAssertEqual(try definition(HMCharacteristicTypeWiFiSatelliteStatus).format(2), "Not connected")
        XCTAssertEqual(HomeCharacteristicCatalog.allDefinitions.count, 129, "All public Xcode27 characteristic types except the9 named binary management types are described.")
        XCTAssertEqual(HomeCharacteristicCatalog.excludedCharacteristicTypes.count, 9)
    }
}
