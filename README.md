# APIClient

Bare-bones async JSON client. `Endpoint` is a path and an HTTP method. Call `response` to send it.

The examples below use [OpenWeather’s Stations API](https://openweathermap.org/stations). Replace `YOUR_API_KEY` with your key.

## Installation

```swift
.package(url: "https://github.com/iliaskarim/APIClient.git", branch: "main")
```

## Usage

```swift
struct Station: Codable {
  var id: String?
  var externalId: String
  var name: String
  var latitude: Double
  var longitude: Double
  var altitude: Double

  enum CodingKeys: String, CodingKey {
    case id
    case externalId = "external_id"
    case name, latitude, longitude, altitude
  }
}

struct Measurement: Encodable {
  var stationId: String
  var dt: Int
  var temperature: Double

  enum CodingKeys: String, CodingKey {
    case stationId = "station_id"
    case dt, temperature
  }
}

let apiKey = "YOUR_API_KEY"
let client = APIClient(
  baseURL: URL(string: "https://api.openweathermap.org")!
)

// No request body → Decodable response (GET /stations)
let stations: [Station] = try await client.response(
  endpoint: .init(path: "data/3.0/stations?appid=\(apiKey)")
)

// Encodable request body → Decodable response (POST /stations)
let created: Station = try await client.response(
  endpoint: .init(path: "data/3.0/stations?appid=\(apiKey)", method: "POST"),
  requestBody: Station(
    externalId: "SF_TEST001",
    name: "San Francisco Test Station",
    latitude: 37.76,
    longitude: -122.43,
    altitude: 150
  )
)

// Encodable request body → no response body (POST /measurements)
try await client.response(
  endpoint: .init(path: "data/3.0/measurements?appid=\(apiKey)", method: "POST"),
  requestBody: [
    Measurement(
      stationId: created.id!,
      dt: 1479817340,
      temperature: 18.7
    )
  ]
)

// No request body → no response body (DELETE /stations/{id})
try await client.response(
  endpoint: .init(
    path: "data/3.0/stations/\(created.id!)?appid=\(apiKey)",
    method: "DELETE"
  )
)
```
