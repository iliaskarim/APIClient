# How to Type OpenWeather Query Items in a Swift API Client

In this tutorial we will learn how to replace a stringly typed OpenWeather query dictionary with a small Swift struct. In [How to Build a Bare-Bones Async JSON Client in Swift](/how-to-build-a-bare-bones-async-json-client-in-swift) we passed `appid`, `lat`, `lon`, and `units` as a `[String: String]` into `response`. That works, but the keys are magic strings and every value is already a `String`—even latitude and longitude. We will teach the client to accept any value that can build that dictionary, then model Current Weather’s query as a named type.

## Getting Started

The earlier client post left the call site looking like this:

```swift
let apiKey = "YOUR_API_KEY"
let path = "data/2.5/weather"
let queryItems = [
  "appid": apiKey,
  "lat": "40.6501",
  "lon": "-73.9496",
  "units": "imperial",
]

let forecast: CurrentWeather = try await client.response(
  endpoint: .init(path: path),
  queryItems: queryItems
)
```

The endpoint is still only a path and a method. The query rides on `response`, the same place a request body would. Nothing about that division changes. What changes is the *type* of `queryItems`: instead of always demanding `[String: String]`, the client will ask for something that can *produce* one.

## Naming the Query Type

Introduce a tiny protocol whose only job is to expose a dictionary the URL builder already understands:

```swift
protocol QueryItemsConvertible {
  var queryItems: [String: String] { get }
}

extension [String: String]: QueryItemsConvertible {
  var queryItems: [String: String] { self }

  init(_ queryItems: some QueryItemsConvertible) {
    self = queryItems.queryItems
  }
}
```

Dictionary literals keep working: `[String: String]` conforms, so existing call sites compile. Custom types opt in by returning the same shape of dictionary the private `url(for:queryItems:)` helper already maps to `URLQueryItem` values.

`Endpoint` gains a third generic parameter so each endpoint can name the query type it expects, alongside the request and response body types you already had:

```swift
struct Endpoint<QueryItems, RequestBody, ResponseBody> {
  let method: String
  let path: String

  init(
    path: String,
    method: String = "GET"
  ) {
    self.path = path
    self.method = method
  }
}

typealias VoidRequestBodyEndpoint<QueryItems, ResponseBody> =
  Endpoint<QueryItems, Void, ResponseBody>
```

The GET overload now constrains `QueryItems` to `QueryItemsConvertible` and takes a value of that type instead of a bare dictionary:

```swift
extension APIClient {
  func response<QueryItems: QueryItemsConvertible, ResponseBody: Decodable>(
    endpoint: VoidRequestBodyEndpoint<QueryItems, ResponseBody>,
    queryItems: QueryItems
  ) async throws -> ResponseBody {
    let url = url(for: endpoint.path, queryItems: queryItems)
    let request = request(url: url, method: endpoint.method)
    let data = try await performRequest(request)
    return try decoder.decode(ResponseBody.self, from: data)
  }
}
```

Inside `url(for:queryItems:)`, convert through the dictionary initializer and keep the same `URLComponents` + `map` path from the earlier post. The networking core does not learn about OpenWeather; it only learns how to ask any query value for `[String: String]`.

## A Current Weather Query Struct

Current Weather always wants the same four parameters. Give them a home:

```swift
struct CurrentWeatherQuery: QueryItemsConvertible {
  let appid: String
  let lat: Double
  let lon: Double
  let units: String

  var queryItems: [String: String] {
    [
      "appid": appid,
      "lat": String(lat),
      "lon": String(lon),
      "units": units,
    ]
  }
}
```

`appid` and `units` stay strings because that is how OpenWeather’s query string spells them. `lat` and `lon` can be `Double` in your model; the computed `queryItems` property is where they become the decimal strings the API expects. Forgetting a field is now a compile error. Typos in key names—“`appId`” instead of “`appid`”—stop living at every call site and live in one dictionary literal inside the type.

Pin the endpoint’s query generic to that struct when you want the type system to enforce it:

```swift
let weatherEndpoint = Endpoint<CurrentWeatherQuery, Void, CurrentWeather>(
  path: "data/2.5/weather"
)
```

Or keep using `VoidRequestBodyEndpoint<CurrentWeatherQuery, CurrentWeather>` if you prefer the alias. A call that passes a plain `[String: String]` no longer type-checks against that endpoint; a call that passes `CurrentWeatherQuery` does.

## Wiring the Call Site

Build the query value, then hand it to `response` the same way you used to hand over the dictionary:

```swift
let query = CurrentWeatherQuery(
  appid: "YOUR_API_KEY",
  lat: 40.6501,
  lon: -73.9496,
  units: "imperial"
)

let forecast: CurrentWeather = try await client.response(
  endpoint: weatherEndpoint,
  queryItems: query
)
```

Use your own coordinates; the numbers above are only a sample. Replace `YOUR_API_KEY` with the key from your OpenWeather account—the loading strategy (hard-coded placeholder, scheme environment variable, or `.xcconfig`) is independent of how the query is typed. Dictionary call sites remain available for endpoints that have not earned a struct yet, because `[String: String]` still conforms to `QueryItemsConvertible`.

## Why Bother

A dictionary is the right first step: it matches how query strings look on the wire, and it kept the first client tutorial small. A struct earns its keep when the same parameter set shows up at more than one call site, or when a wrong key would fail only at runtime against OpenWeather.

Typed queries give you:

- **Required fields** — omit `units` and the compiler complains before you hit the network.
- **Real types at the edge** — `lat` / `lon` as `Double` in app code; stringification stays in `queryItems`.
- **One spelling of each key** — OpenWeather’s `appid` lives in a single property wrapper around the dictionary, not in every screen that loads a forecast.
- **Endpoint-shaped documentation** — `Endpoint<CurrentWeatherQuery, Void, CurrentWeather>` reads as “this GET takes that query and returns that body,” the same way request-body generics already document POST shapes.

You do not need a struct for every endpoint on day one. Start with Current Weather, leave quieter calls on dictionaries, and promote a query type when the parameter list stabilizes.

## Conclusion

We’ve taken the bare-bones client from [How to Build a Bare-Bones Async JSON Client in Swift](/how-to-build-a-bare-bones-async-json-client-in-swift) and typed its query parameter the way the body types were already typed: a `QueryItemsConvertible` value on `response`, and an `Endpoint` generic that names which query belongs with which path. A `CurrentWeatherQuery` struct turns `appid`, `lat`, `lon`, and `units` into fields instead of dictionary keys, while dictionaries remain a valid escape hatch. From here you can add a 5-day query type with its own fields, or keep Stations-style `appid`-only calls as a one-property struct when you want the same pattern everywhere.

*Cover image generated for this post.*
