import Foundation
import CoreFoundation
import SwiftUI

struct WeatherCity: Codable, Identifiable, Equatable {
    static let philadelphia = WeatherCity(id: 4560349, name: "Philadelphia", latitude: 39.9526, longitude: -75.1652, admin1: "Pennsylvania", country: "United States")
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    var admin1: String? = nil
    var country: String? = nil
    var displayName: String { id == Self.philadelphia.id ? name.tr : name }
    var detail: String { [admin1, country].compactMap { $0 }.map { id == Self.philadelphia.id ? $0.tr : $0 }.joined(separator: ", ") }
    var valid: Bool { latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude) }
}

struct WeatherReading: Equatable {
    let temperature: Double
    let high: Double
    let low: Double
    let code: Int
    let isDay: Bool
    let date: Date
    static let demo = WeatherReading(temperature: 12.2222, high: 13.8889, low: 9.4444, code: 2, isDay: true, date: Date(timeIntervalSince1970: 1791981300))
    func degrees(_ value: Double, fahrenheit: Bool) -> String {
        String(format: "%.0f°", fahrenheit ? value * 9 / 5 + 32 : value)
    }
    var condition: String {
        switch code {
        case 0: return "Clear".tr
        case 1: return "Mostly Clear".tr
        case 2: return "Partly Cloudy".tr
        case 3: return "Overcast".tr
        case 45, 48: return "Fog".tr
        case 51, 53, 55: return "Drizzle".tr
        case 56, 57, 66, 67: return "Freezing Rain".tr
        case 61, 63, 65: return "Rain".tr
        case 71, 73, 75, 77: return "Snow".tr
        case 80, 81, 82: return "Rain Showers".tr
        case 85, 86: return "Snow Showers".tr
        case 95, 96, 99: return "Thunderstorms".tr
        default: return "Conditions Unknown".tr
        }
    }
    var symbol: String {
        switch code {
        case 0, 1: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud"
        }
    }
}

protocol WeatherProviding {
    func search(_ name: String) async throws -> [WeatherCity]
    func fetch(_ city: WeatherCity) async throws -> WeatherReading
}

enum WeatherError: Error { case response, invalidData }

struct OpenMeteoClient: WeatherProviding {
    var session: URLSession = URLSession(configuration: .ephemeral)
    static func forecastURL(_ city: WeatherCity) -> URL {
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = ["latitude": String(city.latitude), "longitude": String(city.longitude),
                          "current": "temperature_2m,weather_code,is_day", "daily": "temperature_2m_max,temperature_2m_min",
                          "temperature_unit": "celsius", "timezone": "auto", "timeformat": "unixtime", "forecast_days": "1"]
            .sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return url.url!
    }
    private func get(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count < 1_000_000 else { throw WeatherError.response }
        return data
    }
    func search(_ name: String) async throws -> [WeatherCity] {
        var url = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        url.queryItems = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "count", value: "8"), URLQueryItem(name: "language", value: L10n.locale.language.languageCode?.identifier ?? "en"), URLQueryItem(name: "format", value: "json")]
        struct Response: Decodable { let results: [WeatherCity]? }
        return try JSONDecoder().decode(Response.self, from: await get(url.url!)).results?.filter(\.valid) ?? []
    }
    func fetch(_ city: WeatherCity) async throws -> WeatherReading {
        guard city.valid else { throw WeatherError.invalidData }
        return try Self.decode(await get(Self.forecastURL(city)))
    }
    static func decode(_ data: Data) throws -> WeatherReading {
        struct Response: Decodable {
            struct Current: Decodable { let time: Double; let temperature_2m: Double; let weather_code: Int; let is_day: Int }
            struct Daily: Decodable { let temperature_2m_max: [Double?]; let temperature_2m_min: [Double?] }
            let current: Current
            let daily: Daily
        }
        let value = try JSONDecoder().decode(Response.self, from: data)
        guard let high = value.daily.temperature_2m_max.first ?? nil, let low = value.daily.temperature_2m_min.first ?? nil,
              [high, low, value.current.temperature_2m, value.current.time].allSatisfy(\.isFinite), high >= low,
              (0...1).contains(value.current.is_day) else { throw WeatherError.invalidData }
        return WeatherReading(temperature: value.current.temperature_2m, high: high, low: low, code: value.current.weather_code,
                              isDay: value.current.is_day == 1, date: Date(timeIntervalSince1970: value.current.time))
    }
}

