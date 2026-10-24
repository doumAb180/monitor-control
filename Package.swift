// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Monitor",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Monitor", targets: ["Monitor"])],
    targets: [
        .target(name: "MonitorCore"),
        .target(name: "DDCBridge", linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("CoreFoundation")]),
        .executableTarget(name: "Monitor", dependencies: ["MonitorCore", "DDCBridge"]),
        .testTarget(name: "MonitorCoreTests", dependencies: ["MonitorCore"]),
        .testTarget(name: "MonitorTests", dependencies: ["Monitor"])
    ]
)
