// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Rise",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Rise", targets: ["Rise"])],
    targets: [
        .target(name: "RiseCore"),
        .executableTarget(
            name: "Rise",
            dependencies: ["RiseCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "RiseCoreTests", dependencies: ["RiseCore"]),
    ]
)
