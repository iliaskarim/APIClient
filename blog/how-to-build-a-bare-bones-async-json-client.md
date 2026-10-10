# How to Build a Bare-Bones Async JSON Client in Swift

In this tutorial we will learn how to build a small async JSON API client in Swift and use it to fetch the current weather from OpenWeather. The client stays intentionally thin: an endpoint is a path, an HTTP method, and optional query items, and a single `response` call sends the request and decodes JSON. If you already followed [How to Retrieve the Current Weather Forecast from OpenWeather](/how-to-retrieve-the-current-weather-forecast-from-openweather), this post is the next step—wrapping that same endpoint in a reusable client instead of hand-rolling `URLSession` at every call site.

## Getting Started

Start with the value that describes *what* to call. An `Endpoint` carries an HTTP method, a path, and any query parameters. The two generic parameters record whether the call has a JSON request body and whether it expects a JSON response body. For a weather GET we only need the response side, so the request body type is `Void`:

```swift
struct Endpoint<RequestBody, ResponseBody> {
  let method: String
  let path: String
  let queryItems: [URLQueryItem]

  init(
    path: String,
    method: String = "GET",
    queryItems: [URLQueryItem] = []
  ) {
    self.path = path
    self.method = method
    self.queryItems = queryItems
  }
}

typealias VoidRequestBodyEndpoint<ResponseBody> = Endpoint<Void, ResponseBody>
```

Keep the path as the resource alone—for Current Weather that is `data/2.5/weather`. Parameters such as `appid`, `lat`, and `lon` belong in `queryItems`, the same separate inputs you used in the earlier OpenWeather post. `Void` on the request body is only a marker, not something you encode. It lets the type system tell a “GET that returns JSON” apart from later shapes such as “POST that returns nothing,” without putting that distinction into the method name. OpenWeather’s Current Weather API only needs this GET shape, so we will implement one `response` overload and leave the others for APIs that actually accept bodies or return empty responses.

## Why an Actor?

The client holds a base URL, a `URLSession`, and the JSON coder you configure once at launch. You will share one instance from SwiftUI views, pull-to-refresh, and other async call sites. Marking the type as an `actor` gives that shared instance a safe home under Swift 6 concurrency: call sites `await` into it, and any configuration that lives on the client stays isolated.

```swift
actor APIClient {
  private let baseURL: URL
  private let decoder: JSONDecoder
  private let encoder: JSONEncoder
  private let session: URLSession

  init(
    baseURL: URL,
    session: URLSession = .shared,
    encoder: JSONEncoder = .init(),
    decoder: JSONDecoder = .init()
  ) {
    self.baseURL = baseURL
    self.session = session
    self.encoder = encoder
    self.decoder = decoder
  }
}
```

This is not mainly about `JSONEncoder` / `JSONDecoder` being “not thread-safe.” Recent Foundation even treats those types as sendable when you do not mutate their strategies while requests are in flight. The actor’s job is simpler: one client, many async callers, no data races around the values the client owns. If every stored property were an immutable `let` and you never needed isolation, a `final class` could work—but an actor is the straightforward default for a shared networking type.

Pass a decoder already configured the way OpenWeather’s payloads need. For Current Weather, converting snake_case keys is enough; you do not need a date strategy because we will keep timestamps out of the small model below:

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase

let client = APIClient(
  baseURL: URL(string: "https://api.openweathermap.org")!,
  decoder: decoder
)
```

## Sending the Request

Path joining, query attachment, header setup, and status checking stay private. A successful response is any HTTP status in `200 ..< 300`; anything else becomes `URLError.badServerResponse`. That keeps the happy path short while still failing loudly when the server rejects the call:

```swift
extension APIClient {
  private func url(for path: String, queryItems: [URLQueryItem]) -> URL {
    let url = baseURL.appending(path: path)
    guard !queryItems.isEmpty,
          var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return url
    }
    components.queryItems = queryItems
    return components.url ?? url
  }

  private func request(url: URL, method: String) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  @discardableResult
  private func performRequest(_ request: URLRequest) async throws -> Data {
    let (data, response) = try await session.data(for: request)
    guard
      let httpResponse = response as? HTTPURLResponse,
      (200 ..< 300).contains(httpResponse.statusCode)
    else {
      throw URLError(.badServerResponse)
    }
    return data
  }
}
```

`URLComponents` is what turns your `URLQueryItem` list into a real query string. Use the same Brooklyn coordinates and imperial units as the earlier post, and replace `YOUR_API_KEY` with the key from your OpenWeather account:

```swift
let apiKey = "YOUR_API_KEY"
let path = "data/2.5/weather"
let queryItems = [
  URLQueryItem(name: "appid", value: apiKey),
  URLQueryItem(name: "lat", value: "40.6501"),
  URLQueryItem(name: "lon", value: "-73.9496"),
  URLQueryItem(name: "units", value: "imperial"),
]
```

## Decoding the Response

The GET overload takes a void-request endpoint, performs the request, and decodes the body. The return type is inferred from the call site, so you read `CurrentWeather` (or any other `Decodable`) without casting:

```swift
extension APIClient {
  func response<ResponseBody: Decodable>(
    endpoint: VoidRequestBodyEndpoint<ResponseBody>
  ) async throws -> ResponseBody {
    let url = url(for: endpoint.path, queryItems: endpoint.queryItems)
    let request = request(url: url, method: endpoint.method)
    let data = try await performRequest(request)
    return try decoder.decode(ResponseBody.self, from: data)
  }
}
```

You do not need every field OpenWeather returns. Decode the slice your UI cares about; unknown keys are ignored. For a simple readout of place, temperature, humidity, and condition:

```swift
struct CurrentWeather: Decodable {
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
```

`weather` is an array; treat the first element as primary, same as in the Current Weather walkthrough. Icon IDs still resolve with `https://openweathermap.org/img/wn/{icon}@2x.png` when you are ready to show artwork instead of the description string alone.

## Putting It Together

With the client and model in place, the call site is one `await`. Create the endpoint inline, or store it next to the screen that loads forecast data:

```swift
let forecast: CurrentWeather = try await client.response(
  endpoint: .init(path: path, queryItems: queryItems)
)

let condition = forecast.weather.first?.description ?? "Unknown"
print("\(forecast.name): \(forecast.main.temp)°F, \(condition)")
```

That is the whole GET path: describe the endpoint, share an actor-isolated client, decode into a small `Decodable` type. The same `Endpoint` generics leave room for request bodies and empty responses later, but you do not need those shapes to ship a weather screen that shows OpenWeather’s current conditions.

## Conclusion

We’ve built a bare-bones async JSON client—an `Endpoint` for method, path, and query items, an `actor` so one instance can be shared safely from async call sites, and a `response` overload that GETs and decodes. Pointed at OpenWeather’s Current Weather API, that is enough to load Brooklyn’s forecast behind a single call site. From here you can grow the decoded model with more of the fields from the earlier OpenWeather post, add a 5-day endpoint with another path, or extend `response` for POST and DELETE when an API actually needs them.
