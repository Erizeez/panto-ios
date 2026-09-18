// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PantoIOS",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "PantoShared", targets: ["PantoShared"]),
        .library(name: "PantoTunnel", targets: ["PantoTunnel"]),
        .library(name: "PantoApp", targets: ["PantoApp"]),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "PantoKit",
            path: "Frameworks/PantoKit.xcframework"
        ),
        .target(
            name: "PantoShared",
            path: "Shared"
        ),
        .target(
            name: "PantoTunnel",
            dependencies: [
                "PantoShared",
                "PantoKit"
            ],
            path: "PantoTunnel"
        ),
        .target(
            name: "PantoApp",
            dependencies: [
                "PantoShared",
                "PantoKit"
            ],
            path: "PantoApp"
        ),
    ]
)
