# Wrapping Up the OpenWeather Tutorial Series

In this wrap-up we put the OpenWeather tutorial series in one place and ship a small SwiftUI sample that asks for location and shows the current forecast. The app vendors `APIClient` as ordinary source files—no package manager step—so you can open the project, paste a key, and run.

## The Series

Start with the weather response itself, then the client, typed query, and GPS:

1. [How to Retrieve the Current Weather Forecast from OpenWeather](/how-to-retrieve-the-current-weather-forecast-from-openweather)
2. [How to Build a Bare-Bones Async JSON Client in Swift](/how-to-build-a-bare-bones-async-json-client-in-swift)
3. [How to Type OpenWeather Query Items in a Swift API Client](/how-to-type-openweather-query-items-in-a-swift-api-client)
4. [How to Request Location Permission and Read GPS Coordinates on iOS](/how-to-request-location-permission-and-read-gps-coordinates-on-ios)

Alongside those posts, keep the key out of git with [How to Keep API Keys Out of Source Control](/how-to-keep-api-keys-out-of-source-control)—the sample uses the `.xcconfig` + Info.plist path from that article.

## The Sample

Download [OpenWeatherSample.zip](/openweather-sample.zip). Open the Xcode project, copy `Secrets.example.xcconfig` to `Secrets.xcconfig`, paste your OpenWeather API key, and run. On the Simulator, set **Features → Location** before the first refresh.

Inside the app target you will find:

- `Vendor/APIClient.swift` — the client sources from the repo, compiled into the app
- `CurrentWeather` and `CurrentWeatherQuery` — the models from the client and typed-query posts
- `WeatherConfig` — the `.xcconfig` loader from the keys post
- `LocationProvider` — the Core Location wrapper from the location post
- A thin SwiftUI shell that runs the same call site the location post ends on: coordinate → query → `response`

Nothing here invents a new networking API. It is the series call site behind a screen.

## Conclusion

We’ve walked from OpenWeather’s Current Weather response through a bare-bones async JSON client, typed query items, When In Use location access, and a keyed build setting—and this post closes that loop with a runnable sample. This ends the OpenWeather tutorial series. Rest assured further series will follow.

[Download OpenWeatherSample.zip](/openweather-sample.zip)
