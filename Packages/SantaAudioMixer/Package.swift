// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SantaAudioMixer",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SantaAudioMixer", targets: ["SantaAudioMixer"])
    ],
    targets: [
        .target(name: "SantaAudioMixer"),
        .testTarget(name: "SantaAudioMixerTests", dependencies: ["SantaAudioMixer"])
    ]
)
