import XCTest
import CoreLocation
import SwiftUI
@testable import HomePad

private actor WeatherStub: WeatherProviding {
    var calls = 0
    var fail = false
    var hold = false
    var pending: CheckedContinuation<WeatherReading, Error>?
    let started: (() -> Void)?
    init(started: (() -> Void)? = nil) { self.started = started }
    func search(_ name: String) async throws -> [WeatherCity] { [.philadelphia] }
    func fetch(_ city: WeatherCity) async throws -> WeatherReading {
        calls += 1; started?()
        if hold { return try await withCheckedThrowingContinuation { pending = $0 } }
        if fail { throw URLError(.notConnectedToInternet) }
        return .demo
    }
    func setFailure() { fail = true }
    func setHold() { hold = true }
    func finish() { pending?.resume(returning: .demo); pending = nil }
}

@MainActor private final class WeatherLocationStub: WeatherLocationManaging {
    weak var delegate: CLLocationManagerDelegate?
    var desiredAccuracy: CLLocationAccuracy = 0
    var authorizationStatus: CLAuthorizationStatus
    var permissionRequests = 0
    var fixRequests = 0
    var stops = 0
    init(_ authorization: CLAuthorizationStatus) { authorizationStatus = authorization }
    func requestWhenInUseAuthorization() { permissionRequests += 1 }
    func requestLocation() { fixRequests += 1 }
    func stopUpdatingLocation() { stops += 1 }
}

@MainActor private final class WeatherGeocoderStub: WeatherCityGeocoding {
    private var pending: CheckedContinuation<WeatherCity, Error>?
    let started: (() -> Void)?
    var cancellations = 0
    var calls = 0
    init(started: (() -> Void)? = nil) { self.started = started }
    func city(for location: CLLocation, locale: Locale) async throws -> WeatherCity {
        calls += 1
        return try await withCheckedThrowingContinuation { pending = $0; started?() }
    }
    func cancel() { cancellations += 1 }
    func finish(_ result: Result<WeatherCity, Error>) { pending?.resume(with: result); pending = nil }
}

@MainActor private final class WeatherTimeoutStub {
    private var pending: CheckedContinuation<Void, Error>?
    let started: (() -> Void)?
    var durations: [Duration] = []
    init(started: (() -> Void)? = nil) { self.started = started }
    func sleep(_ duration: Duration) async throws {
        durations.append(duration)
        try await withCheckedThrowingContinuation { pending = $0; started?() }
    }
    func finish() { pending?.resume(); pending = nil }
}

