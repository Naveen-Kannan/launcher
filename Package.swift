// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "launcher",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "Launcher",
            targets: ["Launcher"]
        ),
    ],
    targets: [
        .target(
            name: "Launcher"
        ),
        .testTarget(name: "LauncherTests", dependencies: ["Launcher"]),
    ]
)
