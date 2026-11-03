// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PayKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "PayKit",
            targets: ["PayKit"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PayKit",
            dependencies: [],
            path: "Sources/PayKit"
        ),
        .testTarget(
            name: "PayKitTests",
            dependencies: ["PayKit"],
            path: "Tests/PayKitTests"
        ),
    ]
)
