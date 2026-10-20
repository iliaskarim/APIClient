# How to Request Location Permission and Read GPS Coordinates on iOS

In this tutorial we will learn how to ask for When In Use location access on iOS and read a single GPS fix for a weather call. In [How to Type OpenWeather Query Items in a Swift API Client](/how-to-type-openweather-query-items-in-swift) we modeled Current Weather’s query as a struct with `lat` and `lon` as `Double`—but the call site still used hard-coded Brooklyn numbers. Those fields were waiting for a real device (or simulator) location. We will declare the privacy string, request authorization with `CLLocationManager`, take one coordinate, and pass it into `CurrentWeatherQuery`.

## Getting Started

The typed-query call site still looks like this:

```swift
let query = CurrentWeatherQuery(
  appid: WeatherConfig.apiKey,
  lat: 40.6501,
  lon: -73.9496,
  units: "imperial"
)
```

That is fine for a walkthrough. It is wrong the moment the user is not standing in Crown Heights. OpenWeather’s Current Weather endpoint wants the coordinates of *where the forecast should apply*; Core Location is how iOS hands those numbers to your app. Nothing about `APIClient`, `Endpoint`, or `CurrentWeatherQuery` changes—only the source of `lat` and `lon`.

Add the Core Location framework to the app target if Xcode has not already linked it, and import it where you will talk to the manager:

```swift
import CoreLocation
```

You do not need MapKit for this post. A weather screen that only needs a coordinate can stay on Core Location alone.

## Declaring the Privacy Reason

iOS will not show a permission prompt—and will terminate the app if you call the request API—until you declare why you need location. Open the app target’s **Info** tab (or the target’s Info.plist) and add **Privacy - Location When In Use Usage Description** (`NSLocationWhenInUseUsageDescription`) with a sentence the user will actually read:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We use your location to load the weather forecast for where you are.</string>
```

When In Use is the right default for a forecast pull: you need a fix while the app is open, not a continuous background trail. Always, Background Modes, and significant-change monitoring are separate products; leave them out until a feature truly needs them. The string you write is not marketing copy for the App Store listing—it is the body of the system alert—so keep it specific and honest.

## Asking for When-In-Use Access

Create a small type that owns a `CLLocationManager`. Keep the manager alive for the duration of the request; a local variable that falls out of scope cancels the prompt and the fix:

```swift
final class LocationProvider: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  func coordinate() async throws -> CLLocationCoordinate2D {
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation

      switch manager.authorizationStatus {
      case .notDetermined:
        manager.requestWhenInUseAuthorization()
      case .restricted, .denied:
        finish(.failure(LocationError.denied))
      case .authorizedAlways, .authorizedWhenInUse:
        manager.requestLocation()
      @unknown default:
        finish(.failure(LocationError.denied))
      }
    }
  }
}
```

`kCLLocationAccuracyHundredMeters` is enough for city-scale weather and drains less than navigation-grade accuracy. `requestWhenInUseAuthorization()` only matters while status is `.notDetermined`; if the user already chose Allow or Don’t Allow, calling it again does nothing useful—you read `authorizationStatus` and branch. Do not call `requestLocation()` until authorization is granted, or the manager can fail the request before the system sheet even appears. Store a single `CheckedContinuation` so the delegate can finish the `async` call exactly once.

Define a tiny error type for the paths that are not “here is a coordinate”:

```swift
enum LocationError: Error {
  case denied
  case missingFix
}
```

## Reading a Single Fix

`requestLocation()` asks Core Location for one location update and then stops. That matches a weather refresh better than `startUpdatingLocation()`, which keeps the GPS warm until you call `stopUpdatingLocation()`. Implement the delegate methods that complete—or fail—the continuation:

```swift
extension LocationProvider {
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      manager.requestLocation()
    case .restricted, .denied:
      finish(.failure(LocationError.denied))
    case .notDetermined:
      break
    @unknown default:
      finish(.failure(LocationError.denied))
    }
  }

  func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    guard let coordinate = locations.last?.coordinate else {
      finish(.failure(LocationError.missingFix))
      return
    }
    finish(.success(coordinate))
  }

  func locationManager(
    _ manager: CLLocationManager,
    didFailWithError error: Error
  ) {
    finish(.failure(error))
  }

  private func finish(_ result: Result<CLLocationCoordinate2D, Error>) {
    guard let continuation else { return }
    self.continuation = nil
    continuation.resume(with: result)
  }
}
```

Authorization and the first fix often arrive on separate callbacks. When the user taps Allow, `locationManagerDidChangeAuthorization` fires and you call `requestLocation()` again; when the fix lands, `didUpdateLocations` resumes the continuation with `coordinate.latitude` and `coordinate.longitude` as `Double`s—the same types `CurrentWeatherQuery` already stores. Clear the continuation in `finish` so a second delegate call cannot resume it twice.

## Wiring the Call Site

Hold the provider somewhere long-lived enough to survive the permission alert—your weather screen’s model, or a dependency you inject—then replace the hard-coded numbers:

```swift
let provider = LocationProvider()
let coordinate = try await provider.coordinate()

let query = CurrentWeatherQuery(
  appid: WeatherConfig.apiKey,
  lat: coordinate.latitude,
  lon: coordinate.longitude,
  units: "imperial"
)

let forecast: CurrentWeather = try await client.response(
  endpoint: weatherEndpoint,
  queryItems: query
)
```

The client post’s `response` path is unchanged. The typed-query post’s struct still stringifies `lat` and `lon` inside `queryItems`. All you did was stop lying about Brooklyn. If authorization fails, catch `LocationError.denied` and either fall back to a saved city, show a short explanation, or deep-link to Settings with `UIApplication.openSettingsURLString`—pick one product behavior and keep the networking layer out of that decision.

## Simulator, Denial, and Accuracy

On a physical device you will see the system sheet once per install (until the user resets Location Privacy in Settings). In the Simulator, use **Features → Location** to pick Apple’s presets or **Custom Location…** and paste a latitude and longitude; without a simulated location, `requestLocation()` fails even when authorization is granted.

If the user denied access, `authorizationStatus` stays `.denied` until they change it in **Settings → Privacy & Security → Location Services**. Calling `requestWhenInUseAuthorization()` again will not re-prompt. On iOS 14 and later, When In Use can also arrive as reduced accuracy; for OpenWeather’s city-level forecast, reduced accuracy is usually still enough, so you can ignore precise-location upgrades until a feature needs a tighter fix.

## Conclusion

We’ve replaced hard-coded Brooklyn coordinates with a When In Use Core Location flow: a privacy usage string, a `CLLocationManager` that requests authorization, a one-shot `requestLocation()` wrapped in `async`, and the resulting `Double` latitude and longitude passed into `CurrentWeatherQuery`. The bare-bones client from [How to Build a Bare-Bones Async JSON Client in Swift](/how-to-build-a-bare-bones-async-json-client-in-swift) and the typed query from [How to Type OpenWeather Query Items in a Swift API Client](/how-to-type-openweather-query-items-in-swift) stay as they are—only the source of `lat` and `lon` moved from a literal to the device. From here you can cache the last good coordinate for offline launches, or let the user pin a city when they decline the prompt, without teaching the API client anything about GPS.

*Cover image generated for this post.*
