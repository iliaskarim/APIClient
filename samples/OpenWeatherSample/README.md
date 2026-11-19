# OpenWeather Sample

A small SwiftUI app that asks for When In Use location access and shows OpenWeather’s current forecast. It packages the pieces from the [OpenWeather tutorial series](https://iliaskarim.dev/series/openweather-tutorial) as ordinary source files—no Swift package dependency.

## Setup

1. Open `OpenWeatherSample.xcodeproj` in Xcode.
2. Copy `OpenWeatherSample/Secrets.example.xcconfig` to `OpenWeatherSample/Secrets.xcconfig` if you do not already have one.
3. Paste your OpenWeather API key as `WEATHER_API_KEY` in `Secrets.xcconfig`.
4. Run on a simulator or device. In the Simulator, set **Features → Location** to a preset or custom coordinate.

`Secrets.xcconfig` is gitignored. The target already bases its configurations on that file and exposes the key through Info.plist as `WeatherAPIKey`, matching [How to Keep API Keys Out of Source Control](https://iliaskarim.dev/how-to-keep-api-keys-out-of-source-control).

## What’s in the app

| File | From |
| --- | --- |
| `Vendor/APIClient.swift` | The `APIClient` sources from this repo |
| `CurrentWeather.swift` | Bare-bones async JSON client post |
| `CurrentWeatherQuery.swift` | Typed query items post |
| `WeatherConfig.swift` | API keys / `.xcconfig` post |
| `LocationProvider.swift` | Location permission post |
| `WeatherModel.swift` | Wires the location-post call site for SwiftUI |
| `ContentView.swift` | Minimal forecast UI |

The networking and location call site is the same sequence taught at the end of the location post: `provider.coordinate()` → `CurrentWeatherQuery` → `client.response(endpoint:queryItems:)`.
