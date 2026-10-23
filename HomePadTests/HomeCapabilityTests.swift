import XCTest
import HomeKit
@testable import HomePad

final class HomeCapabilityTests: XCTestCase {
    private let service = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private let accessory = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    private func tile(_ snapshot: HomeCharacteristicSnapshot, serviceType: String = HMServiceTypeLightbulb,
                      category: String = HMAccessoryCategoryTypeLightbulb, reachable: Bool = true) -> HomeTile {
        HomeTileFactory.make(snapshot, serviceID: service, serviceType: serviceType, name: "Device", room: "Room",
                             accessoryID: accessory, categoryType: category, reachable: reachable)!
    }
    private func snapshot(_ type: String, value: Double?, writable: Bool = true) -> HomeCharacteristicSnapshot {
        HomeCharacteristicSnapshot(id: UUID(), type: type, title: "Value", number: value, writable: writable)
    }

    func testDeviceMetadataRejectsUnknownOutOfBoundsAndMisalignedCurrentValues() {
        var value = snapshot(HMCharacteristicTypeBrightness, value: 120)
        value.minimum = 0; value.maximum = 100; value.step = 5
        for bad in [120.0, -1, 22, .nan, .infinity] {
            value.number = bad
            let actual = tile(value)
            XCTAssertNil(actual.number); XCTAssertFalse(actual.writable); XCTAssertEqual(actual.value, "Unavailable")
        }
        value.number = 25
        XCTAssertTrue(tile(value).writable)
        value.validValues = [0, 50, 100]
        XCTAssertNil(tile(value).number)
        value.number = 50
        XCTAssertTrue(tile(value).accepts(100)); XCTAssertFalse(tile(value).accepts(75))
    }

    func testMissingRangeBoundsDoesNotInventNumericControls() {
        let value = snapshot(HMCharacteristicTypeTargetPosition, value: 40)
        let readOnly = tile(value, serviceType: HMServiceTypeWindowCovering)
        XCTAssertEqual(readOnly.value, "40 %"); XCTAssertFalse(readOnly.writable)
        XCTAssertNil(readOnly.adjustment)
        var enumerated = value; enumerated.validValues = [0, 40, 100]
        let options = tile(enumerated, serviceType: HMServiceTypeWindowCovering)
        XCTAssertEqual(options.control, .choice); XCTAssertTrue(options.writable)
        XCTAssertTrue(options.accepts(100)); XCTAssertFalse(options.accepts(50))
    }

    func testEnumAndToggleWritesRespectActualOptionsAndPermissions() {
        var choice = snapshot(HMCharacteristicTypeTargetSecuritySystemState, value: 1)
        choice.validValues = [0, 1, 2]
        let security = tile(choice, serviceType: HMServiceTypeSecuritySystem)
        XCTAssertEqual(security.options.map(\.value), [0, 1, 2])
        XCTAssertTrue(security.accepts(2)); XCTAssertFalse(security.accepts(3))
        var power = snapshot(HMCharacteristicTypeActive, value: 0)
        power.minimum = 0; power.maximum = 0
        let limited = tile(power, serviceType: HMServiceTypeValve)
        XCTAssertFalse(limited.accepts(1)); XCTAssertTrue(limited.accepts(0))
        choice.writable = false
        XCTAssertFalse(tile(choice).writable)
        XCTAssertFalse(tile(choice, reachable: false).writable)
        choice.readFailed = true
        XCTAssertNil(tile(choice).number); XCTAssertFalse(tile(choice).writable)
    }

    func testDynamicInputChoicesAreFiniteUniqueAndConstrained() throws {
        guard #available(iOS 18.0, *) else { return }
        var input = snapshot(HMCharacteristicTypeActiveIdentifier, value: 1)
        input.dynamicOptions = [.init(value: 1, title: "HDMI 1"), .init(value: 1, title: "Duplicate"),
                                .init(value: .nan, title: "Bad"), .init(value: 2.5, title: "Fraction"),
                                .init(value: 2, title: "HDMI 2")]
        input.validValues = [1, 2]
        let actual = tile(input, serviceType: HMServiceTypeTelevision)
        XCTAssertEqual(actual.options.map(\.title), ["HDMI 1", "HDMI 2"])
        XCTAssertEqual(actual.formatted(2), "HDMI 2")
        XCTAssertTrue(actual.accepts(2)); XCTAssertFalse(actual.accepts(3))
    }

