// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SantaCallSummary",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SantaCallSummary", targets: ["SantaCallSummary"])
    ],
    targets: [
        .target(name: "SantaCallSummary"),
        .testTarget(name: "SantaCallSummaryTests", dependencies: ["SantaCallSummary"])
    ]
)
