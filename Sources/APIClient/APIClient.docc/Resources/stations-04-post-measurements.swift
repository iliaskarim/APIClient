import APIClient
import Foundation

struct Station: Codable {
  let id: String?
  let externalId: String
  let name: String
  let latitude: Double
  let longitude: Double
  let altitude: Double
}

struct Measurement: Encodable {
  let stationId: String
  let dt: Date
  let temperature: Double
}

struct AggregatedMeasurement: Decodable {
  struct Aggregate: Decodable {
    let average: Double?
  }

  let type: String
  let date: Date
  let stationId: String
  let temp: Aggregate?
}

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .secondsSince1970
encoder.keyEncodingStrategy = .convertToSnakeCase

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .secondsSince1970
decoder.keyDecodingStrategy = .convertFromSnakeCase

let apiKey = "YOUR_API_KEY"
let client = APIClient(
  baseURL: URL(string: "https://api.openweathermap.org")!,
  encoder: encoder,
  decoder: decoder
)

// POST /stations — encodable body, decoded response
let created: Station = try await client.response(
  "data/3.0/stations",
  requestBody: Station(
    id: nil,
    externalId: "SF_TEST001",
    name: "San Francisco Test Station",
    latitude: 37.76,
    longitude: -122.43,
    altitude: 150
  ),
  queryItems: ["appid": apiKey]
)

// GET /stations — no body, decoded response
let stations: [Station] = try await client.response(
  "data/3.0/stations",
  queryItems: ["appid": apiKey]
)

// POST /measurements — encodable body, empty response (204)
try await client.response(
  "data/3.0/measurements",
  requestBody: [
    Measurement(
      stationId: created.id!,
      dt: Date(timeIntervalSince1970: 1479817340),
      temperature: 18.7
    )
  ],
  queryItems: ["appid": apiKey]
)
