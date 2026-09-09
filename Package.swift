// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyBrake",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KeyBrakeCore", targets: ["KeyBrakeCore"]),
        .executable(name: "KeyBrake", targets: ["KeyBrake"])
    ],
    targets: [
        .target(name: "KeyBrakeCore", path: "KeyBrakeCore"),
        .executableTarget(name: "KeyBrake", dependencies: ["KeyBrakeCore"], path: "KeyBrake"),
        .testTarget(name: "KeyBrakeTests", dependencies: ["KeyBrakeCore"], path: "KeyBrakeTests")
    ]
)
