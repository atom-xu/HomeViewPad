import XCTest
import HomeKit
import UIKit
@testable import HomePad

final class HomeServiceCatalogTests: XCTestCase {
    func testEveryPublicServiceAndCategoryHasAnExplicitDefinition() {
        // Frozen public Xcode27 header inventory; no SDK/filesystem dependency at test runtime.
        var services: Set<String> = [
            HMServiceTypeSwitch, HMServiceTypeThermostat, HMServiceTypeOutlet, HMServiceTypeLockManagement,
            HMServiceTypeAirQualitySensor, HMServiceTypeCarbonDioxideSensor, HMServiceTypeCarbonMonoxideSensor,
            HMServiceTypeContactSensor, HMServiceTypeDoor, HMServiceTypeHumiditySensor, HMServiceTypeLeakSensor,
            HMServiceTypeLightSensor, HMServiceTypeMotionSensor, HMServiceTypeOccupancySensor, HMServiceTypeSecuritySystem,
            HMServiceTypeStatefulProgrammableSwitch, HMServiceTypeStatelessProgrammableSwitch, HMServiceTypeSmokeSensor,
            HMServiceTypeTemperatureSensor, HMServiceTypeWindow, HMServiceTypeWindowCovering,
            HMServiceTypeCameraRTPStreamManagement, HMServiceTypeCameraControl, HMServiceTypeMicrophone, HMServiceTypeSpeaker,
            HMServiceTypeAirPurifier, HMServiceTypeFilterMaintenance, HMServiceTypeSlats, HMServiceTypeLabel,
            HMServiceTypeIrrigationSystem, HMServiceTypeValve, HMServiceTypeFaucet, HMServiceTypeAccessoryInformation,
            HMServiceTypeFan, HMServiceTypeGarageDoorOpener, HMServiceTypeLightbulb, HMServiceTypeLockMechanism,
            HMServiceTypeBattery, HMServiceTypeVentilationFan, HMServiceTypeHeaterCooler,
            HMServiceTypeHumidifierDehumidifier, HMServiceTypeDoorbell
        ]
        var categories: Set<String> = [
            HMAccessoryCategoryTypeOther, HMAccessoryCategoryTypeSecuritySystem, HMAccessoryCategoryTypeBridge,
            HMAccessoryCategoryTypeDoor, HMAccessoryCategoryTypeDoorLock, HMAccessoryCategoryTypeFan,
            HMAccessoryCategoryTypeGarageDoorOpener, HMAccessoryCategoryTypeIPCamera, HMAccessoryCategoryTypeLightbulb,
            HMAccessoryCategoryTypeOutlet, HMAccessoryCategoryTypeProgrammableSwitch, HMAccessoryCategoryTypeRangeExtender,
            HMAccessoryCategoryTypeSensor, HMAccessoryCategoryTypeSwitch, HMAccessoryCategoryTypeThermostat,
            HMAccessoryCategoryTypeVideoDoorbell, HMAccessoryCategoryTypeWindow, HMAccessoryCategoryTypeWindowCovering,
            HMAccessoryCategoryTypeAirPurifier, HMAccessoryCategoryTypeAirHeater, HMAccessoryCategoryTypeAirConditioner,
            HMAccessoryCategoryTypeAirHumidifier, HMAccessoryCategoryTypeAirDehumidifier,
            HMAccessoryCategoryTypeSprinkler, HMAccessoryCategoryTypeFaucet, HMAccessoryCategoryTypeShowerHead
        ]
        if #available(iOS 18, *) {
            services.formUnion([HMServiceTypeTelevision, HMServiceTypeInputSource, HMServiceTypeWiFiRouter, HMServiceTypeWiFiSatellite])
            categories.formUnion([HMAccessoryCategoryTypeTelevision, HMAccessoryCategoryTypeTelevisionSetTopBox,
                                  HMAccessoryCategoryTypeTelevisionStreamingStick, HMAccessoryCategoryTypeWiFiRouter,
                                  HMAccessoryCategoryTypeSpeaker, HMAccessoryCategoryTypeAudioReceiver, HMAccessoryCategoryTypeAirPort])
            XCTAssertEqual(services.count, 46)
            XCTAssertEqual(categories.count, 33)
        }
        XCTAssertEqual(Set(HomeServiceCatalog.allServices.map(\.type)), services)
        XCTAssertEqual(HomeServiceCatalog.allServices.count, services.count, "No duplicate service identifiers")
        XCTAssertEqual(Set(HomeServiceCatalog.categorySymbols.keys), categories)
        XCTAssertEqual(HomeServiceCatalog.allCategories.count, categories.count)
    }

    func testServiceIdentityWinsOverCategoryAndCameraAuxiliariesStayOnTheRight() {
        let accessoryCategory = HMAccessoryCategoryTypeBridge
        let lock = HomeServiceCatalog.definition(for: HMServiceTypeLockMechanism, categoryType: accessoryCategory)
        XCTAssertEqual(lock.family, .lock)
        XCTAssertEqual(lock.symbol, "key.fill")
        let unknown = HomeServiceCatalog.definition(for: "vendor-private-service", categoryType: HMAccessoryCategoryTypeWindowCovering)
        XCTAssertEqual(unknown.type, "vendor-private-service")
        XCTAssertEqual(unknown.family, .windowCovering)
        XCTAssertFalse(unknown.supportService)
        XCTAssertEqual(HomeServiceCatalog.definition(for: "unknown", categoryType: "unknown").family, .other)
        XCTAssertEqual(HomeServiceCatalog.definition(for: HMServiceTypeHeaterCooler, categoryType: HMAccessoryCategoryTypeAirHeater).symbol, "heater.vertical.fill")
        XCTAssertEqual(HomeServiceCatalog.definition(for: HMServiceTypeHumidifierDehumidifier, categoryType: HMAccessoryCategoryTypeAirDehumidifier).symbol, "dehumidifier.fill")
        XCTAssertEqual(HomeServiceCatalog.definition(for: HMServiceTypeValve, categoryType: HMAccessoryCategoryTypeShowerHead).symbol, "shower.fill")
        for type in [HMServiceTypeCameraControl, HMServiceTypeCameraRTPStreamManagement, HMServiceTypeDoorbell] {
            XCTAssertTrue(HomeServiceCatalog.definition(for: type).rightColumnOnly)
        }
        for type in [HMServiceTypeSpeaker, HMServiceTypeMicrophone] {
            let camera = HomeServiceCatalog.definition(for: type, categoryType: HMAccessoryCategoryTypeIPCamera)
            XCTAssertTrue(camera.supportService)
            XCTAssertTrue(camera.rightColumnOnly)
            XCTAssertFalse(HomeServiceCatalog.definition(for: type).rightColumnOnly)
        }
        for type in [HMServiceTypeAccessoryInformation, HMServiceTypeBattery, HMServiceTypeFilterMaintenance,
                     HMServiceTypeLockManagement, HMServiceTypeLabel] {
            XCTAssertTrue(HomeServiceCatalog.definition(for: type).supportService)
        }
    }

    func testReportedStateSelectsTheGlyphWithoutTreatingTargetsAsPhysicalState() {
        let lock = HomeServiceCatalog.definition(for: HMServiceTypeLockMechanism)
        XCTAssertEqual(HomeServiceCatalog.symbol(for: lock, characteristicType: HMCharacteristicTypeCurrentLockMechanismState, number: 0), "lock.open.fill")
        XCTAssertEqual(HomeServiceCatalog.symbol(for: lock, characteristicType: HMCharacteristicTypeCurrentLockMechanismState, number: 1), "lock.fill")
        XCTAssertEqual(HomeServiceCatalog.symbol(for: lock, characteristicType: HMCharacteristicTypeCurrentLockMechanismState, number: 2), "exclamationmark.triangle.fill")
        XCTAssertEqual(HomeServiceCatalog.symbol(for: lock, characteristicType: HMCharacteristicTypeTargetLockMechanismState, number: 1), lock.symbol)
        let garage = HomeServiceCatalog.definition(for: HMServiceTypeGarageDoorOpener)
        XCTAssertEqual(HomeServiceCatalog.symbol(for: garage, characteristicType: HMCharacteristicTypeCurrentDoorState, number: 1), "door.garage.closed")
        for state in [0.0, 2, 3, 4] {
            XCTAssertEqual(HomeServiceCatalog.symbol(for: garage, characteristicType: HMCharacteristicTypeCurrentDoorState, number: state), "door.garage.open", "Moving/stopped is not confirmed closed")
        }
        let covering = HomeServiceCatalog.definition(for: HMServiceTypeWindowCovering)
        XCTAssertEqual(HomeServiceCatalog.symbol(for: covering, characteristicType: HMCharacteristicTypeCurrentPosition, number: 0), "window.shade.closed")
        XCTAssertEqual(HomeServiceCatalog.symbol(for: covering, characteristicType: HMCharacteristicTypeCurrentPosition, number: 5), "window.shade.open")
        let contact = HomeServiceCatalog.definition(for: HMServiceTypeContactSensor)
        XCTAssertEqual(HomeServiceCatalog.symbol(for: contact, characteristicType: HMCharacteristicTypeContactState, number: 0), "door.left.hand.closed")
        XCTAssertEqual(HomeServiceCatalog.symbol(for: contact, characteristicType: HMCharacteristicTypeContactState, number: 1), "door.left.hand.open")
    }

    func testUnknownAndOutOfRangeStateReadingsNeverUseTheSafeClosedOrUndetectedGlyph() {
        let types = [HMCharacteristicTypeCurrentLockMechanismState, HMCharacteristicTypeCurrentDoorState,
                     HMCharacteristicTypeContactState, HMCharacteristicTypeCurrentSecuritySystemState,
                     HMCharacteristicTypeMotionDetected, HMCharacteristicTypeOccupancyDetected,
                     HMCharacteristicTypeSmokeDetected, HMCharacteristicTypeLeakDetected,
                     HMCharacteristicTypeCarbonMonoxideDetected, HMCharacteristicTypeCarbonDioxideDetected,
                     HMCharacteristicTypeAirQuality, HMCharacteristicTypeMute]
        let service = HomeServiceCatalog.definition(for: HMServiceTypeLockMechanism)
        for type in types {
            for value: Double? in [nil, .nan, .infinity, -1, 101, 0.5] {
                XCTAssertEqual(HomeServiceCatalog.symbol(for: service, characteristicType: type, number: value), "questionmark.circle", type)
            }
        }
        for type in [HMCharacteristicTypeCurrentPosition, HMCharacteristicTypeBatteryLevel] {
            for value: Double? in [nil, .nan, .infinity, -1, 101] {
                XCTAssertEqual(HomeServiceCatalog.symbol(for: service, characteristicType: type, number: value), "questionmark.circle")
            }
        }
    }

    @MainActor func testAllMappedAndStateVariantSymbolsResolveToSystemImages() {
        var symbols = Set(HomeServiceCatalog.allServices.map(\.symbol) + HomeServiceCatalog.allCategories.map(\.symbol))
        let types = [HMCharacteristicTypeCurrentLockMechanismState, HMCharacteristicTypeCurrentDoorState,
                     HMCharacteristicTypeCurrentPosition, HMCharacteristicTypeContactState,
                     HMCharacteristicTypeCurrentSecuritySystemState, HMCharacteristicTypeMotionDetected,
                     HMCharacteristicTypeOccupancyDetected, HMCharacteristicTypeSmokeDetected, HMCharacteristicTypeLeakDetected,
                     HMCharacteristicTypeCarbonMonoxideDetected, HMCharacteristicTypeCarbonDioxideDetected,
                     HMCharacteristicTypeAirQuality, HMCharacteristicTypeBatteryLevel, HMCharacteristicTypeMute]
        var allTypes = types
        if #available(iOS 18, *) { allTypes.append(HMCharacteristicTypeCurrentMediaState) }
        for service in HomeServiceCatalog.allServices {
            for type in allTypes {
                for value: Double? in [nil, -1, 0, 1, 2, 3, 4, 5, 25, 50, 75, 100, 101] {
                    symbols.insert(HomeServiceCatalog.symbol(for: service, characteristicType: type, number: value))
                }
            }
        }
        for symbol in symbols {
            XCTAssertNotNil(UIImage(systemName: symbol), "Missing system symbol: \(symbol)")
        }
    }
}
