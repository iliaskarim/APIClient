import FixtureURLProtocol
import Foundation
import Testing
@testable import APIClient

private struct CurrentWeather: Decodable {
  struct Main: Decodable {
    let temp: Double
    let humidity: Int
  }

  struct Condition: Decodable {
    let description: String
    let icon: String
  }

  let name: String
  let main: Main
  let weather: [Condition]
}

@Test
func responseSendsTheRequestAndDecodesTheBody() async throws {
  let body = Data(
    """
    {
      "name": "Brooklyn",
      "main": { "temp": 72.5, "humidity": 61 },
      "weather": [{ "description": "clear sky", "icon": "01d" }]
    }
    """.utf8
  )
  let fixture = Fixture(body: body)
  let session = fixture.makeSession()

  let decoder = JSONDecoder()
  decoder.keyDecodingStrategy = .convertFromSnakeCase
  let client = try APIClient(
    baseURL: #require(URL(string: "https://api.openweathermap.org")),
    session: session,
    decoder: decoder
  )

  let apiKey = "YOUR_API_KEY"
  let path = "data/2.5/weather"
  let queryItems = [
    "appid": apiKey,
    "lat": "40.6501",
    "lon": "-73.9496",
    "units": "imperial"
  ]

  let decoded: CurrentWeather = try await client.response(
    endpoint: .init(path: path),
    queryItems: queryItems
  )

  let request = try #require(fixture.requests.first)
  let url = try #require(request.url)
  let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
  let items = Dictionary(
    uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
  )

  #expect(request.httpMethod == "GET")
  #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
  #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
  #expect(components.scheme == "https")
  #expect(components.host == "api.openweathermap.org")
  #expect(components.path == "/data/2.5/weather")
  #expect(items == [
    "appid": "YOUR_API_KEY",
    "lat": "40.6501",
    "lon": "-73.9496",
    "units": "imperial"
  ])
  #expect(decoded.name == "Brooklyn")
  #expect(decoded.main.temp == 72.5)
  #expect(decoded.main.humidity == 61)
  #expect(decoded.weather.first?.description == "clear sky")
  #expect(decoded.weather.first?.icon == "01d")
}