    func testSensorAndUnknownCharacteristicsNeverBecomePowerControls() {
        for type in [HMCharacteristicTypeMotionDetected, HMCharacteristicTypeContactState, HMCharacteristicTypeSmokeDetected,
                     HMCharacteristicTypeLeakDetected, HMCharacteristicTypeOccupancyDetected] {
            let value = tile(snapshot(type, value: 0), serviceType: HMServiceTypeMotionSensor, category: HMAccessoryCategoryTypeSensor)
            XCTAssertEqual(value.control, .readOnly); XCTAssertFalse(value.writable); XCTAssertFalse(value.quickToggle)
            XCTAssertFalse(value.accepts(1))
        }
        var unknown = snapshot("vendor-extra-state", value: 12)
        unknown.text = "Extra"
        XCTAssertEqual(tile(unknown).control, .readOnly); XCTAssertFalse(tile(unknown).writable)
        let alarm = tile(snapshot(HMCharacteristicTypeLeakDetected, value: 1), serviceType: HMServiceTypeLeakSensor)
        XCTAssertTrue(alarm.needsAttention)
        let invalid = tile(snapshot(HMCharacteristicTypeLeakDetected, value: 9), serviceType: HMServiceTypeLeakSensor)
        XCTAssertEqual(invalid.value, "Unavailable"); XCTAssertNil(invalid.number)
    }

    func testNotificationOnlyButtonIsLastEventAndNeverAFakeToggle() {
        var event = snapshot(HMCharacteristicTypeInputEvent, value: nil, writable: false)
        event.readable = false; event.eventCapable = true
        let waiting = tile(event, serviceType: HMServiceTypeStatelessProgrammableSwitch)
        XCTAssertEqual(waiting.value, "No event received"); XCTAssertFalse(waiting.writable)
        event.number = 2
        XCTAssertEqual(tile(event).value, "Long press")
        event.eventCapable = false
        XCTAssertNil(HomeTileFactory.make(event, serviceID: service, serviceType: HMServiceTypeStatelessProgrammableSwitch,
            name: "Button", room: "Room", accessoryID: accessory, categoryType: HMAccessoryCategoryTypeProgrammableSwitch, reachable: true))
    }

    func testRequestOnlyCommandHasNoInventedPhysicalState() {
        var command = snapshot(HMCharacteristicTypeHoldPosition, value: nil)
        command.readable = false
        let actual = tile(command, serviceType: HMServiceTypeWindowCovering)
        XCTAssertTrue(actual.writable); XCTAssertEqual(actual.control, .command)
        XCTAssertNil(actual.number); XCTAssertEqual(actual.value, "Action")
        XCTAssertTrue(actual.accepts(1)); XCTAssertFalse(actual.accepts(0))
    }

    func testPrimaryServiceUsesReportedStateAndIncludesOnlyItsDiagnostics() {
        let current = tile(snapshot(HMCharacteristicTypeCurrentLockMechanismState, value: 1), serviceType: HMServiceTypeLockMechanism)
        let target = tile(snapshot(HMCharacteristicTypeTargetLockMechanismState, value: 0), serviceType: HMServiceTypeLockMechanism)
        var battery = tile(snapshot(HMCharacteristicTypeBatteryLevel, value: 76, writable: false), serviceType: HMServiceTypeBattery)
        battery.serviceID = UUID()
        var unrelated = tile(snapshot(HMCharacteristicTypePowerState, value: 0))
        unrelated.serviceID = UUID(); unrelated.accessoryID = UUID()
        let values = [target, battery, current, unrelated]
        let primary = HomeAccessoryPresentation.primaryTiles(values)
        XCTAssertEqual(Set(primary.map(\.id)), Set([current.id, unrelated.id]))
        XCTAssertEqual(current.displaySymbol, "lock.fill", "Target unlock is not evidence that the door unlocked")
        let details = HomeAccessoryPresentation.details(for: current.id, in: values)
        XCTAssertEqual(Set(details.map(\.id)), Set([current.id, target.id, battery.id]))
    }

