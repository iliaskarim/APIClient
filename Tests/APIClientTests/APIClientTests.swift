import FixtureURLProtocol
import Foundation
import Testing
@testable import APIClient

private struct Measurement: Codable {
  let stationId: String
  let dt: Date
  let temperature: Double
}

private struct Station: Codable {
  let id: String?
  let externalId: String
  let name: String
  let latitude: Double
  let longitude: Double
  let altitude: Double
}

private extension URLRequest {
  func componentsAndQueryItems() throws -> (URLComponents, [String: String?]) {
    let url = try #require(self.url)
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let items = Dictionary(
      uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
    )
    return (components, items)
  }
}

/// DELETE /stations/{id}. No request body, empty response.
@Test
func responseSendsNoBodyAndAcceptsAnEmptyResponse() async throws {
  let fixture = Fixture(statusCode: 204)
  let session = fixture.makeSession()

  let client = try APIClient(
    baseURL: #require(URL(string: "https://api.openweathermap.org")),
    session: session
  )

  let apiKey = "YOUR_API_KEY"
  let path = "data/3.0/stations/station-1"
  let queryItems = ["appid": apiKey]

  try await client.response(
    endpoint: .init(path: path, method: "DELETE"),
    queryItems: queryItems
  )

  let request = try #require(fixture.requests.first)
  let (components, items) = try request.componentsAndQueryItems()

  #expect(request.httpMethod == "DELETE")
  #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
  #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
  #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
  #expect(request.httpBody == nil)
  #expect(components.scheme == "https")
  #expect(components.host == "api.openweathermap.org")
  #expect(components.path == "/data/3.0/stations/station-1")
  #expect(items == ["appid": "YOUR_API_KEY"])
}

/// GET /stations. No request body, decoded response.
@Test
func responseSendsNoBodyAndDecodesTheResponse() async throws {
  let body = Data(
    """
    [
      {
        "id": "station-1",
        "external_id": "SF_TEST001",
        "name": "San Francisco Test Station",
        "latitude": 37.76,
        "longitude": -122.43,
        "altitude": 150
      }
    ]
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
  let path = "data/3.0/stations"
  let queryItems = ["appid": apiKey]

  let decoded: [Station] = try await client.response(
    endpoint: .init(path: path),
    queryItems: queryItems
  )

  let request = try #require(fixture.requests.first)
  let (components, items) = try request.componentsAndQueryItems()

  #expect(request.httpMethod == "GET")
  #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
  #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
  #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
  #expect(request.httpBody == nil)
  #expect(components.scheme == "https")
  #expect(components.host == "api.openweathermap.org")
  #expect(components.path == "/data/3.0/stations")
  #expect(items == ["appid": "YOUR_API_KEY"])
  #expect(decoded.count == 1)
  #expect(decoded.first?.id == "station-1")
  #expect(decoded.first?.externalId == "SF_TEST001")
  #expect(decoded.first?.name == "San Francisco Test Station")
  #expect(decoded.first?.latitude == 37.76)
  #expect(decoded.first?.longitude == -122.43)
  #expect(decoded.first?.altitude == 150)
}

/// POST /measurements. Encoded request body, empty response.
@Test
func responseSendsTheEncodedBodyAndAcceptsAnEmptyResponse() async throws {
  let fixture = Fixture(statusCode: 204)
  let session = fixture.makeSession()

  let encoder = JSONEncoder()
  encoder.dateEncodingStrategy = .secondsSince1970
  encoder.keyEncodingStrategy = .convertToSnakeCase
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .secondsSince1970
  decoder.keyDecodingStrategy = .convertFromSnakeCase
  let client = try APIClient(
    baseURL: #require(URL(string: "https://api.openweathermap.org")),
    session: session,
    encoder: encoder,
    decoder: decoder
  )

  let apiKey = "YOUR_API_KEY"
  let path = "data/3.0/measurements"
  let queryItems = ["appid": apiKey]
  let measurement = Measurement(
    stationId: "station-1",
    dt: Date(timeIntervalSince1970: 1479817340),
    temperature: 18.7
  )

  try await client.response(
    endpoint: .init(path: path, method: "POST"),
    requestBody: [measurement],
    queryItems: queryItems
  )

  let request = try #require(fixture.requests.first)
  let (components, items) = try request.componentsAndQueryItems()
  let decoded = try decoder.decode([Measurement].self, from: #require(request.httpBody))

  #expect(request.httpMethod == "POST")
  #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
  #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
  #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
  #expect(components.scheme == "https")
  #expect(components.host == "api.openweathermap.org")
  #expect(components.path == "/data/3.0/measurements")
  #expect(items == ["appid": "YOUR_API_KEY"])
  #expect(decoded.count == 1)
  #expect(decoded.first?.stationId == measurement.stationId)
  #expect(decoded.first?.dt == measurement.dt)
  #expect(decoded.first?.temperature == measurement.temperature)
}

/// POST /stations. Encoded request body, decoded response.
@Test
func responseSendsTheEncodedBodyAndDecodesTheResponse() async throws {
  let body = Data(
    """
    {
      "id": "station-1",
      "external_id": "SF_TEST001",
      "name": "San Francisco Test Station",
      "latitude": 37.76,
      "longitude": -122.43,
      "altitude": 150
    }
    """.utf8
  )
  let fixture = Fixture(body: body)
  let session = fixture.makeSession()

  let encoder = JSONEncoder()
  encoder.keyEncodingStrategy = .convertToSnakeCase
  let decoder = JSONDecoder()
  decoder.keyDecodingStrategy = .convertFromSnakeCase
  let client = try APIClient(
    baseURL: #require(URL(string: "https://api.openweathermap.org")),
    session: session,
    encoder: encoder,
    decoder: decoder
  )

  let apiKey = "YOUR_API_KEY"
  let path = "data/3.0/stations"
  let queryItems = ["appid": apiKey]
  let station = Station(
    id: nil,
    externalId: "SF_TEST001",
    name: "San Francisco Test Station",
    latitude: 37.76,
    longitude: -122.43,
    altitude: 150
  )

  let decoded: Station = try await client.response(
    endpoint: .init(path: path, method: "POST"),
    requestBody: station,
    queryItems: queryItems
  )

  let request = try #require(fixture.requests.first)
  let (components, items) = try request.componentsAndQueryItems()
  let encoded = try decoder.decode(Station.self, from: #require(request.httpBody))

  #expect(request.httpMethod == "POST")
  #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
  #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
  #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
  #expect(components.scheme == "https")
  #expect(components.host == "api.openweathermap.org")
  #expect(components.path == "/data/3.0/stations")
  #expect(items == ["appid": "YOUR_API_KEY"])
  #expect(encoded.id == station.id)
  #expect(encoded.externalId == station.externalId)
  #expect(encoded.name == station.name)
  #expect(encoded.latitude == station.latitude)
  #expect(encoded.longitude == station.longitude)
  #expect(encoded.altitude == station.altitude)
  #expect(decoded.id == "station-1")
  #expect(decoded.externalId == station.externalId)
  #expect(decoded.name == station.name)
  #expect(decoded.latitude == station.latitude)
  #expect(decoded.longitude == station.longitude)
  #expect(decoded.altitude == station.altitude)
}
