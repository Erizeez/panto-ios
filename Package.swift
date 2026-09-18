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
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PantoShared",
            path: "Shared"
        )
    ]
)
