#if DEBUG
import Foundation
import HomeKit

/// Isolated, deterministic UI data selected only by --demo --uitesting
/// --homekit-coverage-fixture. This path never constructs HMHomeManager.
extension HomeStore {
    func configureHomeKitValidation() {
        guard demo, status == .ready else { return }
        tiles = []
        func uuid(_ value: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-0000-000c-%012d", value))! }
        func add(_ index: Int, _ type: String, _ category: String, _ name: String,
                 _ values: [(String, Double?, Bool, Double?, Double?, Double?)], accessory: Int? = nil) {
            for (position, entry) in values.enumerated() {
                let (characteristic, number, writable, minimum, maximum, step) = entry
                var snapshot = HomeCharacteristicSnapshot(id: uuid(index * 100 + position + 1), type: characteristic,
                    title: name, number: number, writable: writable, minimum: minimum, maximum: maximum, step: step)
                if characteristic == HMCharacteristicTypeInputEvent { snapshot.readable = false; snapshot.eventCapable = true }
                if let tile = HomeTileFactory.make(snapshot, serviceID: uuid(index * 100), serviceType: type,
                    name: name, room: "Living room", accessoryID: uuid(10000 + (accessory ?? index)),
                    categoryType: category, reachable: true) { tiles.append(tile) }
            }
        }
        add(1, HMServiceTypeLockMechanism, HMAccessoryCategoryTypeDoorLock, "Door lock", [
            (HMCharacteristicTypeCurrentLockMechanismState, 1, false, nil, nil, nil),
            (HMCharacteristicTypeTargetLockMechanismState, 1, true, 0, 1, 1)])
        add(2, HMServiceTypeWindowCovering, HMAccessoryCategoryTypeWindowCovering, "Window covering", [
            (HMCharacteristicTypeCurrentPosition, 45, false, 0, 100, 1),
            (HMCharacteristicTypeTargetPosition, 45, true, 0, 100, 1),
            (HMCharacteristicTypeHoldPosition, nil, true, nil, nil, nil)])
        add(3, HMServiceTypeMotionSensor, HMAccessoryCategoryTypeSensor, "Motion sensor", [
            (HMCharacteristicTypeMotionDetected, 0, false, nil, nil, nil)])
        add(4, HMServiceTypeAirPurifier, HMAccessoryCategoryTypeAirPurifier, "Air purifier", [
            (HMCharacteristicTypeActive, 1, true, 0, 1, 1),
            (HMCharacteristicTypeCurrentAirPurifierState, 2, false, nil, nil, nil),
            (HMCharacteristicTypeTargetAirPurifierState, 1, true, 0, 1, 1),
            (HMCharacteristicTypeRotationSpeed, 35, true, 0, 100, 1)])
        add(5, HMServiceTypeSecuritySystem, HMAccessoryCategoryTypeSecuritySystem, "Security system", [
            (HMCharacteristicTypeCurrentSecuritySystemState, 1, false, nil, nil, nil),
            (HMCharacteristicTypeTargetSecuritySystemState, 1, true, 0, 3, 1)])
        add(6, HMServiceTypeValve, HMAccessoryCategoryTypeFaucet, "Valve", [
            (HMCharacteristicTypeActive, 0, true, 0, 1, 1),
            (HMCharacteristicTypeInUse, 0, false, nil, nil, nil),
            (HMCharacteristicTypeSetDuration, 120, true, 0, 3600, 1)])
        add(7, HMServiceTypeGarageDoorOpener, HMAccessoryCategoryTypeGarageDoorOpener, "Garage door", [
            (HMCharacteristicTypeCurrentDoorState, 1, false, nil, nil, nil),
            (HMCharacteristicTypeTargetDoorState, 1, true, 0, 1, 1),
            (HMCharacteristicTypeObstructionDetected, 0, false, nil, nil, nil)])
        add(8, HMServiceTypeAirQualitySensor, HMAccessoryCategoryTypeSensor, "Air quality", [
            (HMCharacteristicTypeAirQuality, 2, false, nil, nil, nil),
            (HMCharacteristicTypePM2_5Density, 18.5, false, 0, nil, nil),
            (HMCharacteristicTypeCarbonDioxideLevel, 640, false, 0, nil, nil)])
        add(9, HMServiceTypeLeakSensor, HMAccessoryCategoryTypeSensor, "Leak sensor", [
            (HMCharacteristicTypeLeakDetected, 1, false, nil, nil, nil)])
        add(10, HMServiceTypeSmokeSensor, HMAccessoryCategoryTypeSensor, "Smoke sensor", [
            (HMCharacteristicTypeSmokeDetected, 0, false, nil, nil, nil)])
        add(11, HMServiceTypeBattery, HMAccessoryCategoryTypeDoorLock, "Door lock battery", [
            (HMCharacteristicTypeBatteryLevel, 76, false, 0, 100, 1),
            (HMCharacteristicTypeStatusLowBattery, 0, false, nil, nil, nil)], accessory: 1)
        add(12, HMServiceTypeHeaterCooler, HMAccessoryCategoryTypeAirConditioner, "Air conditioner", [
            (HMCharacteristicTypeActive, 1, true, 0, 1, 1),
            (HMCharacteristicTypeCurrentHeaterCoolerState, 2, false, nil, nil, nil),
            (HMCharacteristicTypeTargetHeaterCoolerState, 1, true, 0, 2, 1),
            (HMCharacteristicTypeHeatingThreshold, 20, true, 16, 30, 0.5),
            (HMCharacteristicTypeCoolingThreshold, 25, true, 16, 30, 0.5)])
        add(13, HMServiceTypeStatelessProgrammableSwitch, HMAccessoryCategoryTypeProgrammableSwitch, "Programmable button", [
            (HMCharacteristicTypeInputEvent, nil, false, nil, nil, nil)])
        if #available(iOS 18.0, *) {
            add(14, HMServiceTypeTelevision, HMAccessoryCategoryTypeTelevision, "Television", [
                (HMCharacteristicTypeActive, 1, true, 0, 1, 1),
                (HMCharacteristicTypeCurrentMediaState, 1, false, nil, nil, nil),
                (HMCharacteristicTypeTargetMediaState, 1, true, 0, 2, 1),
                (HMCharacteristicTypeRemoteKey, nil, true, nil, nil, nil)])
        }
    }
}
#endif
