import Foundation

enum WeatherConfig {
  static var apiKey: String {
    guard
      let key = Bundle.main.object(forInfoDictionaryKey: "WeatherAPIKey") as? String,
      !key.isEmpty,
      key != "$(WEATHER_API_KEY)"
    else {
      fatalError("Missing WeatherAPIKey — copy Secrets.example.xcconfig to Secrets.xcconfig")
    }
    return key
  }
}
