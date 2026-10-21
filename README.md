# APIClient

Bare-bones async JSON client. A path string passed to `response` is a GET, or a POST when the call includes a request body. Pass an `Endpoint` to name another method: it carries the path, the method, and the types of the query, request body, and response body. Pass query items into `response` the same way you pass a request body: a dictionary literal, or any type that exposes `[URLQueryItem]`.

## Installation

```swift
.package(url: "https://github.com/iliaskarim/APIClient.git", branch: "main")
```

## Usage

`response` has an overload for each combination of request body and response body: neither, request only, response only, or both. A path string selects GET or POST. An `Endpoint` selects the method. The sections below walk through each shape against [OpenWeather’s Stations API](https://openweathermap.org/stations).

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
  "data/3.0/stations",
  queryItems: ["appid": apiKey]
)
```

### Encodable request body → Decodable response

`POST /stations` registers a station and returns it.

```swift
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
```

### Encodable request body → no response body

`POST /measurements` uploads readings. A successful response is `204` with an empty body.

```swift
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
```

### No request body → no response body

`DELETE /stations/{id}` removes a station and its measurements. A successful response is `204` with an empty body. A path string with no body sends GET, so this call passes an `Endpoint`.

```swift
try await client.response(
  endpoint: Endpoint(
    path: "data/3.0/stations/\(created.id!)",
    method: "DELETE"
  ),
  queryItems: ["appid": apiKey]
)
```
