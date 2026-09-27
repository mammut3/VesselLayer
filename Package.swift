// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VesselLayer",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "VesselLayer", targets: ["VesselLayer"]),
        .library(name: "VesselLayerTesting", targets: ["VesselLayerTesting"]),
    ],
    targets: [
        .target(name: "VesselLayer"),
        .target(name: "VesselLayerTesting", dependencies: ["VesselLayer"]),
        .testTarget(
            name: "VesselLayerTests",
            dependencies: ["VesselLayer", "VesselLayerTesting"]
        ),
    ]
)
