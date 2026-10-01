# APIClient

Bare-bones async JSON client. `Endpoint` is a path and an HTTP method. Call `response` to send it.

## Installation

```swift
.package(url: "https://github.com/iliaskarim/APIClient.git", branch: "main")
```

## Usage

`response` has four overloads, one for each combination of request body and response body: neither, request only, response only, or both. The sections below walk through each shape against [OpenWeather’s Stations API](https://openweathermap.org/stations). Replace `YOUR_API_KEY` with your key.

### Models

```swift
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
```

### No request body → Decodable response

`GET /stations` lists the stations on your account.

```swift
let stations: [Station] = try await client.response(
  endpoint: .init(path: "data/3.0/stations?appid=\(apiKey)")
)
```

### Encodable request body → Decodable response

`POST /stations` registers a station and returns it.

```swift
let created: Station = try await client.response(
  endpoint: .init(path: "data/3.0/stations?appid=\(apiKey)", method: "POST"),
  requestBody: Station(
    id: nil,
    externalId: "SF_TEST001",
    name: "San Francisco Test Station",
    latitude: 37.76,
    longitude: -122.43,
    altitude: 150
  )
)
```

### Encodable request body → no response body

`POST /measurements` uploads readings. A successful response is `204` with an empty body.

```swift
try await client.response(
  endpoint: .init(path: "data/3.0/measurements?appid=\(apiKey)", method: "POST"),
  requestBody: [
    Measurement(
      stationId: created.id!,
      dt: Date(timeIntervalSince1970: 1479817340),
      temperature: 18.7
    )
  ]
)
```

### No request body → no response body

`DELETE /stations/{id}` removes a station and its measurements. A successful response is `204` with an empty body.

```swift
try await client.response(
  endpoint: .init(
    path: "data/3.0/stations/\(created.id!)?appid=\(apiKey)",
    method: "DELETE"
  )
)
```
