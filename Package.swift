// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChromePatcher",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "ChromePatcher", targets: ["ChromePatcher"]),
        .library(name: "ChromePatcherCore", targets: ["ChromePatcherCore"]),
    ],
    targets: [
        .target(name: "ChromePatcherCore"),
        .executableTarget(
            name: "ChromePatcher",
            dependencies: ["ChromePatcherCore"]
        ),
        .testTarget(
            name: "ChromePatcherCoreTests",
            dependencies: ["ChromePatcherCore"]
        ),
    ]
)
