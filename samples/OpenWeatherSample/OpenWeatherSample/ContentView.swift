import SwiftUI

struct ContentView: View {
  @StateObject private var model = WeatherModel()

  var body: some View {
    NavigationStack {
      Group {
        switch model.phase {
        case .idle, .loading:
          ProgressView("Loading forecast…")
        case .loaded(let forecast):
          ForecastView(forecast: forecast)
        case .failed(let message):
          ContentUnavailableView(
            "Couldn’t load weather",
            systemImage: "cloud.bolt",
            description: Text(message)
          )
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .navigationTitle("Current Weather")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Refresh") {
            Task { await model.load() }
          }
          .disabled({
            if case .loading = model.phase { return true }
            return false
          }())
        }
      }
      .task {
        if case .idle = model.phase {
          await model.load()
        }
      }
    }
  }
}

private struct ForecastView: View {
  let forecast: CurrentWeather

  var body: some View {
    let condition = forecast.weather.first
    VStack(spacing: 16) {
      Text(forecast.name)
        .font(.largeTitle.bold())
      Text("\(Int(forecast.main.temp.rounded()))°F")
        .font(.system(size: 56, weight: .semibold, design: .rounded))
      Text(condition?.description.capitalized ?? "Unknown")
        .font(.title3)
        .foregroundStyle(.secondary)
      Text("Humidity \(forecast.main.humidity)%")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      if let icon = condition?.icon {
        AsyncImage(
          url: URL(string: "https://openweathermap.org/img/wn/\(icon)@2x.png")
        ) { image in
          image.resizable().scaledToFit()
        } placeholder: {
          ProgressView()
        }
        .frame(width: 100, height: 100)
      }
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
