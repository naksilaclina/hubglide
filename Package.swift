// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HubGlide",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "HubGlide", targets: ["HubGlide"])],
    targets: [
        .executableTarget(name: "HubGlide"),
        .testTarget(name: "HubGlideTests", dependencies: ["HubGlide"]),
    ],
    swiftLanguageModes: [.v5]
)
