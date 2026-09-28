// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Posy",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "Posy", targets: ["Posy"]),
        .library(name: "PosyCore", targets: ["PosyCore"]),
    ],
    targets: [
        .target(name: "PosyCore"),
        .target(name: "Posy", dependencies: ["PosyCore"]),

        // Evaluation and demo tooling. Not exported as products.
        .target(name: "PosyMetrics", dependencies: ["PosyCore"]),
        .target(name: "DemoSupport"),
        .executableTarget(name: "PosyGallery", dependencies: ["Posy", "PosyCore", "PosyMetrics", "DemoSupport"]),
        .executableTarget(name: "ReadmeAssets", dependencies: ["Posy", "PosyCore", "DemoSupport"]),

        .testTarget(name: "PosyCoreTests", dependencies: ["PosyCore"]),
        .testTarget(name: "PosyMetricsTests", dependencies: ["PosyCore", "PosyMetrics"]),
    ]
)
