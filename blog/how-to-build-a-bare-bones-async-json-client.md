# How to Build a Bare-Bones Async JSON Client in Swift

In this tutorial we will learn how to build a small async JSON API client in Swift and use it to fetch the current weather from OpenWeather. The client stays intentionally thin: an endpoint is a path and an HTTP method, and a single `response` call sends the request and decodes JSON. If you already followed [How to Retrieve the Current Weather Forecast from OpenWeather](/how-to-retrieve-the-current-weather-forecast-from-openweather), this post is the next step—wrapping that same endpoint in a reusable client instead of hand-rolling `URLSession` at every call site.

## Getting Started

Start with the value that describes *what* to call. An `Endpoint` carries an HTTP method and a path. The two generic parameters record whether the call has a JSON request body and whether it expects a JSON response body. For a weather GET we only need the response side, so the request body type is `Void`:

```swift
struct Endpoint<RequestBody, ResponseBody> {
  let method: String
  let path: String

  init(path: String, method: String = "GET") {
    self.path = path
    self.method = method
  }
}

typealias VoidRequestBodyEndpoint<ResponseBody> = Endpoint<Void, ResponseBody>
```

`Void` here is a marker, not something you encode. It lets the type system tell a “GET that returns JSON” apart from later shapes such as “POST that returns nothing,” without putting that distinction into the method name.

## Why an Actor?

The client holds a base URL, a `URLSession`, and the JSON coder you configure once at launch. You will share one instance from SwiftUI views, refresh actions, and other async call sites. Marking the type as an `actor` gives that shared instance a safe home under Swift 6 concurrency: call sites `await` into it, and mutable configuration stays isolated on the actor.

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

This is not mainly about `JSONEncoder` / `JSONDecoder` being “not thread-safe.” The actor’s job is simpler: one client, many async callers, no data races. Pass a decoder already configured the way OpenWeather’s payloads need—for Current Weather, snake_case keys are enough:

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase

let client = APIClient(
  baseURL: URL(string: "https://api.openweathermap.org")!,
  decoder: decoder
)
```

## Sending the Request

Path joining, header setup, and status checking stay private. A successful response is any HTTP status in `200 ..< 300`; anything else becomes `URLError.badServerResponse`:

```swift
extension APIClient {
  private func url(for path: String) -> URL {
    baseURL.appending(path: path)
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

OpenWeather’s Current Weather API key and coordinates travel as query items on the path. Replace `YOUR_API_KEY` with the key from your OpenWeather account—the same setup as in the earlier forecast post:

```swift
let apiKey = "YOUR_API_KEY"
let path =
  "data/2.5/weather?appid=\(apiKey)&lat=40.6501&lon=-73.9496&units=imperial"
```

## Decoding the Response

The GET overload takes a void-request endpoint, performs the request, and decodes the body. The return type is inferred from the call site:

```swift
extension APIClient {
  func response<ResponseBody: Decodable>(
    endpoint: VoidRequestBodyEndpoint<ResponseBody>
  ) async throws -> ResponseBody {
    let url = url(for: endpoint.path)
    let request = request(url: url, method: endpoint.method)
    let data = try await performRequest(request)
    return try decoder.decode(ResponseBody.self, from: data)
  }
}
```

You do not need every field OpenWeather returns. Decode the slice your UI cares about; unknown keys are ignored. For a simple readout of place, temperature, and condition:

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

`weather` is an array; treat the first element as primary, same as in the Current Weather walkthrough. Icon IDs still resolve with `https://openweathermap.org/img/wn/{icon}@2x.png`.

## Putting It Together

With the client and model in place, the call site is one `await`:

```swift
let forecast: CurrentWeather = try await client.response(
  endpoint: .init(path: path)
)

print(forecast.name, forecast.main.temp, forecast.weather.first?.description ?? "")
```

That is the whole GET path: describe the endpoint, share an actor-isolated client, decode into a small `Decodable` type. The same `Endpoint` generics leave room for request bodies and empty responses later, but you do not need those shapes to ship a weather screen.

## Conclusion

We’ve built a bare-bones async JSON client—an `Endpoint` for method and path, an `actor` so one instance can be shared safely, and a `response` overload that GETs and decodes. Pointed at OpenWeather’s Current Weather API, that is enough to load Brooklyn’s forecast behind a single call site. From here you can grow the decoded model, add a 5-day endpoint with another path, or extend `response` for POST and DELETE when an API actually needs them.
