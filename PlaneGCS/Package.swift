// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PlaneGCS",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "PlaneGCS",
            targets: ["PlaneGCS"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PlaneGCS",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "PlaneGCSTests",
            dependencies: ["PlaneGCS"]),
    ]
)