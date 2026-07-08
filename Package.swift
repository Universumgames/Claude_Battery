// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageMenuBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeUsageMenuBar",
            path: "Sources/ClaudeUsageMenuBar",
            exclude: ["Info.plist", "ClaudeUsageMenuBar.entitlements", "AppIcon.icon"]
        )
    ]
)
