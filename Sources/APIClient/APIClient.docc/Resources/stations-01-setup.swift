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