/// The stored choice is independent of the current device region.
enum WeatherTemperatureUnit: String, CaseIterable, Identifiable {
    case system, celsius, fahrenheit
    var id: String { rawValue }
    var title: String {
        switch self { case .system: return "System".tr; case .celsius: return "°C".tr; case .fahrenheit: return "°F".tr }
    }
    func usesFahrenheit(locale: Locale = .autoupdatingCurrent) -> Bool {
        switch self {
        case .system: return locale.measurementSystem == .us
        case .celsius: return false
        case .fahrenheit: return true
        }
    }
}

/// Only new keys are written. Legacy raw preferences remain available unchanged.
struct WeatherPreferences {
    static let version = 2
    static let versionKey = "weather.preferencesVersion"
    static let cityKey = "weather.citySelection"
    static let followsLocationKey = "weather.followsLocation"
    static let unitKey = "weather.temperatureUnit"
    static let legacyDefaultsKey = "weather.legacyDefaults"
    static let legacyWeatherKeys = ["weatherCity", "weatherFahrenheit", "weatherFollowsLocation"]
    static let legacyAppKeys = [
        "homeMode", "appLanguage", "keepAwake", "photoSlideshow", "selectedHomeID", "photoAlbumID",
        "homeWidgetLayouts", "homeShortcuts", "tealWallpaper", "showPersonal",
        "display.automaticStandby", "display.standbyDelay", "display.motionWake", "display.faceWake",
        "display.faceForegroundConsentVersion", "display.proximityWake", "display.nightMode",
        "display.nightStartHour", "display.nightEndHour"
    ]
    let city: WeatherCity?
    let followsLocation: Bool
    let temperatureUnit: WeatherTemperatureUnit
    let legacyDefaults: Bool

    static func savedBool(_ raw: Any?) -> Bool? {
        guard let value = raw as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return value.boolValue
    }
    static func savedCity(_ raw: Any?) -> WeatherCity? {
        guard let data = raw as? Data else { return nil }
        do {
            let value = try JSONDecoder().decode(WeatherCity?.self, from: data)
            return value?.valid == true ? value : nil
        } catch { return nil }
    }
    static func encodedCity(_ city: WeatherCity?) -> Data {
        // Optional.none is encoded as JSON null: a deliberate clear differs from a missing key.
        (try? JSONEncoder().encode(city)) ?? Data("null".utf8)
    }
    static func load(defaults: UserDefaults, persistentDomainName: String?) -> Self {
        let marker = defaults.object(forKey: versionKey)
        let firstMigration = marker == nil
        // A marker with an unknown value is not permission to overwrite future settings.
        let persistent = persistentDomainName.flatMap { defaults.persistentDomain(forName: $0) } ?? [:]
        let legacyEvidence = firstMigration && (
            legacyWeatherKeys.contains { persistent[$0] != nil }
            || legacyAppKeys.contains { persistent[$0] != nil }
        )
        let rawCity = defaults.object(forKey: cityKey)
        let rawFollow = defaults.object(forKey: followsLocationKey)
        let rawUnit = defaults.object(forKey: unitKey)
        let rawLegacy = defaults.object(forKey: legacyDefaultsKey)
        let oldCity = firstMigration ? savedCity(defaults.object(forKey: "weatherCity")) : nil
        let selectedCity: WeatherCity? = rawCity != nil ? savedCity(rawCity) : oldCity ?? (legacyEvidence ? .philadelphia : nil)
        let follow: Bool
        if rawFollow != nil { follow = savedBool(rawFollow) ?? false }
        else if firstMigration { follow = savedBool(defaults.object(forKey: "weatherFollowsLocation")) ?? legacyEvidence }
        else { follow = false }
        let unit: WeatherTemperatureUnit
        if rawUnit != nil { unit = (rawUnit as? String).flatMap(WeatherTemperatureUnit.init(rawValue:)) ?? .system }
        else if firstMigration, let oldFahrenheit = savedBool(defaults.object(forKey: "weatherFahrenheit")) {
            unit = oldFahrenheit ? .fahrenheit : .celsius
        } else { unit = legacyEvidence ? .fahrenheit : .system }
        let legacy = rawLegacy != nil ? (savedBool(rawLegacy) ?? false)
            : legacyEvidence && rawCity == nil && oldCity == nil
        let result = Self(city: selectedCity, followsLocation: follow, temperatureUnit: unit, legacyDefaults: legacy)
        if firstMigration {
            // Do not replace an existing explicit or unrecognized new raw choice.
            if rawCity == nil { defaults.set(encodedCity(result.city), forKey: cityKey) }
            if rawFollow == nil { defaults.set(result.followsLocation, forKey: followsLocationKey) }
            if rawUnit == nil { defaults.set(result.temperatureUnit.rawValue, forKey: unitKey) }
            if rawLegacy == nil { defaults.set(result.legacyDefaults, forKey: legacyDefaultsKey) }
            defaults.set(version, forKey: versionKey)
        }
        return result
    }
}

