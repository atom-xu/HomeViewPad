import XCTest
import HomeKit
@testable import HomePad

final class HomeAccessoryPresentationTests: XCTestCase {
    func testIdenticallyNamedServicesNeverShareControls() {
        let firstService = identifier(101)
        let secondService = identifier(102)
        let firstPower = tile(1, kind: .power, service: firstService)
        let secondPower = tile(2, kind: .power, service: secondService)
        let firstBrightness = tile(3, kind: .brightness, service: firstService)
        let secondBrightness = tile(4, kind: .brightness, service: secondService)
        let secondHue = tile(5, kind: .hue, service: secondService)
        // Every characteristic deliberately has the same name and room.
        let values = [secondHue, firstBrightness, secondPower, firstPower, secondBrightness]

        XCTAssertEqual(HomeAccessoryPresentation.primaryTiles(values).map(\.id), [secondPower.id, firstPower.id])
        XCTAssertEqual(HomeAccessoryPresentation.details(for: firstPower.id, in: values).map(\.id),
                       [firstPower.id, firstBrightness.id])
        XCTAssertEqual(HomeAccessoryPresentation.details(for: secondPower.id, in: values).map(\.id),
                       [secondPower.id, secondBrightness.id, secondHue.id])
        XCTAssertEqual(HomeAccessoryPresentation.details(for: firstBrightness.id, in: values).map(\.id),
                       [firstPower.id, firstBrightness.id])
    }

    func testLegacyTilesWithoutServiceIdentityRemainIndependent() {
        let power = tile(1, kind: .power)
        let brightness = tile(2, kind: .brightness)
        let hue = tile(3, kind: .hue)
        let identifiedBrightness = tile(4, kind: .brightness, service: identifier(101))
        let values = [power, brightness, hue, identifiedBrightness]

        XCTAssertEqual(HomeAccessoryPresentation.primaryTiles(values).map(\.id), values.map(\.id))
        for value in values {
            XCTAssertEqual(HomeAccessoryPresentation.details(for: value.id, in: values).map(\.id), [value.id],
                           "A missing service identifier must not group unrelated legacy controls")
        }
    }

    func testPowerCardOwnsOnlyItsAdvertisedAdjustmentControls() {
        let service = identifier(101)
        let power = tile(1, kind: .power, service: service)
        let brightness = tile(2, kind: .brightness, service: service)
        let hue = tile(3, kind: .hue, service: service)
        let saturation = tile(4, kind: .saturation, service: service)
        let colorTemperature = tile(5, kind: .colorTemperature, service: service)
        let values = [saturation, colorTemperature, brightness, hue, power]

        XCTAssertEqual(HomeAccessoryPresentation.primaryTiles(values).map(\.id), [power.id])
        XCTAssertEqual(HomeAccessoryPresentation.details(for: power.id, in: values).map(\.id),
                       [power.id, brightness.id, hue.id, saturation.id, colorTemperature.id])
    }

    func testServiceWithoutPowerUsesOnePrimaryCardAndRetainsAllItsAdjustments() {
        let dimmer = tile(1, kind: .brightness, service: identifier(101))
        let fan = tile(2, kind: .fanSpeed, service: identifier(102))
        let hue = tile(3, kind: .hue, service: identifier(103))
        let saturation = tile(4, kind: .saturation, service: identifier(103))
        let values = [dimmer, fan, hue, saturation]
        XCTAssertEqual(HomeAccessoryPresentation.primaryTiles(values).map(\.id), [dimmer.id, fan.id, hue.id])
        XCTAssertEqual(HomeAccessoryPresentation.details(for: dimmer.id, in: values).map(\.id), [dimmer.id])
        XCTAssertEqual(HomeAccessoryPresentation.details(for: hue.id, in: values).map(\.id), [hue.id, saturation.id])
    }

    func testServicePowerKeepsClimateReadingsInItsDetailsWithoutDuplicateCards() {
        let service = identifier(101)
        let power = tile(1, kind: .power, service: service)
        let temperature = tile(2, kind: .temperature, service: service)
        let humidity = tile(3, kind: .humidity, service: service)
        let target = tile(4, kind: .targetTemperature, service: service)
        let values = [power, temperature, humidity, target]
        XCTAssertEqual(HomeAccessoryPresentation.primaryTiles(values).map(\.id), [power.id])
        XCTAssertEqual(HomeAccessoryPresentation.details(for: target.id, in: values).map(\.id), values.map(\.id))
    }

    func testDetailsDoNotInventColorControlsForOnOffOrDimmableDevices() {
        let service = identifier(101)
        let power = tile(1, kind: .power, service: service)
        let brightness = tile(2, kind: .brightness, service: service)

        XCTAssertEqual(HomeAccessoryPresentation.details(for: power.id, in: [power]).map(\.kind), [.power])
        XCTAssertEqual(HomeAccessoryPresentation.details(for: power.id, in: [brightness, power]).map(\.kind),
                       [.power, .brightness])
        XCTAssertTrue(HomeAccessoryPresentation.details(for: identifier(999), in: [power, brightness]).isEmpty)
        XCTAssertTrue(HomeAccessoryPresentation.details(for: power.id, in: []).isEmpty)
    }

    func testUnavailableCapabilitiesKeepTheirIdentityAndCannotBecomeWritable() throws {
        let service = identifier(101)
        let power = tile(1, kind: .power, service: service)
        var brightness = tile(2, kind: .brightness, service: service)
        brightness.reachable = false
        brightness.writable = false
        brightness.number = nil
        brightness.adjustment = nil
        brightness.value = "Offline"
        let details = HomeAccessoryPresentation.details(for: power.id, in: [brightness, power])
        let actual = try XCTUnwrap(details.first(where: { $0.id == brightness.id }))

        XCTAssertEqual(details.map(\.id), [power.id, brightness.id])
        XCTAssertFalse(actual.reachable)
        XCTAssertFalse(actual.writable)
        XCTAssertNil(actual.number)
        XCTAssertNil(actual.adjustment)
        XCTAssertEqual(actual.value, "Offline")
        XCTAssertEqual(HomeAccessoryPresentation.primaryTiles([brightness, power]).map(\.id), [power.id])
    }

    func testColorCharacteristicsRequireRecognizedHomeKitTypes() {
        XCTAssertEqual(HomeValueKind(characteristicType: HMCharacteristicTypeHue), .hue)
        XCTAssertEqual(HomeValueKind(characteristicType: HMCharacteristicTypeSaturation), .saturation)
        XCTAssertEqual(HomeValueKind(characteristicType: HMCharacteristicTypeColorTemperature), .colorTemperature)
        XCTAssertNil(HomeValueKind(characteristicType: "Unsupported vendor color control"))
        XCTAssertEqual(HomeValueKind(characteristicType: HMCharacteristicTypeTargetLockMechanismState), .state)
    }

    private func identifier(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    private func tile(_ value: Int, kind: HomeValueKind, service: UUID? = nil) -> HomeTile {
        HomeTile(id: identifier(value), name: "Same accessory", room: "Same room", symbol: kind.symbol,
                 value: kind == .power ? "On" : "50", isOn: kind == .power,
                 reachable: true, writable: kind == .power || kind.adjustable, kind: kind, number: 50,
                 adjustment: kind.adjustable ? HomeAdjustment(minimum: 0, maximum: 100, step: 1) : nil,
                 serviceID: service)
    }
}
