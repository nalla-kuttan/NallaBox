// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NallaServer",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "NallaServer", targets: ["NallaServer"])],
    dependencies: [.package(path: "../NallaCore")],
    targets: [
        .target(name: "NallaServer", dependencies: ["NallaCore"]),
        .executableTarget(name: "NallaDevServer", dependencies: ["NallaServer", "NallaCore"]),
        .testTarget(name: "NallaServerTests", dependencies: ["NallaServer", "NallaCore"]),
    ]
)
