import CoreLocation
import SwiftUI

/// Constructing WeatherLocation does not construct a location manager or request access.
@MainActor protocol WeatherLocationManaging: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func requestLocation()
    func stopUpdatingLocation()
}
extension CLLocationManager: WeatherLocationManaging {}

/// The seam covers both Apple's network result and cancellation, without fabricating a device fix.
@MainActor protocol WeatherCityGeocoding: AnyObject {
    func city(for location: CLLocation, locale: Locale) async throws -> WeatherCity
    func cancel()
}

@MainActor private final class AppleWeatherCityGeocoder: WeatherCityGeocoding {
    private let coder = CLGeocoder()
    func city(for location: CLLocation, locale: Locale) async throws -> WeatherCity {
        let places = try await coder.reverseGeocodeLocation(location, preferredLocale: locale)
        guard let place = places.first, let name = place.locality ?? place.subAdministrativeArea else {
            throw WeatherError.invalidData
        }
        let city = WeatherCity(id: -1, name: name,
                               latitude: (location.coordinate.latitude * 100).rounded() / 100,
                               longitude: (location.coordinate.longitude * 100).rounded() / 100,
                               admin1: place.administrativeArea, country: place.country)
        guard city.valid else { throw WeatherError.invalidData }
        return city
    }
    func cancel() { coder.cancelGeocode() }
}

