import XCTest
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

final class WeatherTests: XCTestCase {
    private let json = #"{"current":{"time":1792032300,"temperature_2m":21.0,"weather_code":0,"is_day":0},"daily":{"temperature_2m_max":[26.8],"temperature_2m_min":[18.1]}}"#
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
    @MainActor func testDemoDoesNotRequestWeatherAndCitySelectionPersists() async {
        let name = "WeatherTests.\(UUID())", stub = WeatherStub()
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = WeatherStore(defaults: defaults, client: stub, demo: true)
        XCTAssertEqual(store.city, .philadelphia); XCTAssertTrue(store.followsLocation)
        await store.refresh(force: true)
        let calls = await stub.calls; XCTAssertEqual(calls, 0); XCTAssertNil(store.reading)
        store.select(WeatherCity(id: 5128581, name: "New York", latitude: 40.71, longitude: -74))
        store.fahrenheit = false
        let restored = WeatherStore(defaults: defaults, client: stub)
        XCTAssertEqual(restored.city?.name, "New York"); XCTAssertFalse(restored.followsLocation)
        XCTAssertFalse(restored.fahrenheit)
        restored.enableLocation()
        let automatic = WeatherStore(defaults: defaults, client: stub)
        XCTAssertEqual(automatic.city, .philadelphia) // Never persist an automatically detected GPS point.
    }
    @MainActor func testRefreshThrottlesAndOfflineReadingIsMarked() async {
        let name = "WeatherTests.\(UUID())", stub = WeatherStub()
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = WeatherStore(defaults: defaults, client: stub)
        let now = WeatherReading.demo.date
        await store.refresh(now: now)
        await store.refresh(now: now.addingTimeInterval(60))
        var calls = await stub.calls; XCTAssertEqual(calls, 1)
        await stub.setFailure()
        await store.refresh(force: true, now: now.addingTimeInterval(900))
        calls = await stub.calls; XCTAssertEqual(calls, 2)
        XCTAssertTrue(store.failed); XCTAssertEqual(store.reading, .demo)
        XCTAssertTrue(store.stale(at: now.addingTimeInterval(3601)))
        XCTAssertFalse(store.loading)
    }
    @MainActor func testLateResponseCannotReplaceAnotherCityOrDemoMode() async {
        let name = "WeatherTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let started = expectation(description: "request started")
        let stub = WeatherStub { started.fulfill() }; await stub.setHold()
        let store = WeatherStore(defaults: defaults, client: stub)
        let task = Task { await store.refresh() }
        await fulfillment(of: [started], timeout: 2)
        store.select(WeatherCity(id: 1, name: "Other city", latitude: 0, longitude: 0))
        store.setDemo(true)
        await stub.finish(); await task.value
        XCTAssertNil(store.reading); XCTAssertEqual(store.city?.name, "Other city")
        XCTAssertFalse(store.loading); XCTAssertFalse(store.failed)
    }
    @MainActor func testLocationUpdatesCannotOverrideManualChoiceOrDemo() {
        let name = "WeatherTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = WeatherStore(defaults: defaults, client: WeatherStub())
        let detected = WeatherCity(id: -1, name: "Detected city", latitude: 40, longitude: -75)
        store.applyLocatedCity(detected); XCTAssertEqual(store.city, detected)
        store.select(.philadelphia); store.applyLocatedCity(detected)
        XCTAssertEqual(store.city, .philadelphia)
        store.enableLocation(); store.setDemo(true); store.applyLocatedCity(detected)
        XCTAssertEqual(store.city, .philadelphia)
    }
}
