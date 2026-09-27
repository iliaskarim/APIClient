# APIClient

Bare-bones async JSON client. `Endpoint` is a path and an HTTP method. Call `response` to send it.

## Installation

```swift
.package(url: "https://github.com/iliaskarim/APIClient.git", branch: "main")
```

## Usage

```swift
struct Flag: Decodable {
  let enabledFor: [String]
}

let client = APIClient(
  baseURL: URL(string: "https://api.octodoge.com")!,
  bearerToken: "<token>"
)

let flags: [String: Flag] = try await client.response(
  endpoint: .init(path: "/features")
)
```