/// Only an explicit tap can begin a one-shot request. Saved follow flags are not authorization.
@MainActor final class WeatherLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private var messageKey = "Choose a city. Location is only used when you tap Locate once."
    @Published private(set) var isLocating = false
    private var locatedCityName: String?
    var message: String {
        if let locatedCityName, messageKey == "City saved · %@" {
            return L10n.format(messageKey, locatedCityName)
        }
        return messageKey.tr
    }
    private let makeManager: () -> any WeatherLocationManaging
    private let makeGeocoder: () -> any WeatherCityGeocoding
    private let requestTimeout: Duration
    private let sleep: (Duration) async throws -> Void
    private var manager: (any WeatherLocationManaging)?
    private var geocoder: (any WeatherCityGeocoding)?
    private weak var weather: WeatherStore?
    private var requestID: UUID?
    private var requestedFix = false
    private var geocodeTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    init(makeManager: @escaping () -> any WeatherLocationManaging = { CLLocationManager() },
         makeGeocoder: (() -> any WeatherCityGeocoding)? = nil,
         requestTimeout: Duration = .seconds(20),
         sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.makeManager = makeManager; self.makeGeocoder = makeGeocoder ?? { AppleWeatherCityGeocoder() }
        self.requestTimeout = requestTimeout; self.sleep = sleep
        super.init()
    }

    /// Kept safe for older call sites: passive refresh never starts or retries location.
    func update(_ weather: WeatherStore, force: Bool = false) {
        if weather.demo { stop() }
    }

    func requestCurrentLocation(_ weather: WeatherStore) {
        stop()
        guard let id = weather.beginLocationRequest() else { return }
        self.weather = weather; requestID = id; isLocating = true
        locatedCityName = nil; messageKey = "Finding your city once…"
        let created = makeManager()
        created.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager = created; created.delegate = self
        let sleep = self.sleep, duration = requestTimeout
        // Bounds the entire operation, including a slow permission dialog or reverse-geocoder.
        timeoutTask = Task { [weak self] in
            do { try await sleep(duration) } catch { return }
            guard let self, !Task.isCancelled, self.currentWeather(for: id) != nil else { return }
            self.fail(timedOut: true)
        }
        authorizeOrLocate(allowsPermissionPrompt: true)
    }

    private func currentWeather(for id: UUID) -> WeatherStore? {
        guard requestID == id else { return nil }
        guard let weather, weather.isLocationRequestCurrent(id) else { stop(); return nil }
        return weather
    }
    private func authorizeOrLocate(allowsPermissionPrompt: Bool = false) {
        guard let id = requestID, let weather = currentWeather(for: id), let manager else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            if allowsPermissionPrompt { manager.requestWhenInUseAuthorization() }
        case .authorizedAlways, .authorizedWhenInUse:
            guard !requestedFix else { return }
            requestedFix = true
            manager.requestLocation()
        case .denied, .restricted:
            let message = weather.city == nil ? "Location is off. Choose a city manually." : "Location is off. Keeping your previous city."
            releaseResources(); locatedCityName = nil; messageKey = message
        @unknown default:
            fail()
        }
    }

    /// Permission alerts temporarily inactivate the app. Preserve that explicit request,
    /// but cancel on actual background; becoming active never begins/retries a request.
    func setScenePhase(_ phase: ScenePhase) {
        if phase == .background { stop() }
    }

    /// Cancels permission/fix/geocoding intent; existing manual city and units never change.
    func stop() {
        releaseResources(); locatedCityName = nil
        messageKey = "Choose a city. Location is only used when you tap Locate once."
    }
    private func releaseResources() {
        if let requestID { weather?.cancelLocationRequest(requestID) }
        requestID = nil
        timeoutTask?.cancel(); timeoutTask = nil
        geocodeTask?.cancel(); geocodeTask = nil
        geocoder?.cancel(); geocoder = nil
        manager?.delegate = nil; manager?.stopUpdatingLocation(); manager = nil
        requestedFix = false; isLocating = false; weather = nil
    }
    private func isCurrent(_ source: any WeatherLocationManaging) -> Bool {
        manager.map { ObjectIdentifier($0) == ObjectIdentifier(source) } ?? false
    }
    private func fail(timedOut: Bool = false) {
        let hasCity = weather?.city != nil
        releaseResources(); locatedCityName = nil
        if timedOut {
            messageKey = hasCity
                ? "Location took too long. Keeping your previous city. Choose a city or try Locate once again."
                : "Location took too long. Choose a city manually or try Locate once again."
        } else {
            messageKey = hasCity
                ? "Location unavailable. Keeping your previous city. Choose a city or try Locate once again."
                : "Location unavailable. Choose a city manually or try Locate once again."
        }
    }

    // Internal event entry points also allow controlled manager/geocoder unit tests.
    func authorizationChanged(from source: any WeatherLocationManaging) {
        guard isCurrent(source) else { return }
        authorizeOrLocate()
    }
    func receivedLocations(_ locations: [CLLocation], from source: any WeatherLocationManaging) {
        guard isCurrent(source), requestedFix, let id = requestID, currentWeather(for: id) != nil else { return }
        guard let location = locations.last, location.horizontalAccuracy.isFinite, location.horizontalAccuracy >= 0,
              abs(location.timestamp.timeIntervalSinceNow) < 600 else { fail(); return }
        // requestLocation is one-shot. Stop and release the manager before Apple's network lookup.
        manager?.delegate = nil; manager?.stopUpdatingLocation(); manager = nil
        let coder = makeGeocoder(); geocoder = coder
        geocodeTask = Task { [weak self] in
            do {
                let city = try await coder.city(for: location, locale: L10n.locale)
                guard let self, !Task.isCancelled, let weather = self.currentWeather(for: id) else { return }
                guard weather.applyLocatedCity(city, requestID: id) else { self.stop(); return }
                self.releaseResources(); self.locatedCityName = city.displayName; self.messageKey = "City saved · %@"
            } catch {
                guard let self, !Task.isCancelled, self.currentWeather(for: id) != nil else { return }
                self.fail()
            }
        }
    }
    func receivedFailure(from source: any WeatherLocationManaging) {
        guard isCurrent(source), let id = requestID, currentWeather(for: id) != nil else { return }
        fail()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in self?.authorizationChanged(from: manager) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in self?.receivedLocations(locations, from: manager) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.receivedFailure(from: manager) }
    }
}
