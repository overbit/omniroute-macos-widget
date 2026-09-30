// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OmniRouteWidget",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "OmniRouteCore", targets: ["OmniRouteCore"])
    ],
    targets: [
        .target(name: "OmniRouteCore"),
        .testTarget(
            name: "OmniRouteCoreTests",
            dependencies: ["OmniRouteCore"]
        )
    ]
)