@MainActor final class WeatherStore: ObservableObject {
    @Published private(set) var city: WeatherCity?
    @Published private(set) var reading: WeatherReading?
    @Published private(set) var loading = false
    @Published private(set) var failed = false
    @Published private(set) var demo: Bool
    /// Historical preference only; never used to start location or infer permission.
    @Published private(set) var followsLocation: Bool
    @Published var temperatureUnit: WeatherTemperatureUnit {
        didSet {
            defaults.set(temperatureUnit.rawValue, forKey: WeatherPreferences.unitKey)
            recordVersion()
        }
    }
    /// Compatibility for existing display call sites; new UI persists the explicit three-way choice.
    var fahrenheit: Bool {
        get { temperatureUnit.usesFahrenheit(locale: unitLocale) }
        set { temperatureUnit = newValue ? .fahrenheit : .celsius }
    }
    private(set) var legacyDefaults: Bool
    var usesLegacyPhiladelphia: Bool { legacyDefaults && city?.id == WeatherCity.philadelphia.id }
    let client: any WeatherProviding
    private let defaults: UserDefaults
    private let unitLocale: Locale
    private var requestID = UUID()
    private var locationRequestID: UUID?
    private var lastAttempt: Date?
    init(defaults: UserDefaults = .standard, client: any WeatherProviding = OpenMeteoClient(), demo: Bool = false,
         persistentDomainName: String? = Bundle.main.bundleIdentifier, unitLocale: Locale = .autoupdatingCurrent) {
        self.defaults = defaults; self.client = client; self.demo = demo; self.unitLocale = unitLocale
        let saved = WeatherPreferences.load(defaults: defaults, persistentDomainName: persistentDomainName)
        city = saved.city; followsLocation = saved.followsLocation
        temperatureUnit = saved.temperatureUnit; legacyDefaults = saved.legacyDefaults
    }
    private func recordVersion() { defaults.set(WeatherPreferences.version, forKey: WeatherPreferences.versionKey) }
    func setDemo(_ value: Bool) {
        guard value != demo else { return }
        demo = value; locationRequestID = nil; invalidate()
    }
    private func invalidate() { requestID = UUID(); reading = nil; loading = false; failed = false; lastAttempt = nil }
    func select(_ value: WeatherCity?) {
        guard value == nil || value!.valid else { return }
        locationRequestID = nil
        followsLocation = false; legacyDefaults = false
        invalidate(); city = value
        defaults.set(false, forKey: WeatherPreferences.followsLocationKey)
        defaults.set(false, forKey: WeatherPreferences.legacyDefaultsKey)
        defaults.set(WeatherPreferences.encodedCity(value), forKey: WeatherPreferences.cityKey)
        recordVersion()
    }
    /// Ephemeral intent belongs to one explicit tap, never a saved follow-location flag.
    func beginLocationRequest() -> UUID? {
        guard !demo else { return nil }
        let id = UUID(); locationRequestID = id; return id
    }
    func isLocationRequestCurrent(_ id: UUID) -> Bool { !demo && locationRequestID == id }
    func cancelLocationRequest(_ id: UUID) {
        if locationRequestID == id { locationRequestID = nil }
    }
    @discardableResult func applyLocatedCity(_ city: WeatherCity, requestID: UUID) -> Bool {
        guard isLocationRequestCurrent(requestID), city.valid else { return false }
        // A successful one-shot lookup is now an ordinary persistent city selection.
        select(city)
        return true
    }
    func refresh(force: Bool = false, now: Date = .now) async {
        guard !demo, let city, !loading else { return }
        if !force, let lastAttempt, (reading != nil || failed), now.timeIntervalSince(lastAttempt) < (failed ? 120 : 900) { return }
        let id = UUID(); requestID = id; lastAttempt = now; loading = true
        defer { if requestID == id { loading = false } }
        do {
            let result = try await client.fetch(city)
            if Task.isCancelled { if requestID == id { lastAttempt = nil }; return }
            guard requestID == id, !demo, self.city == city else { return }
            reading = result; failed = false
        } catch {
            if Task.isCancelled { if requestID == id { lastAttempt = nil }; return }
            guard requestID == id, !demo else { return }
            failed = true
        }
    }
    func stale(at date: Date = .now) -> Bool { reading.map { date.timeIntervalSince($0.date) > 3600 } ?? false }
}

