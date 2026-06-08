// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MemoryGuard",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MemoryGuard",
            path: "Sources/MemoryGuard",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
