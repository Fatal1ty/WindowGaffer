// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "WindowGaffer",
    platforms: [
        .macOS("27.0")
    ],
    products: [
        .library(name: "WindowGafferCore", targets: ["WindowGafferCore"]),
        .executable(name: "WindowGaffer", targets: ["WindowGaffer"])
    ],
    targets: [
        .target(name: "WindowGafferCore"),
        .executableTarget(
            name: "WindowGaffer",
            dependencies: ["WindowGafferCore"]
        ),
        .testTarget(
            name: "WindowGafferCoreTests",
            dependencies: ["WindowGafferCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)
