// LiveWeatherService.swift
// wthrr — macOS decorative weather overlay

import Foundation
import CoreLocation
import MapKit

// MARK: - Open-Meteo response models

/// Private model for decoding the top-level response from the Open-Meteo forecast API.
/// Only the `current` block is used; forecast data is ignored.
private struct OpenMeteoResponse: Decodable {
    /// The current-conditions sub-object returned by the API.
    let current: CurrentWeather

    /// Subset of Open-Meteo current-weather fields used by wthrr.
    struct CurrentWeather: Decodable {
        /// Air temperature at 2 m altitude in the units requested (Fahrenheit).
        let temperature2m: Double
        /// WMO weather interpretation code (0 = clear, 95 = thunderstorm, etc.).
        let weathercode: Int
        /// Wind speed at 10 m altitude in the units requested (mph).
        let windspeed10m: Double
        /// Current precipitation intensity in mm/h.
        let precipitation: Double

        /// Maps snake_case JSON keys to camelCase Swift properties.
        enum CodingKeys: String, CodingKey {
            case temperature2m  = "temperature_2m"
            case weathercode
            case windspeed10m   = "windspeed_10m"
            case precipitation
        }
    }
}

// MARK: - Resolved condition

/// The weather effect parameters derived from a single Open-Meteo API response.
/// Passed to `WeatherSettings` to auto-apply real conditions.
struct LiveWeatherCondition {
    /// The weather effect type mapped from the WMO weather code.
    let weatherType: WeatherType
    /// Recommended particle count based on precipitation intensity.
    let flakeCount: Int
    /// Recommended speed multiplier based on precipitation intensity.
    let speedMultiplier: Double
    /// Recommended wind strength (0-1) mapped from wind speed in mph.
    let windStrength: Double
    /// Whether lightning should be active (true for WMO thunderstorm codes).
    let lightningEnabled: Bool
    /// Formatted temperature string shown in the header (e.g. "52°F").
    let temperatureText: String
}

// MARK: - Live weather service

/// Fetches current conditions from Open-Meteo (no API key required) and applies
/// them to WeatherSettings.shared when live mode is enabled.
@Observable
final class LiveWeatherService: NSObject {
    static let shared = LiveWeatherService()

    /// True while a location request or API fetch is in progress.
    var isLoading = false
    /// Reverse-geocoded city name for the most recent location, shown in the popover.
    var locationName: String = ""
    /// Non-nil when location or network access fails; shown in the popover status row.
    var errorMessage: String?
    /// The most recently resolved weather condition, retained so settings can be re-applied
    /// without a fresh network request (e.g. when the user returns from background).
    var lastCondition: LiveWeatherCondition?
    /// Whether the service is currently active. Controls the 20-minute refresh loop.
    private(set) var isRunning = false

    /// Core Location manager providing GPS coordinates.
    private let locationManager = CLLocationManager()
    /// Retained CLLocationManagerDelegate shim (weak-referenced from CLLocationManager).
    private var locationDelegate: _LocationDelegate?
    /// Cancellable task for the active Open-Meteo fetch.
    private var fetchTask: Task<Void, Never>?
    /// Cancellable background task that triggers a new location request every 20 minutes.
    private var refreshLoop: Task<Void, Never>?

    private override init() {
        super.init()
        let d = _LocationDelegate(service: self)
        locationDelegate = d
        locationManager.delegate = d
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    // MARK: - Public interface

    /// Starts the live weather service: requests location authorization, fires the first
    /// location lookup, and schedules an automatic refresh every 20 minutes.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()

        // Re-fetch every 20 minutes while running.
        refreshLoop = Task {
            while !Task.isCancelled && self.isRunning {
                try? await Task.sleep(for: .seconds(20 * 60))
                guard self.isRunning && !Task.isCancelled else { break }
                self.locationManager.requestLocation()
            }
        }
    }

    /// Stops the service, cancels all background tasks, and halts the refresh loop.
    func stop() {
        isRunning = false
        refreshLoop?.cancel()
        refreshLoop = nil
        fetchTask?.cancel()
    }

    /// Triggers an immediate location and weather refresh outside the normal 20-min cycle.
    func refresh() {
        guard isRunning else { return }
        locationManager.requestLocation()
    }

    // MARK: - Location delegate callbacks

