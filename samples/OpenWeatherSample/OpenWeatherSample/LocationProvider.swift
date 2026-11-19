import CoreLocation

enum LocationError: Error {
  case denied
  case missingFix
}

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
