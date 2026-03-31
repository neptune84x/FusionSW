// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Fusion",
    platforms: [
        .macOS(.v12) // Minimum macOS Monterey gereksinimi
    ],
    targets: [
        .executableTarget(
            name: "Fusion",
            dependencies: [],
            path: "Sources/Fusion"
        )
    ]
)
