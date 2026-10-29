// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NovaVideoRecoveryTests",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "NovaVideoSearch", targets: ["NovaVideoSearch"])
    ],
    targets: [
        .target(
            name: "NovaVideoSearch",
            path: "Sources/NovaVideoSearch"
        ),
        .testTarget(
            name: "NovaVideoSearchTests",
            dependencies: ["NovaVideoSearch"],
            path: "Tests/NovaVideoSearchTests"
        )
    ]
)