    fileprivate func didUpdateLocation(_ location: CLLocation) {
        Task {
            if let request = MKReverseGeocodingRequest(location: location),
               let mapItems = try? await request.mapItems,
               let cityWithContext = mapItems.first?.addressRepresentations?.cityWithContext {
                self.locationName = cityWithContext
            }
        }
        fetch(for: location)
    }

    fileprivate func didFailWithError(_ error: Error) {
        errorMessage = "Location unavailable"
        isLoading = false
    }

    // MARK: - Fetch

    private func fetch(for location: CLLocation) {
        fetchTask?.cancel()
        isLoading = true
        errorMessage = nil

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let urlStr = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(lat)&longitude=\(lon)"
            + "&current=temperature_2m,weathercode,windspeed_10m,precipitation"
            + "&temperature_unit=fahrenheit&wind_speed_unit=mph"

        fetchTask = Task {
            defer { self.isLoading = false }
            guard let url = URL(string: urlStr) else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response  = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                self.lastCondition = LiveWeatherCondition(from: response.current)
                self.applyToSettings()
            } catch {
                self.errorMessage = "Weather fetch failed"
            }
        }
    }

    // MARK: - Apply to settings

    func applyToSettings() {
        guard let c = lastCondition else { return }
        let s = WeatherSettings.shared
        s.weatherType       = c.weatherType
        s.flakeCount        = c.flakeCount
        s.speedMultiplier   = c.speedMultiplier
        s.windStrength      = c.windStrength
        s.lightningEnabled  = c.lightningEnabled
        s.liveTemperatureText = c.temperatureText
    }
}

// MARK: - CLLocationManagerDelegate helper

/// Thin NSObject shim so CLLocationManagerDelegate can be satisfied without
/// making LiveWeatherService itself a full NSObject subclass observable tangle.
private final class _LocationDelegate: NSObject, CLLocationManagerDelegate {
    weak var service: LiveWeatherService?
    init(service: LiveWeatherService) { self.service = service }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        service?.didUpdateLocation(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        service?.didFailWithError(error)
    }
}

// MARK: - WMO code → condition mapping

private extension LiveWeatherCondition {
    init(from w: OpenMeteoResponse.CurrentWeather) {
        let temp   = w.temperature2m
        let code   = w.weathercode
        let precip = w.precipitation
        let wind   = w.windspeed10m

        // WMO weather code → weather type + lightning
        let type: WeatherType
        let lightning: Bool
        switch code {
        case 0...3:
            // Clear / partly cloudy / overcast — decorative pick by temperature
            type = temp <= 35 ? .snow : .rain
            lightning = false
        case 45, 48:
            type = .rain; lightning = false          // Fog
        case 51...57:
            type = .rain; lightning = false          // Drizzle
        case 61...67:
            type = .rain; lightning = false          // Rain
        case 71...77:
            type = .snow; lightning = false          // Snow
        case 80...82:
            type = .rain; lightning = false          // Rain showers
        case 85, 86:
            type = .snow; lightning = false          // Snow showers
        case 95:
            type = .rain; lightning = true           // Thunderstorm
        case 96, 99:
            type = .rain; lightning = true           // Thunderstorm + hail
        default:
            type = .snow; lightning = false
        }

        // Precipitation intensity → particle count + speed
        let flakeCount: Int
        let speed: Double
        switch precip {
        case ..<0.1:  flakeCount = 80;  speed = 0.60
        case ..<1.0:  flakeCount = 120; speed = 0.85
        case ..<5.0:  flakeCount = 180; speed = 1.20
        case ..<15.0: flakeCount = 250; speed = 1.80
        default:      flakeCount = 320; speed = 2.50
        }

        // Wind speed (mph) → 0-1 wind strength
        let windStrength: Double
        switch wind {
        case ..<5:  windStrength = 0.1
        case ..<15: windStrength = 0.3
        case ..<25: windStrength = 0.5
        case ..<40: windStrength = 0.7
        default:    windStrength = 0.9
        }

        self.weatherType      = type
        self.flakeCount       = flakeCount
        self.speedMultiplier  = speed
        self.windStrength     = windStrength
        self.lightningEnabled = lightning
        self.temperatureText  = "\(Int(temp.rounded()))°F"
    }
}
