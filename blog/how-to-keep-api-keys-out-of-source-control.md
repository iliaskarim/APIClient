# How to Keep API Keys Out of Source Control

In this tutorial we will learn how to keep an API key out of your Swift weather app’s source control. Hard-coding the key in a string literal is fine for a walkthrough, risky the moment that file is committed. We will start with environment variables in an Xcode scheme, then move to an `.xcconfig` file, and compare when each approach earns its keep.

## Getting Started

Hard-coding the key is the failure mode we want to leave behind:

```swift
let apiKey = "YOUR_API_KEY"
```

Once that real key replaces the placeholder, `git commit` publishes a secret to every clone of the repo. Keys are easy to rotate, but the habit matters: treat the key like a password, not like sample data. The rest of this post assumes a call site that already passes `apiKey` into a request—only the way you *load* that value changes.

## Environment Variables First

Xcode schemes can inject environment variables into the process when you Run. Open **Product → Scheme → Edit Scheme…**, select **Run**, open the **Arguments** tab, and add a variable—for example `WEATHER_API_KEY`—with your real key as the value. Uncheck “Shared” on the scheme if you do not want that configuration checked into the repo; a shared scheme that embeds the secret is still a secret in git.

Read the value at runtime with `ProcessInfo`:

```swift
enum WeatherConfig {
  static var apiKey: String {
    guard
      let key = ProcessInfo.processInfo.environment["WEATHER_API_KEY"],
      !key.isEmpty
    else {
      fatalError("Missing WEATHER_API_KEY in the Run scheme environment")
    }
    return key
  }
}
```

Wire that into the query dictionary (or header) your networking layer already expects:

```swift
let queryItems = [
  "api_key": WeatherConfig.apiKey,
  "lat": "40.6501",
  "lon": "-73.9496",
  "units": "imperial",
]
```

This is the fastest loop for a solo weather app: no new files, no build-setting plumbing, and the key never appears in a `.swift` file. The tradeoff is locality. Scheme environment variables apply to that scheme’s Run action on that machine. If you use a separate Test action, add the same variable there when tests hit the network. Teammates and CI each need their own copy—nothing in the repo teaches the next Mac what to set. And if someone checks the shared scheme checkbox, the secret can sneak back into source control through `xcscheme` XML, which is easy to miss in a diff full of scheme noise.

## xcconfig Next

When you want the key available to every configuration without editing schemes, move it into an `.xcconfig` file that git ignores. Add two files at the project root (or in a `Config` group):

`Secrets.example.xcconfig` — committed, no real secret:

```xcconfig
WEATHER_API_KEY = YOUR_API_KEY
```

`Secrets.xcconfig` — gitignored, your real key:

```xcconfig
WEATHER_API_KEY = pastetherealkeyhere
```

Point the project or target at the real file under **Project → Info → Configurations** (or the target’s based-on configuration). Expose the build setting to the app through Info.plist so Swift can read it without digging through the build system at runtime. Add a key such as `WeatherAPIKey` with value `$(WEATHER_API_KEY)`, then load it from the bundle:

```swift
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
```

Ignore the real file explicitly:

```gitignore
Secrets.xcconfig
```

Commit the example so a new clone knows what to create. Document one setup line in the README: copy the example, paste your key, build. CI can generate `Secrets.xcconfig` from a masked pipeline secret the same way—write the file in a pre-build step, never commit it from the runner. If you already use `.xcconfig` for compiler flags or bundle IDs, basing Debug and Release on `Secrets.xcconfig` keeps the API key beside those other per-machine values instead of inventing a second channel.

## Which Approach When?

Environment variables win when you are alone on one Mac and want the smallest change: open the scheme, set `WEATHER_API_KEY`, keep coding. They lose when you need Debug and Release, unit tests, a teammate’s laptop, or a CI job to see the same value without repeating scheme edits.

`.xcconfig` wins when the key should ride with the build. One ignored file, one example in git, Info.plist as the bridge into Swift, and every configuration that based-on that file inherits the setting. The cost is a little project setup the first time—worth it as soon as the weather app leaves the “just me, just Run” stage.

Neither approach hides the key inside a shipped `.ipa`. Anything readable from `Bundle.main` or the process environment can be extracted from the app binary—Info.plist values included. That is acceptable for a teaching weather app and for many hobby projects; it is not a substitute for a backend proxy if you later need a key that must stay server-side. The goal here is narrower and still important: keep secrets out of git history and out of pull requests, not out of a determined reader of your IPA.

## Conclusion

We’ve replaced a hard-coded API key with two layered options: scheme environment variables for the quick local path, and a gitignored `.xcconfig` plus Info.plist for a build that scales past one scheme. Start with the scheme if you are still sketching the forecast UI; graduate to `.xcconfig` when tests, teammates, or CI need the same key without copying a secret into Swift. In both cases, the call site stays a single `WeatherConfig.apiKey`—only the delivery mechanism changes.

*Cover: [Old key and laptop](https://commons.wikimedia.org/wiki/File:Old_key_and_laptop.jpg) by [Nikowsk](https://commons.wikimedia.org/wiki/User:Nikowsk), [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).*