    func testEveryCameraCategoryTileStaysOutOfLeftFavoritesIncludingSavedInformationIDs() {
        let info = tile(snapshot(HMCharacteristicTypeName, value: nil, writable: false),
                        serviceType: HMServiceTypeAccessoryInformation, category: HMAccessoryCategoryTypeIPCamera)
        let battery = tile(snapshot(HMCharacteristicTypeBatteryLevel, value: 90, writable: false),
                           serviceType: HMServiceTypeBattery, category: HMAccessoryCategoryTypeVideoDoorbell)
        XCTAssertTrue(info.rightColumnOnly); XCTAssertTrue(battery.rightColumnOnly)
        XCTAssertTrue(HomeAccessoryPresentation.primaryTiles([info, battery]).isEmpty)
    }

    @MainActor func testSensorSignalAndThermostatTargetStayPrimaryWhenPowerIsAlsoExposed() {
        let detection = tile(snapshot(HMCharacteristicTypeMotionDetected, value: 0, writable: false),
                             serviceType: HMServiceTypeMotionSensor, category: HMAccessoryCategoryTypeSensor)
        let sensorPower = tile(snapshot(HMCharacteristicTypePowerState, value: 1),
                              serviceType: HMServiceTypeMotionSensor, category: HMAccessoryCategoryTypeSensor)
        XCTAssertEqual(HomeAccessoryPresentation.primaryTiles([sensorPower, detection]).map(\.id), [detection.id])
        let store = HomeStore(); store.startDemo(); store.tiles = [sensorPower, detection]
        XCTAssertNil(store.quickToggle(for: detection), "A sensor icon opens readings, rather than silently disabling its power")
        var temperature = snapshot(HMCharacteristicTypeTargetTemperature, value: 22)
        temperature.minimum = 10; temperature.maximum = 30; temperature.step = 0.5
        let target = tile(temperature, serviceType: HMServiceTypeThermostat, category: HMAccessoryCategoryTypeThermostat)
        let power = tile(snapshot(HMCharacteristicTypePowerState, value: 1), serviceType: HMServiceTypeThermostat)
        XCTAssertEqual(HomeAccessoryPresentation.primaryTiles([power, target]).map(\.id), [target.id])
        XCTAssertTrue(target.isClimate)
        store.tiles = [power, target]
        XCTAssertEqual(store.quickToggle(for: target)?.id, power.id)
    }

    @MainActor func testDemoTypedControlsUseCurrentServiceAndRejectOfflineInvalidAndBusyWrites() {
        let store = HomeStore(); store.startDemo(); store.configureHomeKitValidation()
        let lock = store.tiles.first { $0.characteristicType == HMCharacteristicTypeCurrentLockMechanismState }!
        let target = store.tiles.first { $0.characteristicType == HMCharacteristicTypeTargetLockMechanismState }!
        XCTAssertNil(store.quickToggle(for: lock))
        store.setValue(target.id, to: 7)
        XCTAssertEqual(store.tiles.first { $0.id == lock.id }?.number, 1)
        store.busy.insert(target.id); store.setValue(target.id, to: 0)
        XCTAssertEqual(store.tiles.first { $0.id == lock.id }?.number, 1)
        store.busy.remove(target.id); store.setValue(target.id, to: 0)
        XCTAssertEqual(store.tiles.first { $0.id == lock.id }?.number, 0)
        let motion = store.tiles.first { $0.characteristicType == HMCharacteristicTypeMotionDetected }!
        store.setValue(motion.id, to: 1)
        XCTAssertEqual(store.tiles.first { $0.id == motion.id }?.number, 0)
        let valve = store.tiles.first { $0.serviceType == HMServiceTypeValve && $0.characteristicType == HMCharacteristicTypeActive }!
        store.toggle(valve)
        XCTAssertEqual(store.tiles.first { $0.id == valve.id }?.value, "On")
        let index = store.tiles.firstIndex { $0.id == valve.id }!
        store.tiles[index].reachable = false; store.toggle(store.tiles[index])
        XCTAssertEqual(store.tiles[index].value, "On")
        store.runScene("Good night")
        XCTAssertTrue(store.tiles.filter { $0.kind == .power }.allSatisfy { $0.number == 0 && !$0.hasActiveState })
        store.disconnect(); XCTAssertTrue(store.tiles.isEmpty)
    }
}
