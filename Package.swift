// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PantoIOS",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "PantoShared", targets: ["PantoShared"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PantoShared",
            path: "Shared"
        ),
        .testTarget(
            name: "PantoTests",
            dependencies: [
                "PantoShared"
            ],
            path: "Tests/PantoTests"
        ),
    ]
)
