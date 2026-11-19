import Foundation

struct CurrentWeatherQuery: QueryItemsConvertible {
  let appid: String
  let lat: Double
  let lon: Double
  let units: String

  var queryItems: [URLQueryItem] {
    [
      URLQueryItem(name: "appid", value: appid),
      URLQueryItem(name: "lat", value: String(lat)),
      URLQueryItem(name: "lon", value: String(lon)),
      URLQueryItem(name: "units", value: units),
    ]
  }
}
