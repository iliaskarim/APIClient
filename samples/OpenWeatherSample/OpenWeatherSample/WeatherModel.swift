import Foundation

/// Thin SwiftUI shell around the call site from the location post.
@MainActor
final class WeatherModel: ObservableObject {
  enum Phase {
    case idle
    case loading
    case loaded(CurrentWeather)
    case failed(String)
  }

  @Published private(set) var phase: Phase = .idle

  private let client: APIClient
  private let provider = LocationProvider()
  private let weatherEndpoint = Endpoint<CurrentWeatherQuery, Void, CurrentWeather>(
    path: "data/2.5/weather"
  )

  init() {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    client = APIClient(
      baseURL: URL(string: "https://api.openweathermap.org")!,
      decoder: decoder
    )
  }

  func load() async {
    phase = .loading
    do {
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
      phase = .loaded(forecast)
    } catch is LocationError {
      phase = .failed(
        "Location access is off. Enable it in Settings → Privacy & Security → Location Services, then try again."
      )
    } catch {
      phase = .failed(error.localizedDescription)
    }
  }
}
