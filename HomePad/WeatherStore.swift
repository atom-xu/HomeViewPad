import Foundation
import SwiftUI

struct WeatherCity: Codable, Identifiable, Equatable {
    static let philadelphia = WeatherCity(id: 4560349, name: "Philadelphia", latitude: 39.9526, longitude: -75.1652, admin1: "Pennsylvania", country: "United States")
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    var admin1: String? = nil
    var country: String? = nil
    var detail: String { [admin1, country].compactMap { $0 }.joined(separator: ", ") }
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
        case 0: return "Clear"
        case 1: return "Mostly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57, 66, 67: return "Freezing Rain"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75, 77: return "Snow"
        case 80, 81, 82: return "Rain Showers"
        case 85, 86: return "Snow Showers"
        case 95, 96, 99: return "Thunderstorms"
        default: return "Conditions Unknown"
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
        url.queryItems = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "count", value: "8"), URLQueryItem(name: "language", value: Locale.current.language.languageCode?.identifier ?? "en"), URLQueryItem(name: "format", value: "json")]
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

@MainActor final class WeatherStore: ObservableObject {
    @Published private(set) var city: WeatherCity?
    @Published private(set) var reading: WeatherReading?
    @Published private(set) var loading = false
    @Published private(set) var failed = false
    @Published private(set) var demo: Bool
    @Published private(set) var followsLocation: Bool
    @Published var fahrenheit: Bool { didSet { defaults.set(fahrenheit, forKey: "weatherFahrenheit") } }
    let client: any WeatherProviding
    private let defaults: UserDefaults
    private var requestID = UUID()
    private var lastAttempt: Date?
    init(defaults: UserDefaults = .standard, client: any WeatherProviding = OpenMeteoClient(), demo: Bool = false) {
        self.defaults = defaults; self.client = client; self.demo = demo
        followsLocation = defaults.object(forKey: "weatherFollowsLocation") as? Bool ?? true
        city = .philadelphia
        fahrenheit = defaults.object(forKey: "weatherFahrenheit") as? Bool ?? true
        if !followsLocation, let data = defaults.data(forKey: "weatherCity"), let stored = try? JSONDecoder().decode(WeatherCity.self, from: data), stored.valid { city = stored }
    }
    func setDemo(_ value: Bool) {
        guard value != demo else { return }
        demo = value; invalidate()
    }
    private func invalidate() { requestID = UUID(); reading = nil; loading = false; failed = false; lastAttempt = nil }
    func select(_ value: WeatherCity?) {
        guard value == nil || value!.valid else { return }
        followsLocation = false; defaults.set(false, forKey: "weatherFollowsLocation")
        invalidate(); city = value
        if let value, let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: "weatherCity") }
        else { defaults.removeObject(forKey: "weatherCity") }
    }
    func enableLocation() {
        followsLocation = true; defaults.set(true, forKey: "weatherFollowsLocation")
    }
    func applyLocatedCity(_ city: WeatherCity) {
        guard followsLocation, !demo, city.valid, self.city != city else { return }
        invalidate(); self.city = city
        // Keep automatically located coordinates in memory only. Relaunch falls back to Philadelphia.
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
            failed = true // Keep a previous reading, explicitly marked as cached/offline.
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
                Section { Text("DEMO · Fixed sample weather. Leave demo mode in Settings to use live weather.").accessibilityIdentifier("weatherDemoNotice") }
            } else {
                Section("Location") {
                    Button("Use current location") { weather.enableLocation(); location.update(weather, force: true) }.accessibilityIdentifier("useWeatherLocation")
                    Text(weather.followsLocation ? location.message : "Using your chosen city.").font(.footnote).accessibilityIdentifier("weatherLocationStatus")
                }
                Section("City") {
                    if let city = weather.city {
                        Text(city.name).font(.headline).accessibilityIdentifier("weatherSelectedCity")
                        Text(city.detail).foregroundStyle(.secondary)
                        if let reading = weather.reading {
                            Text("\(reading.degrees(reading.temperature, fahrenheit: weather.fahrenheit)) · \(reading.condition)").accessibilityIdentifier("weatherLiveReading")
                            Text("Weather time: \(reading.date.formatted(date: .abbreviated, time: .shortened))").font(.footnote)
                        }
                        if weather.failed { Text("Couldn't refresh. Any previous reading is marked as cached. Check your connection and try again.") }
                        Button("Refresh weather") { Task { await weather.refresh(force: true) } }.disabled(weather.loading).accessibilityIdentifier("refreshWeather")
                        Button("Use Philadelphia") { weather.select(.philadelphia) }.accessibilityIdentifier("removeWeatherCity")
                    }
                    TextField("Search city", text: $query).textInputAutocapitalization(.words).autocorrectionDisabled().focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }.accessibilityIdentifier("weatherCitySearch")
                    if searching || weather.loading { ProgressView() }
                    ForEach(results) { city in
                        Button { weather.select(city); query = "" } label: {
                            VStack(alignment: .leading) { Text(city.name); Text(city.detail).font(.caption).foregroundStyle(.secondary) }
                        }.accessibilityIdentifier("weatherCity-\(city.id)")
                    }
                    if let searchMessage { Text(searchMessage).foregroundStyle(.secondary) }
                }
            }
            Section("Temperature") {
                Picker("Units", selection: $weather.fahrenheit) { Text("°C").tag(false); Text("°F").tag(true) }.pickerStyle(.segmented)
            }
            Section("Weather data") {
                Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                Link("City names by GeoNames", destination: URL(string: "https://www.geonames.org/")!)
                Text("Current conditions are weather-model estimates. Refreshes every 15 minutes while visible. City searches and the selected city's coordinates are sent to Open-Meteo. With your permission, Apple Location Services finds your city. Coordinates sent for weather are rounded to about 1 km. No background location tracking.").font(.footnote)
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
        }
    }
}
