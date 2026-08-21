// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DesktopWorm",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DesktopWorm", targets: ["DesktopWorm"]),
    ],
    targets: [
        .executableTarget(
            name: "DesktopWorm",
            resources: [.process("Resources")]
        ),
    ]
)