struct WeatherPanel: View {
    @ObservedObject var weather: WeatherStore
    @ObservedObject var location: WeatherLocation
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var results: [WeatherCity] = []
    @State private var searching = false
    @State private var searchMessage: String?
    var body: some View {
        Form {
            if weather.demo {
                Section { Text("DEMO · Fixed sample weather. Leave demo mode in Settings to use live weather.".tr).accessibilityIdentifier("weatherDemoNotice") }
            } else {
                Section("Choose a city".tr) {
                    if let city = weather.city {
                        Text(city.displayName).font(.headline).accessibilityIdentifier("weatherSelectedCity")
                        Text(city.detail).foregroundStyle(.secondary)
                        if let reading = weather.reading {
                            Text("\(reading.degrees(reading.temperature, fahrenheit: weather.fahrenheit)) · \(reading.condition)").accessibilityIdentifier("weatherLiveReading")
                            Text(L10n.format("Weather time: %@", reading.date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(L10n.locale)))).font(.footnote)
                        }
                        if weather.failed { Text("Couldn't refresh. Any previous reading is marked as cached. Check your connection and try again.".tr) }
                        Button("Refresh weather".tr) { Task { await weather.refresh(force: true) } }.disabled(weather.loading).accessibilityIdentifier("refreshWeather")
                        Button("Clear city".tr) { location.stop(); weather.select(nil); query = ""; results = [] }.accessibilityIdentifier("removeWeatherCity")
                    } else {
                        Text("Choose a city to show live weather.".tr).accessibilityIdentifier("weatherCityUnconfigured")
                    }
                    TextField("Search city".tr, text: $query).textInputAutocapitalization(.words).autocorrectionDisabled().focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }.accessibilityIdentifier("weatherCitySearch")
                    if searching || weather.loading { ProgressView() }
                    ForEach(results) { city in
                        Button { location.stop(); weather.select(city); query = ""; results = [] } label: {
                            VStack(alignment: .leading) { Text(city.displayName); Text(city.detail).font(.caption).foregroundStyle(.secondary) }
                        }.accessibilityIdentifier("weatherCity-\(city.id)")
                    }
                    if let searchMessage { Text(searchMessage.tr).foregroundStyle(.secondary) }
                }
                Section("Locate once".tr) {
                    Button("Locate once".tr) { location.requestCurrentLocation(weather) }
                        .disabled(location.isLocating).accessibilityIdentifier("useWeatherLocation")
                    if location.isLocating {
                        ProgressView().accessibilityIdentifier("weatherLocationProgress")
                        Button("Cancel".tr) { location.stop() }.accessibilityIdentifier("cancelWeatherLocation")
                    }
                    Text(location.message).font(.footnote).accessibilityIdentifier("weatherLocationStatus")
                    Text("Saves this city for future weather updates. HomePad does not locate again when you reopen it or refresh weather.".tr)
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Temperature".tr) {
                Picker("Units".tr, selection: $weather.temperatureUnit) {
                    ForEach(WeatherTemperatureUnit.allCases) { unit in Text(unit.title).tag(unit) }
                }.pickerStyle(.segmented).accessibilityIdentifier("weatherTemperatureUnit")
            }
            Section("Weather data".tr) {
                Link("Weather data by Open-Meteo".tr, destination: URL(string: "https://open-meteo.com/")!)
                Link("City names by GeoNames".tr, destination: URL(string: "https://www.geonames.org/")!)
                Text("Weather refreshes every 15 minutes while visible, using your saved city. City searches and its coordinates are sent to Open-Meteo. Locate once uses Apple Location Services only after you tap it; located coordinates are rounded to about 1 km. No background location tracking.".tr).font(.footnote)
            }
        }.task(id: query) {
            results = []; searchMessage = nil; searching = false
            let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !weather.demo, term.count >= 2 else { return }
            do {
                try await Task.sleep(for: .milliseconds(400)); searching = true
                let found = try await weather.client.search(term)
                guard !Task.isCancelled else { return }
                results = found; searching = false
                if found.isEmpty { searchMessage = "No cities found. Try a nearby city or include the country." }
            } catch {
                guard !Task.isCancelled else { return }
                searching = false; searchMessage = "Search unavailable. Check your connection and try again."
            }
        }.onDisappear { location.stop() }
    }
}
