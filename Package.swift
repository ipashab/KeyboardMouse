// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "KeyboardMouse",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "KeyboardMouse",
            path: "Sources/KeyboardMouse",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "KeyboardMouseTests",
            dependencies: ["KeyboardMouse"],
            path: "Tests/KeyboardMouseTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