final class WeatherTests: XCTestCase {
    private let newYork = WeatherCity(id: 5128581, name: "New York", latitude: 40.71, longitude: -74)
    private let json = #"{"current":{"time":1792032300,"temperature_2m":21.0,"weather_code":0,"is_day":0},"daily":{"temperature_2m_max":[26.8],"temperature_2m_min":[18.1]}}"#
    private func isolatedDefaults() -> (String, UserDefaults) {
        let name = "WeatherTests.\(UUID())"
        return (name, UserDefaults(suiteName: name)!)
    }
    @MainActor private func store(_ defaults: UserDefaults, domain: String, client: any WeatherProviding = WeatherStub(), demo: Bool = false) -> WeatherStore {
        WeatherStore(defaults: defaults, client: client, demo: demo, persistentDomainName: domain)
    }
    func testWeatherResponseUnitsNightAndMalformedData() throws {
        let reading = try OpenMeteoClient.decode(Data(json.utf8))
        XCTAssertEqual(reading.temperature, 21)
        XCTAssertEqual(reading.degrees(reading.temperature, fahrenheit: true), "70°")
        XCTAssertEqual(reading.degrees(reading.temperature, fahrenheit: false), "21°")
        XCTAssertEqual(reading.symbol, "moon.stars.fill")
        XCTAssertEqual(reading.date.timeIntervalSince1970, 1792032300)
        XCTAssertThrowsError(try OpenMeteoClient.decode(Data(json.replacingOccurrences(of: "[26.8]", with: "[null]").utf8)))
        XCTAssertThrowsError(try OpenMeteoClient.decode(Data(json.replacingOccurrences(of: "[18.1]", with: "[]").utf8)))
        XCTAssertThrowsError(try OpenMeteoClient.decode(Data("{\"error\":true}".utf8)))
        let url = OpenMeteoClient.forecastURL(.philadelphia)
        XCTAssertEqual(url.host, "api.open-meteo.com")
        let parameters = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertTrue(parameters.contains(URLQueryItem(name: "timeformat", value: "unixtime")))
        XCTAssertTrue(parameters.contains(URLQueryItem(name: "temperature_unit", value: "celsius")))
    }
    @MainActor func testFreshSandboxRequiresCityAndDoesNotEnableLocationOrWeatherRequests() async {
        let (name, defaults) = isolatedDefaults(), stub = WeatherStub()
        defer { defaults.removePersistentDomain(forName: name) }
        let weather = store(defaults, domain: name, client: stub)
        XCTAssertNil(weather.city); XCTAssertFalse(weather.followsLocation)
        XCTAssertEqual(weather.temperatureUnit, .system); XCTAssertFalse(weather.legacyDefaults)
        await weather.refresh(force: true)
        let calls = await stub.calls; XCTAssertEqual(calls, 0)
        XCTAssertEqual(defaults.integer(forKey: WeatherPreferences.versionKey), 2)
        XCTAssertEqual(defaults.string(forKey: WeatherPreferences.unitKey), "system")
        XCTAssertEqual(defaults.object(forKey: WeatherPreferences.followsLocationKey) as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: WeatherPreferences.legacyDefaultsKey) as? Bool, false)
        XCTAssertEqual(defaults.data(forKey: WeatherPreferences.cityKey), Data("null".utf8))
        for key in WeatherPreferences.legacyWeatherKeys { XCTAssertNil(defaults.object(forKey: key)) }
        // A prior installation that only used implicit defaults and left no app-owned
        // record is observationally identical to this fresh sandbox. Do not claim to
        // have proved its old city/unit/location intent: first use must choose a city.
    }
    @MainActor func testPersistedAppEvidenceMigratesLegacyImplicitDefaultsOnlyOnce() {
        for (key, value) in [("homeMode", "demo" as Any), ("appLanguage", "en" as Any), ("keepAwake", true as Any), ("photoSlideshow", false as Any)] {
            let (name, defaults) = isolatedDefaults()
            defer { defaults.removePersistentDomain(forName: name) }
            defaults.set(value, forKey: key)
            let weather = store(defaults, domain: name)
            XCTAssertEqual(weather.city, .philadelphia); XCTAssertTrue(weather.followsLocation)
            XCTAssertEqual(weather.temperatureUnit, .fahrenheit); XCTAssertTrue(weather.legacyDefaults)
            XCTAssertNotNil(defaults.persistentDomain(forName: name)?[key])
            for oldKey in WeatherPreferences.legacyWeatherKeys { XCTAssertNil(defaults.object(forKey: oldKey)) }
            let unchanged = store(defaults, domain: name)
            XCTAssertEqual(unchanged.city, .philadelphia); XCTAssertTrue(unchanged.followsLocation)
            XCTAssertEqual(unchanged.temperatureUnit, .fahrenheit); XCTAssertTrue(unchanged.legacyDefaults)
            weather.select(nil); weather.temperatureUnit = .system
            let restored = store(defaults, domain: name)
            XCTAssertNil(restored.city); XCTAssertFalse(restored.followsLocation)
            XCTAssertEqual(restored.temperatureUnit, .system); XCTAssertFalse(restored.legacyDefaults)
        }
    }
    @MainActor func testSystemUnrelatedAndRegisteredDefaultsDoNotProveLegacyInstallation() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(["en-US"], forKey: "AppleLanguages")
        defaults.set("en_US", forKey: "AppleLocale")
        defaults.set("unrelated", forKey: "someOtherSetting")
        defaults.register(defaults: ["homeMode": "demo", "keepAwake": true])
        let weather = store(defaults, domain: name)
        XCTAssertNil(weather.city); XCTAssertFalse(weather.followsLocation)
        XCTAssertEqual(weather.temperatureUnit, .system); XCTAssertFalse(weather.legacyDefaults)
    }
    @MainActor func testExplicitOldWeatherChoicesSurviveAndOldRawKeysAreNeverRewritten() throws {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let cityData = try JSONEncoder().encode(newYork)
        defaults.set(cityData, forKey: "weatherCity")
        defaults.set(false, forKey: "weatherFahrenheit")
        defaults.set(false, forKey: "weatherFollowsLocation")
        let weather = store(defaults, domain: name)
        XCTAssertEqual(weather.city, newYork); XCTAssertFalse(weather.followsLocation)
        XCTAssertEqual(weather.temperatureUnit, .celsius)
        weather.select(nil); weather.fahrenheit = true
        let id = weather.beginLocationRequest()!; weather.cancelLocationRequest(id)
        let restored = store(defaults, domain: name)
        XCTAssertNil(restored.city); XCTAssertFalse(restored.followsLocation)
        XCTAssertEqual(restored.temperatureUnit, .fahrenheit)
        XCTAssertEqual(defaults.data(forKey: "weatherCity"), cityData)
        XCTAssertEqual(defaults.object(forKey: "weatherFahrenheit") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "weatherFollowsLocation") as? Bool, false)
    }
    @MainActor func testEachExplicitOldUnitAndLocationChoiceIsRetained() {
        for oldValue in [false, true] {
            let (name, defaults) = isolatedDefaults()
            defer { defaults.removePersistentDomain(forName: name) }
            defaults.set(oldValue, forKey: "weatherFahrenheit")
            defaults.set(oldValue, forKey: "weatherFollowsLocation")
            let weather = store(defaults, domain: name)
            XCTAssertEqual(weather.temperatureUnit, oldValue ? .fahrenheit : .celsius)
            XCTAssertEqual(weather.followsLocation, oldValue)
            XCTAssertEqual(defaults.object(forKey: "weatherFahrenheit") as? Bool, oldValue)
            XCTAssertEqual(defaults.object(forKey: "weatherFollowsLocation") as? Bool, oldValue)
        }
    }
    @MainActor func testExplicitOneShotStoresLocatedCityWithoutRewritingOldRawKeys() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let data = WeatherPreferences.encodedCity(newYork)
        defaults.set(data, forKey: "weatherCity")
        defaults.set(true, forKey: "weatherFollowsLocation")
        let weather = store(defaults, domain: name)
        XCTAssertEqual(weather.city, newYork); XCTAssertTrue(weather.followsLocation)
        let located = WeatherCity(id: -1, name: "Located city", latitude: 0, longitude: 0)
        let id = weather.beginLocationRequest()!
        XCTAssertTrue(weather.applyLocatedCity(located, requestID: id))
        XCTAssertEqual(weather.city, located)
        let restored = store(defaults, domain: name)
        XCTAssertEqual(restored.city, located); XCTAssertFalse(restored.followsLocation)
        XCTAssertEqual(defaults.data(forKey: "weatherCity"), data)
        XCTAssertEqual(defaults.object(forKey: "weatherFollowsLocation") as? Bool, true)
    }
    @MainActor func testNumericOrStringNewBooleanValuesCannotEnableLocation() {
        for value in [1 as Any, 2 as Any, -1 as Any, "true" as Any] {
            let (name, defaults) = isolatedDefaults()
            defer { defaults.removePersistentDomain(forName: name) }
            defaults.set(2, forKey: WeatherPreferences.versionKey)
            defaults.set(value, forKey: WeatherPreferences.followsLocationKey)
            defaults.set(value, forKey: WeatherPreferences.legacyDefaultsKey)
            let before = defaults.persistentDomain(forName: name)! as NSDictionary
            let weather = store(defaults, domain: name)
            XCTAssertFalse(weather.followsLocation); XCTAssertFalse(weather.legacyDefaults)
            XCTAssertNil(weather.city)
            XCTAssertEqual(defaults.persistentDomain(forName: name)! as NSDictionary, before)
        }
    }
    @MainActor func testExplicitNewChoicesWinEvenWhenMigrationMarkerIsMissing() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("demo", forKey: "homeMode")
        defaults.set(true, forKey: "weatherFahrenheit")
        defaults.set(true, forKey: "weatherFollowsLocation")
        let cityData = WeatherPreferences.encodedCity(newYork)
        defaults.set(cityData, forKey: WeatherPreferences.cityKey)
        defaults.set(false, forKey: WeatherPreferences.followsLocationKey)
        defaults.set("system", forKey: WeatherPreferences.unitKey)
        defaults.set(false, forKey: WeatherPreferences.legacyDefaultsKey)
        let weather = store(defaults, domain: name)
        XCTAssertEqual(weather.city, newYork); XCTAssertFalse(weather.followsLocation)
        XCTAssertEqual(weather.temperatureUnit, .system); XCTAssertFalse(weather.legacyDefaults)
        XCTAssertEqual(defaults.data(forKey: WeatherPreferences.cityKey), cityData)
        XCTAssertEqual(defaults.string(forKey: WeatherPreferences.unitKey), "system")
        XCTAssertEqual(defaults.object(forKey: WeatherPreferences.followsLocationKey) as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: WeatherPreferences.legacyDefaultsKey) as? Bool, false)
    }
    @MainActor func testKnownVersionWithMissingNewFieldsDoesNotReviveOldRawPreferences() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(2, forKey: WeatherPreferences.versionKey)
        defaults.set("demo", forKey: "homeMode")
        defaults.set(true, forKey: "weatherFahrenheit")
        defaults.set(true, forKey: "weatherFollowsLocation")
        defaults.set(WeatherPreferences.encodedCity(.philadelphia), forKey: "weatherCity")
        let weather = store(defaults, domain: name)
        XCTAssertNil(weather.city); XCTAssertFalse(weather.followsLocation)
        XCTAssertEqual(weather.temperatureUnit, .system); XCTAssertFalse(weather.legacyDefaults)
        for key in [WeatherPreferences.cityKey, WeatherPreferences.followsLocationKey, WeatherPreferences.unitKey, WeatherPreferences.legacyDefaultsKey] {
            XCTAssertNil(defaults.object(forKey: key))
        }
    }
    @MainActor func testUnknownVersionsRemainUntouchedAndDoNotInferLocationConsent() {
        for marker in [0 as Any, 1 as Any, 3 as Any, 99 as Any, "future" as Any] {
            let (name, defaults) = isolatedDefaults()
            defer { defaults.removePersistentDomain(forName: name) }
            defaults.set(marker, forKey: WeatherPreferences.versionKey)
            defaults.set("demo", forKey: "homeMode")
            defaults.set(true, forKey: "weatherFollowsLocation")
            let before = defaults.persistentDomain(forName: name)! as NSDictionary
            let weather = store(defaults, domain: name)
            XCTAssertNil(weather.city); XCTAssertFalse(weather.followsLocation)
            XCTAssertEqual(weather.temperatureUnit, .system); XCTAssertFalse(weather.legacyDefaults)
            XCTAssertEqual(defaults.persistentDomain(forName: name)! as NSDictionary, before)
        }
    }
    @MainActor func testUnknownVersionStillHonorsRecognizedExplicitNewValuesWithoutRewriting() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(99, forKey: WeatherPreferences.versionKey)
        defaults.set(WeatherPreferences.encodedCity(newYork), forKey: WeatherPreferences.cityKey)
        defaults.set(true, forKey: WeatherPreferences.followsLocationKey)
        defaults.set("celsius", forKey: WeatherPreferences.unitKey)
        defaults.set(false, forKey: WeatherPreferences.legacyDefaultsKey)
        let before = defaults.persistentDomain(forName: name)! as NSDictionary
        let weather = store(defaults, domain: name)
        XCTAssertEqual(weather.city, newYork); XCTAssertTrue(weather.followsLocation)
        XCTAssertEqual(weather.temperatureUnit, .celsius); XCTAssertFalse(weather.legacyDefaults)
        XCTAssertEqual(defaults.persistentDomain(forName: name)! as NSDictionary, before)
    }
    @MainActor func testUnknownNewRawValuesStayUntouchedUntilUserChooses() {
        for marker in [nil, 2] as [Int?] {
            let (name, defaults) = isolatedDefaults()
            defer { defaults.removePersistentDomain(forName: name) }
            if let marker { defaults.set(marker, forKey: WeatherPreferences.versionKey) }
            defaults.set(Data("not-json".utf8), forKey: WeatherPreferences.cityKey)
            defaults.set("not-a-boolean", forKey: WeatherPreferences.followsLocationKey)
            defaults.set("kelvin", forKey: WeatherPreferences.unitKey)
            defaults.set("unknown", forKey: WeatherPreferences.legacyDefaultsKey)
            let weather = store(defaults, domain: name)
            XCTAssertNil(weather.city); XCTAssertFalse(weather.followsLocation)
            XCTAssertEqual(weather.temperatureUnit, .system); XCTAssertFalse(weather.legacyDefaults)
            XCTAssertEqual(defaults.data(forKey: WeatherPreferences.cityKey), Data("not-json".utf8))
            XCTAssertEqual(defaults.string(forKey: WeatherPreferences.followsLocationKey), "not-a-boolean")
            XCTAssertEqual(defaults.string(forKey: WeatherPreferences.unitKey), "kelvin")
            XCTAssertEqual(defaults.string(forKey: WeatherPreferences.legacyDefaultsKey), "unknown")
            weather.select(newYork); weather.temperatureUnit = .celsius
            let restored = store(defaults, domain: name)
            XCTAssertEqual(restored.city, newYork); XCTAssertFalse(restored.followsLocation)
            XCTAssertEqual(restored.temperatureUnit, .celsius); XCTAssertFalse(restored.legacyDefaults)
        }
    }
    @MainActor func testExplicitClearedCityCannotFallBackToLegacyPhiladelphia() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("demo", forKey: "homeMode")
        defaults.set(WeatherPreferences.encodedCity(.philadelphia), forKey: "weatherCity")
        defaults.set(Data("null".utf8), forKey: WeatherPreferences.cityKey)
        defaults.set(false, forKey: WeatherPreferences.followsLocationKey)
        let weather = store(defaults, domain: name)
        XCTAssertNil(weather.city); XCTAssertFalse(weather.legacyDefaults)
        let id = weather.beginLocationRequest()!; weather.cancelLocationRequest(id)
        XCTAssertNil(weather.city)
    }
    @MainActor func testSystemTemperatureTracksRegionAndExplicitChoicePersistsIndependently() {
        XCTAssertTrue(WeatherTemperatureUnit.system.usesFahrenheit(locale: Locale(identifier: "en_US")))
        XCTAssertFalse(WeatherTemperatureUnit.system.usesFahrenheit(locale: Locale(identifier: "en_GB")))
        XCTAssertFalse(WeatherTemperatureUnit.system.usesFahrenheit(locale: Locale(identifier: "zh_CN")))
        XCTAssertTrue(WeatherTemperatureUnit.fahrenheit.usesFahrenheit(locale: Locale(identifier: "zh_CN")))
        XCTAssertFalse(WeatherTemperatureUnit.celsius.usesFahrenheit(locale: Locale(identifier: "en_US")))
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "weatherFahrenheit")
        let weather = store(defaults, domain: name)
        weather.temperatureUnit = .system
        XCTAssertEqual(store(defaults, domain: name).temperatureUnit, .system)
        XCTAssertEqual(defaults.object(forKey: "weatherFahrenheit") as? Bool, true)
    }
    @MainActor func testDemoDoesNotRequestWeatherAndCitySelectionPersists() async {
        let (name, defaults) = isolatedDefaults(), stub = WeatherStub()
        defer { defaults.removePersistentDomain(forName: name) }
        let weather = store(defaults, domain: name, client: stub, demo: true)
        XCTAssertNil(weather.city); XCTAssertFalse(weather.followsLocation)
        XCTAssertNil(weather.beginLocationRequest())
        await weather.refresh(force: true)
        let calls = await stub.calls; XCTAssertEqual(calls, 0); XCTAssertNil(weather.reading)
        weather.select(newYork); weather.fahrenheit = false
        let restored = store(defaults, domain: name, client: stub)
        XCTAssertEqual(restored.city, newYork); XCTAssertFalse(restored.followsLocation)
        XCTAssertFalse(restored.fahrenheit)
        let id = restored.beginLocationRequest()!
        let detected = WeatherCity(id: -1, name: "Detected city", latitude: 37.77, longitude: -122.42)
        XCTAssertTrue(restored.applyLocatedCity(detected, requestID: id))
        XCTAssertEqual(store(defaults, domain: name).city, detected, "An explicitly requested one-shot becomes the saved city")
        XCTAssertFalse(store(defaults, domain: name).followsLocation)
    }
    @MainActor func testRefreshThrottlesAndOfflineReadingIsMarked() async {
        let (name, defaults) = isolatedDefaults(), stub = WeatherStub()
        defer { defaults.removePersistentDomain(forName: name) }
        let weather = store(defaults, domain: name, client: stub)
        weather.select(.philadelphia)
        let now = WeatherReading.demo.date
        await weather.refresh(now: now)
        await weather.refresh(now: now.addingTimeInterval(60))
        var calls = await stub.calls; XCTAssertEqual(calls, 1)
        await stub.setFailure()
        await weather.refresh(force: true, now: now.addingTimeInterval(900))
        calls = await stub.calls; XCTAssertEqual(calls, 2)
        XCTAssertTrue(weather.failed); XCTAssertEqual(weather.reading, .demo)
        XCTAssertTrue(weather.stale(at: now.addingTimeInterval(3601)))
        XCTAssertFalse(weather.loading)
    }
    @MainActor func testLateResponseCannotReplaceAnotherCityOrDemoMode() async {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let started = expectation(description: "request started")
        let stub = WeatherStub { started.fulfill() }; await stub.setHold()
        let weather = store(defaults, domain: name, client: stub)
        weather.select(.philadelphia)
        let task = Task { await weather.refresh() }
        await fulfillment(of: [started], timeout: 2)
        weather.select(WeatherCity(id: 1, name: "Other city", latitude: 0, longitude: 0))
        weather.setDemo(true)
        await stub.finish(); await task.value
        XCTAssertNil(weather.reading); XCTAssertEqual(weather.city?.name, "Other city")
        XCTAssertFalse(weather.loading); XCTAssertFalse(weather.failed)
    }
    @MainActor private func waitForLocationToFinish(_ location: WeatherLocation) async {
        let finished = expectation(for: NSPredicate { _, _ in !location.isLocating }, evaluatedWith: nil)
        await fulfillment(of: [finished], timeout: 2)
    }
    @MainActor func testLocationResultRequiresCurrentExplicitIntentAndCannotOverrideManualChoiceOrDemo() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let weather = store(defaults, domain: name)
        let detected = WeatherCity(id: -1, name: "Detected city", latitude: 40, longitude: -75)
        XCTAssertFalse(weather.applyLocatedCity(detected, requestID: UUID())); XCTAssertNil(weather.city)
        let first = weather.beginLocationRequest()!, second = weather.beginLocationRequest()!
        XCTAssertFalse(weather.applyLocatedCity(detected, requestID: first))
        weather.cancelLocationRequest(first)
        XCTAssertTrue(weather.isLocationRequestCurrent(second), "Canceling an old request cannot cancel a later tap")
        weather.select(.philadelphia)
        XCTAssertFalse(weather.applyLocatedCity(detected, requestID: second)); XCTAssertEqual(weather.city, .philadelphia)
        let canceled = weather.beginLocationRequest()!; weather.cancelLocationRequest(canceled)
        XCTAssertFalse(weather.applyLocatedCity(detected, requestID: canceled))
        let pending = weather.beginLocationRequest()!; weather.setDemo(true)
        XCTAssertFalse(weather.applyLocatedCity(detected, requestID: pending)); XCTAssertNil(weather.beginLocationRequest())
        XCTAssertEqual(weather.city, .philadelphia)
    }
    @MainActor func testPassiveRefreshCannotRequestPermissionButExplicitActionCan() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "weatherFollowsLocation")
        let weather = store(defaults, domain: name)
        let fake = WeatherLocationStub(.notDetermined)
        var constructions = 0
        let location = WeatherLocation(makeManager: { constructions += 1; return fake })
        location.update(weather, force: true); location.setScenePhase(.active)
        XCTAssertEqual(constructions, 0, "Old follow preferences never create a passive manager")
        location.requestCurrentLocation(weather)
        XCTAssertEqual(constructions, 1); XCTAssertEqual(fake.permissionRequests, 1); XCTAssertEqual(fake.fixRequests, 0)
        location.update(weather, force: true)
        XCTAssertEqual(fake.permissionRequests, 1, "Passive refresh cannot reuse permission-prompt intent")
        fake.authorizationStatus = .authorizedWhenInUse
        location.authorizationChanged(from: fake)
        XCTAssertEqual(fake.fixRequests, 1)
        location.authorizationChanged(from: fake); location.update(weather)
        XCTAssertEqual(fake.fixRequests, 1)
        location.stop(); XCTAssertNil(fake.delegate); XCTAssertEqual(fake.stops, 1)
    }
    @MainActor func testAuthorizedLegacyFollowNeverLocatesOnInitializationForecastRefreshOrForeground() async {
        let (name, defaults) = isolatedDefaults(), client = WeatherStub()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "keepAwake")
        let weather = store(defaults, domain: name, client: client)
        let fake = WeatherLocationStub(.authorizedWhenInUse)
        var constructions = 0
        let location = WeatherLocation(makeManager: { constructions += 1; return fake })
        location.update(weather); location.update(weather, force: true)
        location.setScenePhase(.inactive); location.setScenePhase(.active)
        await weather.refresh(force: true)
        XCTAssertTrue(weather.followsLocation, "Historical raw preference is preserved, not used as live intent")
        XCTAssertEqual(constructions, 0); XCTAssertEqual(fake.fixRequests, 0); XCTAssertEqual(fake.permissionRequests, 0)
        let forecastCalls = await client.calls; XCTAssertEqual(forecastCalls, 1, "Saved-city weather refresh is independent of location")
    }
    @MainActor func testInactivePermissionAlertRetainsExplicitIntentButActualBackgroundCancels() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let weather = store(defaults, domain: name)
        weather.select(newYork)
        let fake = WeatherLocationStub(.notDetermined)
        var constructions = 0
        let location = WeatherLocation(makeManager: { constructions += 1; return fake })
        location.requestCurrentLocation(weather)
        location.setScenePhase(.inactive)
        XCTAssertTrue(location.isLocating); XCTAssertNotNil(fake.delegate); XCTAssertEqual(fake.stops, 0)
        fake.authorizationStatus = .authorizedWhenInUse; location.authorizationChanged(from: fake)
        XCTAssertEqual(fake.permissionRequests, 1); XCTAssertEqual(fake.fixRequests, 1)
        location.setScenePhase(.background)
        XCTAssertFalse(location.isLocating); XCTAssertNil(fake.delegate); XCTAssertEqual(fake.stops, 1)
        location.authorizationChanged(from: fake); location.setScenePhase(.active); location.update(weather)
        XCTAssertEqual(constructions, 1); XCTAssertEqual(fake.fixRequests, 1); XCTAssertEqual(weather.city, newYork)
    }
    @MainActor func testDemoAndInitializationNeverConstructALocationManager() async {
        let (name, defaults) = isolatedDefaults(), stub = WeatherStub()
        defer { defaults.removePersistentDomain(forName: name) }
        let weather = store(defaults, domain: name, client: stub, demo: true)
        var constructions = 0
        let location = WeatherLocation(makeManager: { constructions += 1; return WeatherLocationStub(.notDetermined) })
        location.update(weather, force: true); location.requestCurrentLocation(weather); location.setScenePhase(.active)
        await weather.refresh(force: true)
        let calls = await stub.calls
        XCTAssertEqual(constructions, 0); XCTAssertEqual(calls, 0); XCTAssertFalse(weather.followsLocation)
    }
    @MainActor func testLocationDenialAndDeviceFailurePreserveCityAndReleaseManager() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let weather = store(defaults, domain: name)
        let denied = WeatherLocationStub(.denied)
        let location = WeatherLocation(makeManager: { denied })
        location.requestCurrentLocation(weather)
        XCTAssertNil(weather.city); XCTAssertFalse(location.isLocating)
        XCTAssertEqual(location.message, "Location is off. Choose a city manually.".tr)
        XCTAssertNil(denied.delegate); XCTAssertEqual(denied.stops, 1)
        weather.select(newYork); location.requestCurrentLocation(weather)
        XCTAssertEqual(location.message, "Location is off. Keeping your previous city.".tr)
        XCTAssertEqual(store(defaults, domain: name).city, newYork)
        let failing = WeatherLocationStub(.authorizedWhenInUse)
        let retry = WeatherLocation(makeManager: { failing })
        retry.requestCurrentLocation(weather); retry.receivedFailure(from: failing)
        XCTAssertEqual(weather.city, newYork); XCTAssertFalse(retry.isLocating)
        XCTAssertNil(failing.delegate); XCTAssertEqual(failing.stops, 1)
        XCTAssertEqual(retry.message, "Location unavailable. Keeping your previous city. Choose a city or try Locate once again.".tr)
    }
    @MainActor func testOnlyIdentifiedLegacyCityIsRetainedAndFailureCannotReviveClearedCity() {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "photoSlideshow")
        let weather = store(defaults, domain: name)
        let fake = WeatherLocationStub(.restricted)
        let location = WeatherLocation(makeManager: { fake })
        location.update(weather)
        XCTAssertEqual(weather.city, .philadelphia); XCTAssertTrue(weather.legacyDefaults)
        XCTAssertEqual(fake.stops, 0); XCTAssertEqual(fake.permissionRequests, 0)
        location.requestCurrentLocation(weather)
        XCTAssertEqual(weather.city, .philadelphia); XCTAssertFalse(location.isLocating)
        XCTAssertEqual(fake.permissionRequests, 0); XCTAssertNil(fake.delegate)
        weather.select(nil); location.requestCurrentLocation(weather)
        XCTAssertNil(weather.city); XCTAssertFalse(weather.legacyDefaults)
    }
    @MainActor func testOneShotSuccessPersistsCityAndReleasesManagerAndGeocoder() async {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let weather = store(defaults, domain: name)
        weather.select(newYork); weather.temperatureUnit = .celsius
        let fake = WeatherLocationStub(.authorizedWhenInUse)
        let began = expectation(description: "controlled reverse geocoder began")
        let coder = WeatherGeocoderStub { began.fulfill() }
        let location = WeatherLocation(makeManager: { fake }, makeGeocoder: { coder })
        location.requestCurrentLocation(weather)
        XCTAssertEqual(fake.fixRequests, 1); XCTAssertTrue(location.isLocating)
        location.receivedLocations([CLLocation(latitude: 37.77, longitude: -122.42)], from: fake)
        XCTAssertNil(fake.delegate); XCTAssertEqual(fake.stops, 1, "Release location hardware after the one valid fix")
        await fulfillment(of: [began], timeout: 2)
        let detected = WeatherCity(id: -1, name: "Detected city", latitude: 37.77, longitude: -122.42)
        coder.finish(.success(detected)); await waitForLocationToFinish(location)
        XCTAssertEqual(weather.city, detected); XCTAssertEqual(store(defaults, domain: name).city, detected)
        XCTAssertEqual(store(defaults, domain: name).temperatureUnit, .celsius)
        XCTAssertFalse(weather.followsLocation); XCTAssertEqual(coder.cancellations, 1)
        XCTAssertEqual(location.message, L10n.format("City saved · %@", detected.displayName))
        location.update(weather, force: true); location.setScenePhase(.active)
        XCTAssertEqual(fake.fixRequests, 1, "Successful city remains fixed until another explicit tap")
    }
    @MainActor func testGeocoderFailureKeepsSavedCityAndAllowsExplicitRetry() async {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let weather = store(defaults, domain: name); weather.select(newYork)
        let first = WeatherLocationStub(.authorizedWhenInUse), second = WeatherLocationStub(.authorizedWhenInUse)
        let began = expectation(description: "reverse geocoder began")
        let coder = WeatherGeocoderStub { began.fulfill() }
        var constructions = 0
        let location = WeatherLocation(makeManager: { constructions += 1; return constructions == 1 ? first : second }, makeGeocoder: { coder })
        location.requestCurrentLocation(weather)
        location.receivedLocations([CLLocation(latitude: 37.77, longitude: -122.42)], from: first)
        await fulfillment(of: [began], timeout: 2)
        coder.finish(.failure(URLError(.notConnectedToInternet))); await waitForLocationToFinish(location)
        XCTAssertEqual(weather.city, newYork); XCTAssertEqual(store(defaults, domain: name).city, newYork)
        XCTAssertEqual(coder.cancellations, 1); XCTAssertNil(first.delegate)
        location.update(weather); XCTAssertEqual(constructions, 1)
        location.requestCurrentLocation(weather)
        XCTAssertEqual(constructions, 2); XCTAssertEqual(second.fixRequests, 1)
        location.stop(); XCTAssertNil(second.delegate)
    }
    @MainActor func testOneShotTimeoutBoundsPendingGeocoderAndIgnoresItsLateSuccess() async {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let weather = store(defaults, domain: name); weather.select(newYork)
        let fake = WeatherLocationStub(.authorizedWhenInUse)
        let began = expectation(description: "geocoder began"), timeoutBegan = expectation(description: "timeout began")
        let coder = WeatherGeocoderStub { began.fulfill() }, timer = WeatherTimeoutStub { timeoutBegan.fulfill() }
        let location = WeatherLocation(makeManager: { fake }, makeGeocoder: { coder }, sleep: { try await timer.sleep($0) })
        location.requestCurrentLocation(weather)
        location.receivedLocations([CLLocation(latitude: 37.77, longitude: -122.42)], from: fake)
        await fulfillment(of: [began, timeoutBegan], timeout: 2)
        XCTAssertEqual(timer.durations, [.seconds(20)])
        timer.finish(); await waitForLocationToFinish(location)
        XCTAssertEqual(location.message, "Location took too long. Keeping your previous city. Choose a city or try Locate once again.".tr)
        XCTAssertEqual(coder.cancellations, 1); XCTAssertEqual(weather.city, newYork)
        coder.finish(.success(.philadelphia))
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(store(defaults, domain: name).city, newYork)
        XCTAssertFalse(location.isLocating); XCTAssertNil(fake.delegate)
    }
    @MainActor func testOneShotTimeoutBeforeFixReleasesManagerAndDoesNotRetryOnResume() async {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let weather = store(defaults, domain: name)
        let fake = WeatherLocationStub(.authorizedWhenInUse)
        let began = expectation(description: "timeout began"), timer = WeatherTimeoutStub()
        let location = WeatherLocation(makeManager: { fake }, sleep: { duration in began.fulfill(); try await timer.sleep(duration) })
        location.requestCurrentLocation(weather)
        await fulfillment(of: [began], timeout: 2)
        timer.finish(); await waitForLocationToFinish(location)
        XCTAssertNil(weather.city); XCTAssertNil(fake.delegate); XCTAssertEqual(fake.stops, 1)
        XCTAssertEqual(location.message, "Location took too long. Choose a city manually or try Locate once again.".tr)
        location.setScenePhase(.active); location.update(weather)
        location.receivedLocations([CLLocation(latitude: 37.77, longitude: -122.42)], from: fake)
        XCTAssertNil(weather.city); XCTAssertEqual(fake.fixRequests, 1)
    }
    @MainActor func testManualSelectionWhileGeocoderIsPendingRejectsLateResultAndCleansUp() async {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let weather = store(defaults, domain: name)
        let fake = WeatherLocationStub(.authorizedWhenInUse)
        let began = expectation(description: "geocoder began")
        // Confirm the controlled task has actually suspended.
        let observedCoder = WeatherGeocoderStub { began.fulfill() }
        let controlled = WeatherLocation(makeManager: { fake }, makeGeocoder: { observedCoder })
        controlled.requestCurrentLocation(weather)
        controlled.receivedLocations([CLLocation(latitude: 37.77, longitude: -122.42)], from: fake)
        await fulfillment(of: [began], timeout: 2)
        weather.select(newYork) // Intentionally omit location.stop to verify the store's independent guard.
        observedCoder.finish(.success(.philadelphia)); await waitForLocationToFinish(controlled)
        XCTAssertEqual(weather.city, newYork); XCTAssertEqual(store(defaults, domain: name).city, newYork)
        XCTAssertEqual(observedCoder.cancellations, 1); XCTAssertNil(fake.delegate)
    }
    @MainActor func testCanceledAndBackgroundGeocodingCannotOverwriteLaterSelection() async {
        for background in [false, true] {
            let (name, defaults) = isolatedDefaults()
            defer { defaults.removePersistentDomain(forName: name) }
            let weather = store(defaults, domain: name); weather.select(newYork)
            let fake = WeatherLocationStub(.authorizedWhenInUse)
            let began = expectation(description: "geocoder began")
            let observedCoder = WeatherGeocoderStub { began.fulfill() }
            let location = WeatherLocation(makeManager: { fake }, makeGeocoder: { observedCoder })
            location.requestCurrentLocation(weather)
            location.receivedLocations([CLLocation(latitude: 37.77, longitude: -122.42)], from: fake)
            await fulfillment(of: [began], timeout: 2)
            if background { location.setScenePhase(.background) } else { location.stop() }
            XCTAssertFalse(location.isLocating); XCTAssertEqual(observedCoder.cancellations, 1)
            let manual = WeatherCity(id: 123, name: "Later chosen city", latitude: 0, longitude: 0)
            weather.select(manual); observedCoder.finish(.success(.philadelphia))
            for _ in 0..<10 { await Task.yield() }
            XCTAssertEqual(weather.city, manual); XCTAssertEqual(store(defaults, domain: name).city, manual)
            XCTAssertNil(fake.delegate); XCTAssertEqual(fake.stops, 1)
        }
    }
    @MainActor func testLateOldGeocoderCannotStopOrOverwriteANewerExplicitRequest() async {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let weather = store(defaults, domain: name); weather.select(newYork)
        let first = WeatherLocationStub(.authorizedWhenInUse), second = WeatherLocationStub(.authorizedWhenInUse)
        let firstBegan = expectation(description: "old geocoder began"), secondBegan = expectation(description: "new geocoder began")
        let firstCoder = WeatherGeocoderStub { firstBegan.fulfill() }, secondCoder = WeatherGeocoderStub { secondBegan.fulfill() }
        var managerCount = 0, geocoderCount = 0
        let location = WeatherLocation(makeManager: {
            managerCount += 1; return managerCount == 1 ? first : second
        }, makeGeocoder: {
            geocoderCount += 1; return geocoderCount == 1 ? firstCoder : secondCoder
        })
        location.requestCurrentLocation(weather)
        location.receivedLocations([CLLocation(latitude: 37.77, longitude: -122.42)], from: first)
        await fulfillment(of: [firstBegan], timeout: 2)
        location.requestCurrentLocation(weather)
        XCTAssertEqual(firstCoder.cancellations, 1); XCTAssertEqual(second.fixRequests, 1)
        firstCoder.finish(.success(.philadelphia))
        for _ in 0..<10 { await Task.yield() }
        XCTAssertTrue(location.isLocating); XCTAssertNotNil(second.delegate); XCTAssertEqual(weather.city, newYork)
        location.receivedLocations([CLLocation(latitude: 40.71, longitude: -74)], from: second)
        await fulfillment(of: [secondBegan], timeout: 2)
        let newCity = WeatherCity(id: -1, name: "New explicit result", latitude: 40.71, longitude: -74)
        secondCoder.finish(.success(newCity)); await waitForLocationToFinish(location)
        XCTAssertEqual(weather.city, newCity); XCTAssertEqual(store(defaults, domain: name).city, newCity)
        XCTAssertNil(second.delegate); XCTAssertEqual(secondCoder.cancellations, 1)
    }
    @MainActor func testInvalidFixAndInvalidGeocodedCityLeaveExistingSelectionUnchanged() async {
        let (name, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let weather = store(defaults, domain: name); weather.select(newYork)
        let fake = WeatherLocationStub(.authorizedWhenInUse)
        let location = WeatherLocation(makeManager: { fake })
        location.requestCurrentLocation(weather); location.receivedLocations([], from: fake)
        XCTAssertFalse(location.isLocating); XCTAssertEqual(weather.city, newYork); XCTAssertNil(fake.delegate)
        let id = weather.beginLocationRequest()!
        XCTAssertFalse(weather.applyLocatedCity(WeatherCity(id: -1, name: "Invalid", latitude: 999, longitude: 0), requestID: id))
        XCTAssertEqual(weather.city, newYork); weather.cancelLocationRequest(id)
    }
}
