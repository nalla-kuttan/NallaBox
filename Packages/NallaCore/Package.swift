// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NallaCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "NallaCore", targets: ["NallaCore"])],
    targets: [
        .target(name: "NallaCore"),
        .testTarget(name: "NallaCoreTests", dependencies: ["NallaCore"]),
    ]
)
