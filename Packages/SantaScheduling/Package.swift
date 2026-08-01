// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SantaScheduling",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SantaScheduling", targets: ["SantaScheduling"])
    ],
    targets: [
        .target(name: "SantaScheduling"),
        .testTarget(name: "SantaSchedulingTests", dependencies: ["SantaScheduling"])
    ]
)
