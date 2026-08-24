// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeBattery",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeBattery",
            path: "Sources/ClaudeBattery",
            exclude: ["Info.plist", "ClaudeBattery.entitlements", "AppIcon.icon"]
        )
    ]
)
