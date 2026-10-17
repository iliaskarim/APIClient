// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "APIClient",
  platforms: [
    .iOS(.v16),
    .macOS(.v13)
  ],
  products: [
    .library(
      name: "APIClient",
      targets: ["APIClient"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/iliaskarim/FixtureURLProtocol.git", branch: "main")
  ],
  targets: [
    .target(
      name: "APIClient"
    ),
    .testTarget(
      name: "APIClientTests",
      dependencies: ["APIClient", "FixtureURLProtocol"]
    )
  ],
  swiftLanguageModes: [.v6]
)
