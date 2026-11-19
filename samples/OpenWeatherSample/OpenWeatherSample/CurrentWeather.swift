import Foundation

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
